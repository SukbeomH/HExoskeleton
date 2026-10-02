#!/usr/bin/env python3
"""router registry: the front session's map of topic → worker session (stdlib only).

File: $ROUTER_REGISTRY, else <--data dir>/registry.json, else $CLAUDE_PLUGIN_DATA/registry.json.
Shape: {"front": {"session_id", "name", "updated"} | null,
        "sessions": {<name>: {session_id, job_id, cwd, topic, model, state, pid, agent_state,
                              agent_type, last_result, merged_into, updated}}}
Writes take an exclusive flock and replace the file atomically. Empty option values are ignored.

Usage: registry.py [--data DIR] <command> ...
  init | set-front [SESSION_ID] [--name N] | get-front | list [--json]
  upsert NAME [--new] [--session-id S] [--job-id J] [--cwd C] [--topic T] [--state S]
  spawn NAME PROMPT_FILE --cwd C [--topic T] [--model M] [--mode P]  → reserve NAME, backend.sh spawn, record job id
  resume NAME PROMPT_FILE                                → backend.sh resume, record job id
  mark NAME STATE [--into NAME] | refresh [FILE|-]  (FILE = `backend.sh list` output)
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
        s["state"] = "exited" if not a.get("pid") else ("active" if a.get("status") == "busy" else "idle")
        s["updated"] = now()


def launch(p, name, args):
    """Run `backend.sh ARGS`; its stdout is the job id. Record it on NAME (state active), or mark NAME exited."""
    r = subprocess.run(["bash", str(BACKEND), *args], stdout=subprocess.PIPE, text=True)
    job = r.stdout.strip() if r.returncode == 0 else ""
    with locked(p) as reg:
        s = reg["sessions"][name]
        s.update({"job_id": job, "state": "active"} if job else {"state": "exited", "pid": None})
        s["updated"] = now()
    return job


def render(reg, width=200):
    front = reg.get("front") or {}
    lines = [f"[router] front: @{front.get('name') or '?'} — workers:"]
    for name, s in sorted(reg["sessions"].items()):
        last = " ".join((s.get("last_result") or "").split())[:width]
        extra = f" → {s['merged_into']}" if s.get("merged_into") else ""
        lines.append(
            f"- {name} [{s.get('state', '?')}{'/' + s['agent_state'] if s.get('agent_state') else ''}{extra}]"
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
    ls.add_argument("--json", action="store_true")
    up = sub.add_parser("upsert")
    up.add_argument("name")
    up.add_argument("--new", action="store_true", help="fail if NAME is already taken")
    for f in ("session-id", "job-id", "cwd", "topic"):
        up.add_argument("--" + f)
    up.add_argument("--state", choices=STATES)
    sp = sub.add_parser("spawn")
    sp.add_argument("name")
    sp.add_argument("prompt_file")
    sp.add_argument("--cwd", required=True)
    sp.add_argument("--topic")
    sp.add_argument("--model")
    sp.add_argument("--mode", help="permission mode for the worker")
    rs = sub.add_parser("resume")
    rs.add_argument("name")
    rs.add_argument("prompt_file")
    mk = sub.add_parser("mark")
    mk.add_argument("name")
    mk.add_argument("state", choices=STATES)
    mk.add_argument("--into")
    rf = sub.add_parser("refresh")
    rf.add_argument("file", nargs="?", default="-")
    rr = sub.add_parser("record-result")
    rr.add_argument("session_id")
    rr.add_argument("text")
    a = ap.parse_args(argv)

    p = path(a.data)
    if p is None:
        sys.exit("registry: set ROUTER_REGISTRY, --data or CLAUDE_PLUGIN_DATA")
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
            if (a.cmd == "spawn" or a.new) and a.name in reg["sessions"]:
                sys.exit(f"registry: name '{a.name}' is taken")
            s = reg["sessions"].setdefault(a.name, {"state": "active"})
            for k in ("session_id", "job_id", "cwd", "topic", "model", "state"):
                if getattr(a, k, None):  # "" never overwrites (e.g. an empty $JOB)
                    s[k] = getattr(a, k)
            s["updated"] = now()
        if a.cmd == "upsert":
            print(json.dumps({a.name: s}, ensure_ascii=False))
            return
        job = launch(p, a.name, ["spawn", a.name, a.cwd, a.prompt_file, a.model or "", a.mode or ""])
        if not job:
            sys.exit(f"registry: spawn of '{a.name}' failed; marked exited")
        print(job)
    elif a.cmd == "resume":
        s = load(p)["sessions"].get(a.name) or {}
        if not s.get("session_id"):
            sys.exit(f"registry: no session id for '{a.name}' (run refresh first)")
        job = launch(p, a.name, ["resume", s["session_id"], a.name, s.get("cwd") or ".", a.prompt_file])
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
        agents = json.load(sys.stdin if a.file == "-" else open(a.file))
        with locked(p) as reg:
            refresh(reg, agents)
        print(render(reg))
    elif a.cmd == "record-result":
        if not record_result(p, a.session_id, None, a.text):
            sys.exit(f"registry: no worker with session id '{a.session_id}'")


if __name__ == "__main__":
    main()
