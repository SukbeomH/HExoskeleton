#!/usr/bin/env python3
"""router registry: the front session's map of topic → worker session (stdlib only).

File: $ROUTER_REGISTRY, else <--data dir>/registry.json, else $CLAUDE_PLUGIN_DATA/registry.json.
Shape: {"front": {"session_id", "name", "updated"} | null,
        "sessions": {<name>: {session_id, job_id, cwd, topic, model, state, pid, agent_state, waiting_for,
                              agent_type, last_result, merged_into, updated}}}
state: active | idle | waiting (refresh only: live but needs the user) | exited | merged.
Writes take an exclusive flock and replace the file atomically. Empty option values are ignored.

Usage: registry.py [--data DIR] <command> ...
  init | set-front [SESSION_ID] [--name N] | get-front | list [--json]
  upsert NAME [--new] [--session-id S] [--job-id J] [--cwd C] [--topic T] [--state S]
  spawn NAME --request R [--cwd C] [--topic T] [--model M] [--mode P] [--merged-from A,B]
        → reserve NAME, compose the prompt, backend.sh spawn, record job id (sources marked merged)
  resume NAME --request R  → refresh, then (if not running) compose the prompt, backend.sh resume, record job id
  --request - reads the request from stdin (only then; never an implicit stdin read that could hang).
  The prompt (front, topic, siblings, request) is composed here.
  mark NAME STATE [--into NAME] | refresh [FILE|-] [--json]  (no FILE: runs `backend.sh list` itself)
  record-result SESSION_ID TEXT
"""

import argparse
import fcntl
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time

STATES = ("active", "idle", "exited", "merged")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")  # SendMessage-safe without quoting
RESULT_MAX = 2000
BACKEND = pathlib.Path(__file__).with_name("backend.sh")
ROUTED = ("Routing instructions in the request (which session, a new session, which model) were already applied "
          "by the front: ignore them and do the task; never refuse it because of them.")


def path(data_dir=None):
    if os.environ.get("ROUTER_REGISTRY"):
        return pathlib.Path(os.environ["ROUTER_REGISTRY"])
    d = data_dir or os.environ.get("CLAUDE_PLUGIN_DATA")
    return pathlib.Path(d) / "registry.json" if d else None


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def load(p):
    try:
        return json.loads(p.read_text())
    except FileNotFoundError:
        return {"front": None, "sessions": {}}


def save(p, reg):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=p.parent, prefix=".registry.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(reg, f, ensure_ascii=False, indent=1)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, p)
    except BaseException:
        os.unlink(tmp)
        raise


class locked:
    """with locked(p) as reg: ... — load under an exclusive lock, save on clean exit."""

    # ponytail: one global lock per registry file; fine for a handful of sessions.
    def __init__(self, p):
        self.p = p

    def __enter__(self):
        self.p.parent.mkdir(parents=True, exist_ok=True)
        self.lock = open(str(self.p) + ".lock", "a")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        self.reg = load(self.p)
        return self.reg

    def __exit__(self, exc_type, *_):
        try:
            if exc_type is None:
                save(self.p, self.reg)
        finally:
            self.lock.close()


def find_worker(reg, session_id=None, job_id=None):
    for name, s in reg["sessions"].items():
        if session_id and s.get("session_id") == session_id:
            return name
    for name, s in reg["sessions"].items():
        if job_id and s.get("job_id") == job_id:
            return name
    return None


def record_result(p, session_id, job_id, text, agent_type=None):
    """Stop hook: store the worker's last reply; the turn ended, so active → idle (merged stays merged).
    Unknown session → no write at all."""
    if not p.exists() or not find_worker(load(p), session_id, job_id):
        return None
    with locked(p) as reg:
        name = find_worker(reg, session_id, job_id)
        if name:
            s = reg["sessions"][name]
            if session_id:
                s["session_id"] = session_id
            if agent_type:
                s["agent_type"] = agent_type
            s["last_result"] = text[:RESULT_MAX]
            if s.get("state") != "merged":
                s["state"] = "idle"
            s["updated"] = now()
    return name


def refresh(reg, agents):
    """Update worker entries from `claude agents --json --all`; alive = the entry has a pid."""
    by_sid = {a["sessionId"]: a for a in agents if a.get("sessionId")}
    by_job = {a["id"]: a for a in agents if a.get("id")}
    for name, s in reg["sessions"].items():
        if s.get("state") == "merged":
            continue
        # job id first: a resume that starts a copy gets a new job/session while session_id is stale
        a = by_job.get(s.get("job_id")) or by_sid.get(s.get("session_id"))
        if a is None and not s.get("job_id") and not s.get("session_id"):
            # no ids recorded: fall back to the name, but only if exactly one agent carries it
            hits = [x for x in agents if x.get("name") == name]
            if len(hits) > 1:
                continue
            a = hits[0] if hits else None
        if a is None:
            s.update(state="exited", pid=None)
            continue
        s["session_id"] = a.get("sessionId") or s.get("session_id")
        s["job_id"] = a.get("id") or s.get("job_id")
        s["pid"] = a.get("pid")
        s["agent_state"] = a.get("state")
        s["waiting_for"] = a.get("waitingFor")
        # waiting: a live worker needs the user (e.g. its own permission prompt holds its turn: no report, no Stop)
        waiting = a.get("status") == "waiting" or a.get("waitingFor") or a.get("state") == "blocked"
        s["state"] = ("exited" if not a.get("pid") else "waiting" if waiting
                      else "active" if a.get("status") == "busy" else "idle")
        s["updated"] = now()


def launch(p, name, args, prompt):
    """Run `backend.sh ARGS` with PROMPT on stdin; its stdout is the job id. Record it on NAME (state active),
    or mark NAME exited. pid/agent_state are cleared either way: they describe the previous process."""
    r = subprocess.run(["bash", str(BACKEND), *args], input=prompt, stdout=subprocess.PIPE, text=True)
    job = r.stdout.strip() if r.returncode == 0 else ""
    with locked(p) as reg:
        s = reg["sessions"][name]
        s.pop("agent_state", None)
        s.update({"job_id": job, "state": "active", "pid": None} if job else {"state": "exited", "pid": None})
        s["updated"] = now()
    return job


def backend_agents():
    """`backend.sh list` parsed, or None if it failed."""
    r = subprocess.run(["bash", str(BACKEND), "list"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None


def compose(reg, name, request, merged_from=()):
    """The worker's prompt: where to report (current front name), its topic, its siblings, a note that routing
    directives were already applied, then the request."""
    sibs = [f"{n} — {s.get('topic') or '-'}" for n, s in sorted(reg["sessions"].items())
            if n != name and n not in merged_from and s.get("state") != "merged"
            and (s.get("job_id") or s.get("session_id"))]
    head = [f"Router front: @{(reg.get('front') or {}).get('name')} — send results there with SendMessage.",
            f"Topic: {reg['sessions'][name].get('topic') or '-'}",
            f"Siblings: {'; '.join(sibs) or 'none'}"]
    if merged_from:
        head.append(f"Merged from: {', '.join(merged_from)}")
    head.append(ROUTED)
    return "\n".join(head) + f"\n\nRequest from the user:\n{request}"


def alive(pid):
    """Does a process with this pid exist? (signal 0 probes without signalling)"""
    # ponytail: a reused pid reads as alive until the next refresh corrects it.
    try:
        if int(pid) <= 0:
            return False
        os.kill(int(pid), 0)
    except PermissionError:
        return True
    except (ProcessLookupError, ValueError, TypeError, OverflowError):
        return False
    return True


def render(reg, width=200):
    front = reg.get("front") or {}
    lines = [f"[router] front: @{front.get('name') or '?'} — workers:"]
    for name, s in sorted(reg["sessions"].items()):
        last = " ".join((s.get("last_result") or "").split())[:width]
        extra = f" → {s['merged_into']}" if s.get("merged_into") else ""
        state, pid, cc = s.get("state", "?"), s.get("pid"), s.get("agent_state")
        if alive(pid):
            extra += f" pid {pid}"
        elif pid and state in ("active", "idle", "waiting"):
            state = "exited"  # recorded process is gone (e.g. idle retire); shown only, refresh records it
        if state == "waiting":
            state = f"WAITING: {s.get('waiting_for') or 'blocked'} — user must run: claude attach {s.get('job_id')};"
        elif cc and cc not in ("working", "done"):  # those only restate (or, after the turn, contradict) the state
            state += "/" + cc
        lines.append(
            f"- {name} [{state}{extra}]"
            f" topic: {s.get('topic') or '-'} | cwd: {s.get('cwd') or '-'} | last: {last or '-'}"
        )
    if not reg["sessions"]:
        lines.append("- (none)")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="router registry")
    ap.add_argument("--data", help="plugin data dir (skills pass ${CLAUDE_PLUGIN_DATA})")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init")
    sf = sub.add_parser("set-front")
    sf.add_argument("session_id", nargs="?")
    sf.add_argument("--name")
    sub.add_parser("get-front")
    ls = sub.add_parser("list")
    up = sub.add_parser("upsert")
    up.add_argument("name")
    up.add_argument("--new", action="store_true", help="fail if NAME is already taken")
    for f in ("session-id", "job-id", "cwd", "topic"):
        up.add_argument("--" + f)
    up.add_argument("--state", choices=STATES)
    sp = sub.add_parser("spawn")
    sp.add_argument("name")
    sp.add_argument("--cwd", default=os.getcwd(), help="worker directory (default: here, i.e. the front's)")
    sp.add_argument("--topic")
    sp.add_argument("--model")
    sp.add_argument("--mode", "--permission-mode", dest="mode", help="permission mode for the worker")
    sp.add_argument("--merged-from", default="", help="comma-separated sources, marked merged on success")
    rs = sub.add_parser("resume")
    rs.add_argument("name")
    for x in (sp, rs):
        x.add_argument("--request", required=True, help="the user's request; '-' reads it from stdin")
    mk = sub.add_parser("mark")
    mk.add_argument("name")
    mk.add_argument("state", choices=STATES)
    mk.add_argument("--into")
    rf = sub.add_parser("refresh")
    rf.add_argument("file", nargs="?")
    for x in (ls, rf):
        x.add_argument("--json", action="store_true", help="print the whole registry as JSON")
    rr = sub.add_parser("record-result")
    rr.add_argument("session_id")
    rr.add_argument("text")
    a = ap.parse_args(argv)

    p = path(a.data)
    if p is None:
        sys.exit("registry: set ROUTER_REGISTRY, --data or CLAUDE_PLUGIN_DATA")
    if a.cmd in ("spawn", "resume"):  # validate inputs before any name is reserved
        request = sys.stdin.read() if a.request == "-" else a.request
        if not request.strip():
            sys.exit("registry: empty request (pass --request TEXT, or --request - with the text on stdin)")
        if not (load(p).get("front") or {}).get("name"):  # the prompt must name where to report
            sys.exit("registry: no front registered (run /router:front first)")
    if a.cmd == "spawn":
        a.cwd = os.path.abspath(os.path.expanduser(a.cwd))
        if not os.path.isdir(a.cwd):
            sys.exit(f"registry: no directory '{a.cwd}' (name not reserved)")
        merged = [n for n in a.merged_from.split(",") if n]
    if a.cmd == "init":
        with locked(p):
            pass
        print(p)
    elif a.cmd == "set-front":
        sid = a.session_id or os.environ.get("CLAUDE_CODE_SESSION_ID", "")
        if not sid or "${" in sid:
            sys.exit("registry: no session id (pass one or run inside Claude Code)")
        with locked(p) as reg:
            reg["front"] = {"session_id": sid, "name": a.name, "updated": now()}
        print(json.dumps(reg["front"]))
    elif a.cmd == "get-front":
        print(json.dumps(load(p).get("front")))
    elif a.cmd == "list":
        reg = load(p)
        print(json.dumps(reg, ensure_ascii=False, indent=1) if a.json else render(reg))
    elif a.cmd in ("upsert", "spawn"):
        if not NAME_RE.match(a.name):
            sys.exit(f"registry: bad name '{a.name}' (letters, digits, - and _ only, <=64)")
        with locked(p) as reg:
            if a.cmd == "spawn" or a.new:
                old = reg["sessions"].get(a.name)
                # free = absent, or left by a spawn that never started (exited, no ids)
                if old and (old.get("job_id") or old.get("session_id") or old.get("state") != "exited"):
                    sys.exit(f"registry: name '{a.name}' is taken")
                reg["sessions"].pop(a.name, None)
            if a.cmd == "spawn" and [n for n in merged if n not in reg["sessions"]]:
                sys.exit(f"registry: unknown --merged-from source in '{a.merged_from}'")
            s = reg["sessions"].setdefault(a.name, {"state": "active"})
            for k in ("session_id", "job_id", "cwd", "topic", "model", "state"):
                if getattr(a, k, None):  # "" never overwrites (e.g. an empty $JOB)
                    s[k] = getattr(a, k)
            s["updated"] = now()
            if a.cmd == "spawn":
                prompt = compose(reg, a.name, request, merged)
        if a.cmd == "upsert":
            print(json.dumps({a.name: s}, ensure_ascii=False))
            return
        job = launch(p, a.name, ["spawn", a.name, a.cwd, a.model or "", a.mode or ""], prompt)
        if not job:
            sys.exit(f"registry: spawn of '{a.name}' failed; marked exited")
        with locked(p) as reg:
            for n in merged:
                reg["sessions"][n].update(state="merged", merged_into=a.name, updated=now())
        print(job)
    elif a.cmd == "resume":
        # refresh first: a forward from stale context must not start a second copy of a running worker
        agents = backend_agents()
        if agents is not None:
            with locked(p) as reg:
                refresh(reg, agents)
        reg = load(p)
        s = reg["sessions"].get(a.name) or {}
        if s.get("pid"):
            sys.exit(f"registry: '{a.name}' is running (pid {s['pid']}); forward with SendMessage instead")
        if not s.get("session_id"):
            sys.exit(f"registry: no session id for '{a.name}'")
        job = launch(p, a.name, ["resume", s["session_id"], a.name, s.get("cwd") or "."], compose(reg, a.name, request))
        if not job:
            sys.exit(f"registry: resume of '{a.name}' failed; marked exited")
        print(job)
    elif a.cmd == "mark":
        with locked(p) as reg:
            if a.name not in reg["sessions"]:
                sys.exit(f"registry: no session '{a.name}'")
            s = reg["sessions"][a.name]
            s["state"] = a.state
            if a.into:
                s["merged_into"] = a.into
            s["updated"] = now()
    elif a.cmd == "refresh":
        if a.file is None:
            agents = backend_agents()
            if agents is None:
                sys.exit("registry: `backend.sh list` failed")
        else:
            agents = json.load(sys.stdin if a.file == "-" else open(a.file))
        with locked(p) as reg:
            refresh(reg, agents)
        print(json.dumps(reg, ensure_ascii=False, indent=1) if a.json else render(reg))
    elif a.cmd == "record-result":
        if not record_result(p, a.session_id, None, a.text):
            sys.exit(f"registry: no worker with session id '{a.session_id}'")


if __name__ == "__main__":
    main()
