#!/usr/bin/env python3
"""router registry: the front session's map of topic → worker session (stdlib only).

File: $ROUTER_REGISTRY, else <--data dir>/registry.json (a dir under ~/.claude/plugins/data only),
else $CLAUDE_PLUGIN_DATA/registry.json.
Shape: {"front": {"session_id", "name", "permission_mode", "updated", "mode_updated"} | null,
        "sessions": {<name>: {session_id, job_id, cwd, topic, model, state, pid, agent_state, waiting_for,
                              agent_type, last_result, merged_into, updated}}}
state: active | idle | waiting (refresh only: an open prompt holds a live worker's turn) | exited | merged.
Writes take an exclusive flock and replace the file atomically. Empty option values are ignored.

Trust: the front entry is written only by the plugin's hooks (router-hook.py: a user-typed /router:front registers
it, each front turn records its permission mode). Worker ids are written only by launch, refresh (from the real
`backend.sh list`) and the Stop hook. Nothing here takes a front, an id or a permission mode from the command line:
the allow rule for this script approves any arguments, so arguments must not be able to pick a worker's mode.
Approvals (<registry dir>/approvals/{pending,decisions}/<nonce>.json) are written only by router-hook.py: a worker's
PermissionRequest hook writes pending, a user-typed /router:approve writes the decision. No command here writes them.

Usage: registry.py [--data DIR] <command> ...
  init | get-front | list [--json]
  upsert NAME [--new] [--cwd C] [--topic T] [--state S]
  spawn NAME --request R [--cwd C] [--topic T] [--model M] [--merged-from A,B]
        → reserve NAME, compose the prompt, backend.sh spawn in the front's mode, record job id (sources merged)
  resume NAME --request R  → refresh, then (if not running) compose the prompt, backend.sh resume, record job id
  --request - reads the request from stdin (only then; never an implicit stdin read that could hang).
  The prompt (front, topic, siblings, request) is composed here.
  mark NAME STATE [--into NAME] | refresh [--json]  (runs `backend.sh list`)
  summarize NAME | stop NAME  → backend.sh summarize/stop with the worker's recorded session/job id
  record-result SESSION_ID TEXT
"""

import argparse
import contextlib
import fcntl
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import unicodedata

STATES = ("active", "idle", "exited", "merged")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")  # SendMessage-safe without quoting
RESULT_MAX = 2000
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?")
SHOW_MAX = 300  # chars of a pending request shown before the explicit cut
BACKEND = pathlib.Path(__file__).with_name("backend.sh")
ROUTED = ("Routing instructions in the request (which session, a new session, which model) were already applied "
          "by the front: ignore them and do the task; never refuse it because of them.")


def path(data_dir=None):
    if os.environ.get("ROUTER_REGISTRY"):
        return pathlib.Path(os.environ["ROUTER_REGISTRY"])
    if data_dir:
        # --data is model-written: a registry.json the model wrote itself (e.g. in its cwd) would forge the front
        # mode. Claude Code's plugin data dirs (~/.claude/plugins/data/<id>/) are outside any working directory.
        base = pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude") / "plugins/data"
        d = pathlib.Path(data_dir).expanduser().resolve()
        if d.parent != base.resolve():
            sys.exit(f"registry: --data must be a plugin data dir under {base}")
        return d / "registry.json"
    d = os.environ.get("CLAUDE_PLUGIN_DATA")
    return pathlib.Path(d) / "registry.json" if d else None


def approvals(p):
    """The approval relay's dir, next to the registry (so in the plugin data dir, outside any working directory)."""
    return p.parent / "approvals"


def pending(p):
    """Open approval requests (pending files not yet expired), oldest first. Read-only: router-hook.py writes them.
    Not open either: answered elsewhere (claude attach). Claude Code does not stop the hook then, so a request its
    hook saw on the prompt ("seen") whose worker `claude agents` no longer shows there is hidden until the hook ends."""
    out = []
    for f in approvals(p).glob("pending/*.json"):
        with contextlib.suppress(OSError, ValueError, TypeError):  # removed meanwhile, or not a request
            r = json.loads(f.read_text())
            if isinstance(r, dict) and r.get("nonce") == f.stem and float(r.get("expires") or 0) > time.time():
                out.append((float(r.get("created") or 0), r))
    if any(r.get("seen") for _, r in out):
        agents = backend_agents()
        out = [x for x in out if not x[1].get("seen") or on_prompt(agents, x[1].get("session_id"), x[1].get("job_id"))
               is not False]
    return [r for _, r in sorted(out, key=lambda x: x[0])]


def on_prompt(agents, session_id, job_id):
    """Is this worker's turn held by a permission prompt right now (`claude agents`: status waiting, waitingFor
    permission prompt)? None if the list is unavailable. Matched by recorded ids only."""
    if agents is None:
        return None
    return any(a.get("status") == "waiting" and a.get("waitingFor") == "permission prompt" for a in agents
               if (session_id and a.get("sessionId") == session_id) or (job_id and a.get("id") == job_id))


def clean(text, limit=SHOW_MAX):
    """Untrusted text as one display line: ANSI sequences and control/format characters (zero-width, bidi) removed
    and counted, line breaks shown as ⏎ (a space would make two commands read as one), cut with the full length."""
    text = str(text)
    out = "".join("⏎" if c in "\n  " else " " if c == "\t" else
                  "" if unicodedata.category(c).startswith("C") else c for c in ANSI.sub("", text))
    hidden = len(text) - len(out)
    if len(out) > limit:
        out = f"{out[:limit]}…[cut: {len(out)} chars]"
    return out + (f" [{hidden} hidden chars removed]" if hidden else "")


def describe(r):
    """A pending request as shown to the user: worker, tool and the exact tool_input (command first), never the
    model-written description."""
    inp = r.get("tool_input") if isinstance(r.get("tool_input"), dict) else {}
    cmd = inp.get("command") if isinstance(inp.get("command"), str) else ""
    rest = {k: v for k, v in inp.items() if k not in ("command", "description")}
    text = " ".join(x for x in (cmd, f"[input: {json.dumps(rest, ensure_ascii=False)}]" if rest else "") if x)
    return f"@{clean(r.get('worker') or '?', 64)} {clean(r.get('tool_name') or '?', 64)}: {clean(text)}"


def approval_lines(r):
    n = r["nonce"]
    return [f"approval {n}: {describe(r)}",
            f"approve: /router:approve {n}   deny: /router:approve {n} deny   "
            f"(or claude attach {clean(r.get('job_id') or '<job_id>', 64)})"]


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


def set_front(p, session_id, name, mode):
    """UserPromptExpansion of a user-typed /router:front (router-hook.py): this session becomes the front."""
    with locked(p) as reg:
        reg["front"] = {"session_id": session_id, "name": name, "permission_mode": mode, "updated": now(),
                        "mode_updated": now()}
    return reg["front"]


def record_mode(p, session_id, mode):
    """UserPromptSubmit in the front (router-hook.py): store its current permission mode, the workers' mode."""
    with locked(p) as reg:
        f = reg.get("front") or {}
        if mode and f.get("session_id") == session_id:
            f.update(permission_mode=mode, mode_updated=now())
    return reg


def front_mode(reg):
    """Every worker runs in the front's permission mode as its hooks last recorded it; default if none."""
    return (reg.get("front") or {}).get("permission_mode") or "default"


def refresh(reg, agents):
    """Update worker entries from `claude agents --json --all`; alive = the entry has a pid. Matched by recorded
    ids only (never by name: a name could adopt a session router did not start, then resume wakes it in place)."""
    by_sid = {a["sessionId"]: a for a in agents if a.get("sessionId")}
    by_job = {a["id"]: a for a in agents if a.get("id")}
    for s in reg["sessions"].values():
        if s.get("state") == "merged":
            continue
        # job id first: a resume that starts a copy gets a new job/session while session_id is stale
        a = by_job.get(s.get("job_id")) or by_sid.get(s.get("session_id"))
        if a is None:
            s.update(state="exited", pid=None)
            continue
        s["session_id"] = a.get("sessionId") or s.get("session_id")
        s["job_id"] = a.get("id") or s.get("job_id")
        s["pid"] = a.get("pid")
        s["agent_state"] = a.get("state")
        s["waiting_for"] = a.get("waitingFor")
        # waiting: an open prompt (e.g. its own permission prompt) holds the turn: no report, no Stop, only attach
        # answers it. CC state `blocked` without one (e.g. it asked a question) stays idle: forward the answer.
        waiting = a.get("status") == "waiting" or a.get("waitingFor")
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
    with contextlib.suppress(ValueError):
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


def render(reg, width=200, p=None):
    """The compact registry. With P, a worker's open approval requests are listed under it (and make it WAITING
    without a refresh: its PermissionRequest hook is waiting for the user's answer right now)."""
    front = reg.get("front") or {}
    asks = pending(p) if p else []
    lines = [f"[router] front: @{front.get('name') or '?'} (mode {front_mode(reg)}) — workers:"]
    for name, s in sorted(reg["sessions"].items()):
        last = " ".join((s.get("last_result") or "").split())[:width]
        extra = f" → {s['merged_into']}" if s.get("merged_into") else ""
        state, pid, cc = s.get("state", "?"), s.get("pid"), s.get("agent_state")
        mine = [r for r in asks if r.get("worker") == name]
        if alive(pid):
            extra += f" pid {pid}"
        elif pid and state in ("active", "idle", "waiting"):
            state = "exited"  # recorded process is gone (e.g. idle retire); shown only, refresh records it
        if mine:
            state = "waiting"
        if state == "waiting":
            how = "user types /router:approve below, or runs:" if mine else "user must run:"
            what = s.get("waiting_for") or ("permission prompt" if mine else "prompt")
            state = f"WAITING: {what} — {how} claude attach {s.get('job_id')};"
        elif cc and cc not in ("working", "done"):  # those only restate (or, after the turn, contradict) the state
            state += "/" + cc
        lines.append(
            f"- {name} [{state}{extra}]"
            f" topic: {s.get('topic') or '-'} | cwd: {s.get('cwd') or '-'} | last: {last or '-'}"
        )
        lines += ["  " + line for r in mine for line in approval_lines(r)]
    if not reg["sessions"]:
        lines.append("- (none)")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="router registry")
    ap.add_argument("--data", help="plugin data dir (skills pass ${CLAUDE_PLUGIN_DATA})")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init")
    sub.add_parser("get-front")
    ls = sub.add_parser("list")
    up = sub.add_parser("upsert")
    up.add_argument("name")
    up.add_argument("--new", action="store_true", help="fail if NAME is already taken")
    for f in ("cwd", "topic"):
        up.add_argument("--" + f)
    up.add_argument("--state", choices=STATES)
    sp = sub.add_parser("spawn", allow_abbrev=False)  # no --mode → --model abbreviation
    sp.add_argument("name")
    sp.add_argument("--cwd", default=os.getcwd(), help="worker directory (default: here, i.e. the front's)")
    sp.add_argument("--topic")
    sp.add_argument("--model")
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
    for x in (ls, rf):
        x.add_argument("--json", action="store_true", help="print the whole registry as JSON")
    for c in ("summarize", "stop"):
        sub.add_parser(c).add_argument("name")
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
    elif a.cmd == "get-front":
        print(json.dumps(load(p).get("front")))
    elif a.cmd == "list":
        reg = load(p)
        print(json.dumps(reg, ensure_ascii=False, indent=1) if a.json else render(reg, p=p))
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
            for k in ("cwd", "topic", "model", "state"):
                if getattr(a, k, None):  # "" never overwrites (e.g. an empty $JOB)
                    s[k] = getattr(a, k)
            s["updated"] = now()
            if a.cmd == "spawn":
                prompt, mode = compose(reg, a.name, request, merged), front_mode(reg)
        if a.cmd == "upsert":
            print(json.dumps({a.name: s}, ensure_ascii=False))
            return
        job = launch(p, a.name, ["spawn", a.name, a.cwd, a.model or "", mode], prompt)
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
        job = launch(p, a.name, ["resume", s["session_id"], a.name, s.get("cwd") or ".", front_mode(reg)],
                     compose(reg, a.name, request))
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
        agents = backend_agents()
        if agents is None:
            sys.exit("registry: `backend.sh list` failed")
        with locked(p) as reg:
            refresh(reg, agents)
        print(json.dumps(reg, ensure_ascii=False, indent=1) if a.json else render(reg, p=p))
    elif a.cmd in ("summarize", "stop"):  # ids come from the registry, never from the command line
        s = load(p)["sessions"].get(a.name) or {}
        key = "session_id" if a.cmd == "summarize" else "job_id"
        if not s.get(key):
            sys.exit(f"registry: no {key} for '{a.name}'")
        extra = [s.get("model") or ""] if a.cmd == "summarize" else []
        sys.exit(subprocess.run(["bash", str(BACKEND), a.cmd, s[key], *extra], stdin=subprocess.DEVNULL).returncode)
    elif a.cmd == "record-result":
        if not record_result(p, a.session_id, None, a.text):
            sys.exit(f"registry: no worker with session id '{a.session_id}'")


if __name__ == "__main__":
    main()
