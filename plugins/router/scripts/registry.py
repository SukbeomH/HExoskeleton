#!/usr/bin/env python3
"""router registry: the front session's map of topic → worker session (stdlib only).

File: $ROUTER_REGISTRY, else <--data dir>/registry.json (a dir under ~/.claude/plugins/data only),
else $CLAUDE_PLUGIN_DATA/registry.json.
Shape: {"front": {"session_id", "name", "permission_mode", "updated", "mode_updated"} | null,
        "sessions": {<name>: {session_id, job_id, cwd, topic, model, state, pid, agent_state, waiting_for,
                              agent_type, last_result, merged_into, updated, backend, held, results}}}
state: active | idle | waiting (refresh only: an open prompt holds a live worker's turn) | exited | merged.
backend: absent = claude (backend.sh: `claude --bg` sessions), "codex" (backend-codex.sh: one codex-turn.py run per
spawn/resume on the worker's thread, session_id = thread id, job_id = the current run). held: a Codex worker's
follow-ups queued while a run is going; codex-run.py sends them as the next run when it ends. results: a Codex
worker's last 3 runs {job, at, text, chained: held follow-ups started right after it}.
Writes take an exclusive flock and replace the file atomically. Empty option values are ignored.

Trust: the front entry is written only by the plugin's hooks (router-hook.py: a user-typed /router:front registers
it, each front turn records its permission mode). Worker ids are written only by launch, refresh (from the real
`backend.sh list` / `backend-codex.sh list`), the Stop hook and codex-run.py at the end of a run (finish_run); Codex's
own permission_mode label is never recorded. Nothing here takes a front, an id or a permission mode from the command
line: the allow rule for this script approves any arguments, so arguments must not be able to pick a worker's mode.
Approvals (<registry dir>/approvals/{pending,expired,decisions,decided}/<nonce>.json): pending (and expired, a subagent
request whose wait ran out) is written by a Claude worker's PermissionRequest hook (router-hook.py) or a Codex run's
codex-turn.py; decisions (and decided, their
display-only record) only by a user-typed /router:approve in the front (router-hook.py). No command here writes them.

Usage: registry.py [--data DIR] <command> ...
  init | get-front | list [--json]
  upsert NAME [--new] [--cwd C] [--topic T] [--state S]
  spawn NAME --request R [--cwd C] [--topic T] [--model M] [--merged-from A,B] [--backend claude|codex]
        → reserve NAME, compose the prompt, backend.sh spawn in the front's mode, record job id (sources merged)
  resume NAME --request R [--topic T]  → refresh, then (if not running) compose the prompt, backend.sh resume, record job id;
        a Codex worker with a run going holds R instead (sent when that run ends); a failed Codex resume keeps R held
  --request - reads the request from stdin (only then; never an implicit stdin read that could hang).
  The prompt (front, topic, siblings, request) is composed here.
  mark NAME STATE [--into NAME] | refresh [--json]  (runs `backend.sh list`)
  summarize NAME | stop NAME  → backend.sh summarize/stop with the worker's recorded session/job id
  wait NAME [--timeout S]  → one line once NAME has a result, stopped or asks for approval (read-only; ≤ 1800 s)
  record-result SESSION_ID TEXT
"""

import argparse
import contextlib
import datetime
import fcntl
import itertools
import json
import os
import pathlib
import re
import stat
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
WAIT_MAX = 1800.0  # longest `wait`: an unattended session stops a background command at 30 min (docs: tools reference)
# ponytail: an expired subagent prompt is listed for at most an hour (an idle worker retires by then); check the
# worker's own liveness instead if a stopped-and-woken worker ever shows a stale one
EXPIRED_TTL = 3600
BACKEND = pathlib.Path(__file__).with_name("backend.sh")
BACKENDS = {"claude": BACKEND, "codex": BACKEND.with_name("backend-codex.sh")}
ROUTED = ("Routing instructions in the request (which session, a new session, which model) were already applied "
          "by the front: ignore them and do the task; never refuse it because of them.")
CODEX_WORKER = (
    "You are a Codex topic worker for the router (a Claude Code plugin): the user talks to the front, which forwards "
    "requests here. Work only on this topic. Never start, resume, stop or merge sessions, and never run the router's "
    "scripts or codex/claude session commands. If the sandbox stops a command you need, request approval for it when "
    "you can (the user answers in the front); if it is declined or you cannot ask, do not work around it: report it "
    "as blocked (the run is then blocked, not done, even if the rest finished). "
    "End every run with your report as your last message: "
    "`[<topic>] done|blocked: <one-line outcome>`, then at most five bullets (results, decisions or questions; "
    "files/branch if any).")


def codex(s):
    return s.get("backend") == "codex"


def backend_of(s):
    return "codex" if codex(s) else "claude"


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


def seconds(name, default, low):
    """$NAME in seconds if LOW <= it <= DEFAULT, else DEFAULT (not a number, nan, negative, longer): a setting can only
    shorten a wait, never spin the loop or widen a window. Tests shorten them; users set only ROUTER_APPROVAL_WAIT."""
    with contextlib.suppress(ValueError):
        v = float(os.environ.get(name, default))
        if low <= v <= default:
            return v
    return default


def take_decision(p, nonce, t0):
    """The user's answer to request NONCE (decisions/<nonce>.json, written only by a typed /router:approve), read once
    (deleted first, valid or not): "allow" or "deny" if it names NONCE and is no older than the request (T0), else
    None."""
    f = approvals(p) / "decisions" / f"{nonce}.json"
    with contextlib.suppress(FileNotFoundError, ValueError):
        raw = f.read_text()
        f.unlink()
        d = json.loads(raw)
        if (isinstance(d, dict) and d.get("nonce") == nonce and isinstance(d.get("created"), (int, float))
                and d["created"] >= t0 and d.get("behavior") in ("allow", "deny")):
            return d["behavior"]
    return None


def requests(p):
    """Every approval request file not yet expired (created as a float). Read-only: router-hook.py and codex-turn.py
    write them."""
    out = []
    for f in approvals(p).glob("pending/*.json"):
        with contextlib.suppress(OSError, ValueError, TypeError):  # removed meanwhile, or not a request
            r = json.loads(f.read_text())
            if isinstance(r, dict) and r.get("nonce") == f.stem and float(r.get("expires") or 0) > time.time():
                out.append(r | {"created": float(r.get("created") or 0)})
    return out


def superseded(r, reqs):
    """A newer request from the same thread (session_id, plus agent_id inside a subagent). Claude Code asks one
    prompt at a time per thread (5th live test), so R's prompt was answered elsewhere (claude attach): a late answer
    is ignored."""
    return bool(r.get("session_id")) and any(
        (o.get("session_id"), o.get("agent_id")) == (r.get("session_id"), r.get("agent_id"))
        and o["created"] > r["created"] for o in reqs)


def answered(r):
    """A subagent's request (agent_id) answered elsewhere (claude attach): its own transcript (r["transcript"]) holds
    a result, written after the request, for a tool_use with this exact tool and input. `claude agents` cannot tell:
    it shows the worker busy while its subagent waits (6th live test). Cheap: the file is read only once it has grown
    past r["size"], which then keeps the size read (a hook's own copy reads each growth once). Regular files only."""
    try:
        st = os.stat(r.get("transcript"))
        if not stat.S_ISREG(st.st_mode) or st.st_size <= r.get("size", 0):
            return False
        r["size"] = st.st_size
        with open(r["transcript"], encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except (OSError, TypeError):
        return False
    uses, after = set(), float(r.get("created") or 0)
    for line in lines:
        if '"tool_use"' not in line and '"tool_result"' not in line:
            continue
        with contextlib.suppress(ValueError, TypeError, AttributeError, KeyError):
            e = json.loads(line)
            for b in e["message"]["content"]:
                if b["type"] == "tool_use" and (b["name"], b["input"]) == (r.get("tool_name"), r.get("tool_input")):
                    uses.add(b["id"])
                elif b["type"] == "tool_result" and b["tool_use_id"] in uses:
                    ts = datetime.datetime.strptime(e["timestamp"], "%Y-%m-%dT%H:%M:%S.%fZ")
                    if ts.replace(tzinfo=datetime.timezone.utc).timestamp() > after:
                        return True  # not an earlier identical call's result: that one predates the request
    return False


def expired(p):
    """Subagent prompts whose router wait ran out (approvals/expired/<nonce>.json, router-hook.py). Claude Code shows a
    background subagent's prompt in claude attach only once its hook has ended (7th live test), so the prompt still
    holds the subagent: listed until its transcript has the result (answered), the same subagent asked again
    (superseded) or EXPIRED_TTL passed. /router:approve never answers them. Read-only."""
    out = []
    for f in approvals(p).glob("expired/*.json"):
        with contextlib.suppress(OSError, ValueError, TypeError, KeyError, AttributeError):
            r = json.loads(f.read_text())
            if r.get("nonce") == f.stem and 0 <= time.time() - float(r["created"]) < EXPIRED_TTL:
                out.append(r | {"created": float(r["created"])})
    reqs = requests(p) + out
    return [r for r in out if not superseded(r, reqs) and not answered(r)]


def pending(p):
    """Open approval requests, oldest first. Not open: answered elsewhere (claude attach). Claude Code does not stop
    the hook then, so a request is hidden until its hook ends when the same thread asked again (superseded), when a
    subagent's transcript has the result (answered), or when its hook saw it on the prompt ("seen") and `claude agents`
    no longer shows its worker there."""
    reqs = requests(p)
    out = [r for r in reqs if not superseded(r, reqs) and not answered(r)]
    if any(r.get("seen") for r in out):
        agents = backend_agents()
        out = [r for r in out if not r.get("seen") or on_prompt(agents, r.get("session_id"), r.get("job_id"))
               is not False]
    return sorted(out, key=lambda r: r["created"])


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
    alt = ("(Codex: no attach; unanswered = denied when it expires)" if r.get("backend") == "codex"
           else f"(or claude attach {clean(r.get('job_id') or '<job_id>', 64)})")
    return [f"approval {n}: {describe(r)}", f"approve: /router:approve {n}   deny: /router:approve {n} deny   {alt}"]


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


def record_result(p, session_id, job_id, text, agent_type=None, busy=False):
    """Stop hook: store the worker's last reply; the turn ended, so active → idle (merged stays merged), unless BUSY
    (its background subagent still runs). Unknown session → no write at all."""
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
            clear_waiting(s)
            if s.get("state") != "merged":
                s["state"] = "active" if busy else "idle"
            s["updated"] = now()
    return name


def finish_run(reg, job_id, thread_id, text):
    """codex-run.py, under the lock: a Codex run ended. Like the Stop hook, its last message → last_result and idle
    (merged stays merged). Returns (name, held follow-ups to send as the next run); with some, the worker stays active.
    Matched by job id only: every run of a worker shares its thread id."""
    name = find_worker(reg, None, job_id)
    if not name:
        return None, []
    s = reg["sessions"][name]
    held = [] if s.get("state") == "merged" else s.pop("held", [])
    s.update(session_id=thread_id, last_result=text[:RESULT_MAX], pid=None, updated=now())
    # the last runs' results: with held follow-ups the next run starts at once and its result replaces last_result
    # before the front may have read this one (7th live test), so render lists a chain's earlier results
    s["results"] = (s.get("results", []) + [{"job": job_id, "at": now(), "text": text[:RESULT_MAX],
                                             **({"chained": True} if held else {})}])[-3:]
    if s.get("state") != "merged":
        s["state"] = "active" if held else "idle"
    return name, held


def requeue(p, name, held):
    """Held follow-ups whose run failed to start go back in front of the queue: the next forward sends them."""
    if held:
        with locked(p) as reg:
            s = reg["sessions"][name]
            s["held"] = held + s.get("held", [])


def clear_waiting(s):
    """The worker's prompt got its answer or its turn moved on: drop what refresh saw while it waited, so it renders
    running or idle again, not WAITING or `idle/blocked`. The next refresh records the current state."""
    s.pop("waiting_for", None)
    if s.get("agent_state") == "blocked":
        s.pop("agent_state")
    if s.get("state") == "waiting":
        s["state"] = "active"


def unblock(p, name):
    """router-hook.py: a relayed decision, an answer in claude attach, or a report (SendMessage) from NAME."""
    with locked(p) as reg:
        if name in reg["sessions"]:
            clear_waiting(reg["sessions"][name])


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
        # job id first: a resume that starts a copy gets a new job/session while session_id is stale. A Codex worker:
        # job id only (all its runs share the thread id); a finished run (done/failed) leaves it idle, not exited.
        a = by_job.get(s.get("job_id")) or (None if codex(s) else by_sid.get(s.get("session_id")))
        if a is None:
            s.update(state="exited", pid=None)
            continue
        if codex(s) and a.get("state") in ("done", "failed"):
            s.update(session_id=a.get("sessionId") or s.get("session_id"), pid=None, agent_state=a["state"],
                     state="idle", updated=now())
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


def launch(p, name, args, prompt, backend="claude"):
    """Run `backend.sh ARGS` (backend-codex.sh for codex) with PROMPT on stdin; its stdout is the job id. Record it on
    NAME (state active), or mark NAME exited. pid/agent_state are cleared either way: they describe the previous
    process."""
    r = subprocess.run(["bash", str(BACKENDS[backend]), *args], input=prompt, stdout=subprocess.PIPE, text=True,
                       env=env(p, backend))
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


def env(p, backend):
    """backend-codex.sh keeps its runs next to the registry and its supervisor writes results there: tell it where
    (--data leaves $ROUTER_REGISTRY unset). backend.sh gets the environment unchanged."""
    return {**os.environ, "ROUTER_REGISTRY": str(p)} if backend == "codex" else None


def refresh_all(p, reg, claude_agents):
    """refresh REG (held under the lock) from CLAUDE_AGENTS (`backend.sh list`, read before taking the lock) plus
    `backend-codex.sh list` when there are Codex workers. Codex runs are local files, listed here under the lock, so
    a run recorded meanwhile is never missed. False (nothing changed) if a list failed."""
    cx = []
    if any(codex(s) for s in reg["sessions"].values()):
        cx = None
        r = subprocess.run(["bash", str(BACKENDS["codex"]), "list"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           text=True, env=env(p, "codex"))
        with contextlib.suppress(ValueError):
            cx = json.loads(r.stdout) if r.returncode == 0 else None
    if claude_agents is None or not isinstance(cx, list):
        return False
    refresh(reg, claude_agents + cx)
    return True


def compose(reg, name, request, merged_from=()):
    """The worker's prompt: where to report (current front name), its topic, its siblings, a note that routing
    directives were already applied, then the request. A Codex worker cannot SendMessage: its last message is the
    report, and it gets the worker rules here (no topic-worker agent on Codex)."""
    sibs = [f"{n} — {s.get('topic') or '-'}" for n, s in sorted(reg["sessions"].items())
            if n != name and n not in merged_from and s.get("state") != "merged"
            and (s.get("job_id") or s.get("session_id"))]
    cx = codex(reg["sessions"][name])
    how = ("you cannot message it: your last message is your report (the router records it, the front reads it)."
           if cx else "send results there with SendMessage.")
    head = [f"Router front: @{(reg.get('front') or {}).get('name')} — {how}",
            f"Topic: {reg['sessions'][name].get('topic') or '-'}",
            f"Siblings: {'; '.join(sibs) or 'none'}"]
    if merged_from:
        head.append(f"Merged from: {', '.join(merged_from)}")
    if cx:
        head.append(CODEX_WORKER)
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
    without a refresh: its PermissionRequest hook or codex-turn.py is waiting for the user's answer right now), then
    recent decisions. A subagent's prompt whose router wait ran out (expired) shows as WAITING on claude attach."""
    front = reg.get("front") or {}
    asks, late = (pending(p), expired(p)) if p else ([], [])
    lines = [f"[router] front: @{front.get('name') or '?'} (mode {front_mode(reg)}) — workers:"]
    for name, s in sorted(reg["sessions"].items()):
        last = " ".join((s.get("last_result") or "").split())[:width]
        extra = " codex" if codex(s) else ""  # never SendMessage: route forwards with `resume` (held while it runs)
        extra += f" → {s['merged_into']}" if s.get("merged_into") else ""
        state, pid, cc = s.get("state", "?"), s.get("pid"), s.get("agent_state")
        mine = [r for r in asks if r.get("worker") == name]
        if alive(pid):
            extra += f" pid {pid}"
        elif pid and state in ("active", "idle", "waiting"):
            state = "exited"  # recorded process is gone (e.g. idle retire); shown only, refresh records it
        if s.get("held"):
            extra += f" held {len(s['held'])}"
        # its subagent's prompt the router no longer relays: it still holds the subagent, even when Stop said idle
        stale = [r for r in late if r.get("worker") == name and state not in ("exited", "merged")]
        if mine:
            state = "waiting"
        if state == "waiting":
            how = "user types /router:approve below, or runs:" if mine else "user must run:"
            what = s.get("waiting_for") or ("permission prompt" if mine else "prompt")
            # a Codex run's request has no attach fallback (its app-server's only client is codex-turn.py)
            how = "user types /router:approve below" if codex(s) else f"{how} claude attach {s.get('job_id')}"
            state = f"WAITING: {what} — {how};"
        elif stale:
            state = f"WAITING: subagent prompt — claude attach {s.get('job_id')} to answer;"
        elif cc and cc not in ("working", "done"):  # those only restate (or, after the turn, contradict) the state
            state += "/" + cc
        lines.append(
            f"- {name} [{state}{extra}]"
            f" topic: {s.get('topic') or '-'} | cwd: {s.get('cwd') or '-'} | last: {last or '-'}"
        )
        chain = list(itertools.takewhile(lambda r: r.get("chained"), reversed((s.get("results") or [])[:-1])))
        lines += ["  earlier result (its held follow-ups ran right after): "
                  + " ".join(str(r.get("text")).split())[:width] for r in reversed(chain)]
        lines += ["  " + line for r in mine for line in approval_lines(r)]
        lines += [f"  subagent prompt (router wait over, /router:approve no longer answers it): {describe(r)}"
                  for r in stale]
    if not reg["sessions"]:
        lines.append("- (none)")
    done = decided(p) if p else []
    if done:
        lines.append("[router] decided by the user's typed /router:approve (last 10 min; the worker's report tells "
                     "what then ran):")
    for d in done:
        when, verdict = time.strftime("%H:%M:%S", time.localtime(d["created"])), d.get("behavior") == "allow"
        lines.append(f"- {when} {'approved' if verdict else 'denied'} {clean(d.get('nonce'), 8)} "
                     f"{clean(d.get('what') or '', 120)}")
    return "\n".join(lines)


def decided(p, window=600, keep=5):
    """The last KEEP decisions typed in the front within WINDOW seconds, oldest first: approve (router-hook.py)
    writes approvals/decided/<nonce>.json, since the blocked prompt never reaches the front's model. Display only."""
    out = []
    for f in approvals(p).glob("decided/*.json"):
        with contextlib.suppress(OSError, ValueError, TypeError, KeyError):
            d = json.loads(f.read_text())
            if 0 <= time.time() - float(d["created"]) < window:  # not nan, inf or future
                out.append(d | {"created": float(d["created"])})
    return sorted(out, key=lambda d: d["created"])[-keep:]


def wait(p, name, timeout):
    """`wait NAME`: the front runs it as a background Bash command, whose end starts a turn in an idle front (7th live
    test), so a Codex worker's result reaches the user without a message. Blocks until NAME records a result, stops
    running or opens an approval request newer than this wait, then prints one line; after TIMEOUT a "still running"
    line. Read-only: it polls the registry's and the requests' mtimes, never takes the lock or writes."""
    s0 = load(p)["sessions"].get(name)
    if s0 is None:
        sys.exit(f"registry: no session '{name}'")
    t0, last, poll = time.time(), None, seconds("ROUTER_POLL_INTERVAL", 0.5, 0.01)
    head = f"[router] wait {name}{' (codex)' if codex(s0) else ''}:"

    def run(s):
        return s.get("last_result"), (s.get("results") or [{}])[-1].get("job")

    while True:
        stamp = []
        for f in (p, approvals(p) / "pending"):
            with contextlib.suppress(OSError):
                stamp.append((f.stat().st_ino, f.stat().st_mtime_ns))
        if stamp != last:
            last, s = stamp, load(p)["sessions"].get(name) or {}
            new = [r for r in requests(p) if r.get("worker") == name and r["created"] >= t0]
            if new:  # an older one was told already: a wait started again after it must not return at once
                return print(f"{head} WAITING: approval {describe(new[0])} — the user types /router:approve (bare "
                             "lists it)")
            if run(s) != run(s0) or s.get("state") not in ("active", "waiting"):
                more = " (held follow-ups are running now: wait again)" if s.get("state") == "active" else ""
                return print(f"{head} {s.get('state') or 'gone'}{more} — last: {clean(s.get('last_result') or '-')}")
        if time.time() >= t0 + timeout:
            return print(f"{head} still running after {timeout:g} s — its result shows in the [router] list later")
        time.sleep(poll)


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
    sp.add_argument("--backend", choices=tuple(BACKENDS), default="claude", help="codex: a Codex CLI worker")
    rs = sub.add_parser("resume")
    rs.add_argument("name")
    rs.add_argument("--topic", help="the topic, widened by this request (also in the prompt)")
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
    wt = sub.add_parser("wait")
    wt.add_argument("name")
    wt.add_argument("--timeout", type=float, default=600.0, help=f"seconds (default 600, at most {WAIT_MAX:g})")
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
            if getattr(a, "backend", "claude") != "claude":
                s["backend"] = a.backend
            s["updated"] = now()
            if a.cmd == "spawn":
                prompt, mode = compose(reg, a.name, request, merged), front_mode(reg)
        if a.cmd == "upsert":
            print(json.dumps({a.name: s}, ensure_ascii=False))
            return
        job = launch(p, a.name, ["spawn", a.name, a.cwd, a.model or "", mode], prompt, a.backend)
        if not job:
            sys.exit(f"registry: spawn of '{a.name}' failed; marked exited")
        with locked(p) as reg:
            for n in merged:
                reg["sessions"][n].update(state="merged", merged_into=a.name, updated=now())
        print(job)
    elif a.cmd == "resume":
        # refresh first: a forward from stale context must not start a second copy of a running worker
        agents = backend_agents()
        with locked(p) as reg:
            refresh_all(p, reg, agents)
            s = reg["sessions"].get(a.name) or {}
            if a.topic:
                s["topic"] = a.topic
            # a Codex run going (live supervisor): hold the request, its supervisor sends it as the next run
            hold = codex(s) and s.get("state") == "active" and alive(s.get("pid")) and bool(s.get("session_id"))
            if hold:
                s.setdefault("held", []).append(request)
            held = [] if hold or not codex(s) or not s.get("session_id") else s.pop("held", [])
        if hold:
            print(f"held: '{a.name}' is running (Codex); the request goes out when its current run ends")
            return
        if s.get("pid") and not codex(s):
            sys.exit(f"registry: '{a.name}' is running (pid {s['pid']}); forward with SendMessage instead")
        if not s.get("session_id"):
            sys.exit(f"registry: no session id for '{a.name}'")
        args = ["resume", s["session_id"], a.name, s.get("cwd") or ".", front_mode(reg)]
        args += [s.get("model") or ""] if codex(s) else []
        job = launch(p, a.name, args, compose(reg, a.name, "\n\n".join([*held, request])), backend_of(s))
        if not job:
            if codex(s):  # e.g. thread/resume refused: nothing reached Codex, so its request waits with the held ones
                requeue(p, a.name, [*held, request])
                sys.exit(f"registry: resume of '{a.name}' failed; marked exited. Its request is kept (held "
                         f"{len(held) + 1}) and goes out first with the next forward: do not send it again")
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
        with locked(p) as reg:
            if not refresh_all(p, reg, agents):
                sys.exit("registry: `backend.sh list` or `backend-codex.sh list` failed")
        print(json.dumps(reg, ensure_ascii=False, indent=1) if a.json else render(reg, p=p))
    elif a.cmd in ("summarize", "stop"):  # ids come from the registry, never from the command line
        s = load(p)["sessions"].get(a.name) or {}
        key = "session_id" if a.cmd == "summarize" else "job_id"
        if not s.get(key):
            sys.exit(f"registry: no {key} for '{a.name}'")
        extra = [s.get("model") or ""] if a.cmd == "summarize" else []
        b = backend_of(s)
        rc = subprocess.run(["bash", str(BACKENDS[b]), a.cmd, s[key], *extra], stdin=subprocess.DEVNULL,
                            env=env(p, b)).returncode
        if a.cmd == "stop" and rc == 0:  # a stopped Codex run records nothing (no finish_run): mark it, `wait` ends
            with locked(p) as reg:
                w = reg["sessions"].get(a.name) or {}
                if w.get("job_id") == s[key] and w.get("state") != "merged":  # not a run started meanwhile
                    w.update(state="exited", pid=None, updated=now())  # held stays: the next forward sends it
        sys.exit(rc)
    elif a.cmd == "wait":
        wait(p, a.name, min(a.timeout, WAIT_MAX) if a.timeout >= 0 else 0)  # nan → 0: never hang
    elif a.cmd == "record-result":
        if not record_result(p, a.session_id, None, a.text):
            sys.exit(f"registry: no worker with session id '{a.session_id}'")


if __name__ == "__main__":
    main()
