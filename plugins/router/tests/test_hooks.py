#!/usr/bin/env python3
"""router-hook.py checks: front registered only by a user-typed /router:front (UserPromptExpansion), front-only
mode recording and injection, worker-only Stop recording, silent exit 0 otherwise.
Usage: python3 plugins/router/tests/test_hooks.py"""

import atexit
import json
import os
import pathlib
import shutil
import subprocess
import tempfile

HOOK = pathlib.Path(__file__).resolve().parent.parent / "hooks/router-hook.py"
TMP = pathlib.Path(tempfile.mkdtemp())
atexit.register(shutil.rmtree, TMP, True)
DATA = TMP / "data"  # hooks get CLAUDE_PLUGIN_DATA from Claude Code
REG = DATA / "registry.json"
BIN = TMP / "bin"  # stub `claude`: `claude agents --json --all` names the sessions (front name lookup)
BIN.mkdir()
(BIN / "claude").write_text("""#!/usr/bin/env bash
[ "$1" = agents ] && echo '[{"kind": "interactive", "sessionId": "front-uuid", "name": "boss", "pid": 1},
  {"kind": "background", "id": "aaaa1111", "sessionId": "w-uuid", "name": "api", "pid": 2}]'
""")
(BIN / "claude").chmod(0o755)


def run(payload, **env):
    e = {k: v for k, v in os.environ.items() if k not in ("ROUTER_REGISTRY", "CLAUDE_JOB_DIR")}
    e.update(CLAUDE_PLUGIN_DATA=str(DATA), PATH=f"{BIN}{os.pathsep}{os.environ['PATH']}", **env)
    r = subprocess.run([str(HOOK)], input=json.dumps(payload), env=e, capture_output=True, text=True)
    assert r.returncode == 0, r
    return r.stdout


def prompt(sid):
    return {"session_id": sid, "hook_event_name": "UserPromptSubmit", "prompt": "hi", "permission_mode": "acceptEdits"}


def expand(sid, name="router:front", source="plugin"):
    return {"session_id": sid, "hook_event_name": "UserPromptExpansion", "expansion_type": "slash_command",
            "command_name": name, "command_args": "", "command_source": source, "prompt": "/" + name,
            "permission_mode": "plan"}


def stop(sid, msg="done: pong"):
    return {"session_id": sid, "hook_event_name": "Stop", "stop_hook_active": False, "last_assistant_message": msg}


# no registry yet → nothing, and nothing created
assert run(prompt("front-uuid")) == "" and run(stop("w-uuid")) == ""
assert not DATA.exists()
# other commands, or a non-plugin command of the same name → nothing (only the typed plugin skill registers)
assert run(expand("front-uuid", "router:route")) == "" and run(expand("front-uuid", source="userSettings")) == ""
assert not DATA.exists()
# user-typed /router:front → front from the hook input (session id, permission mode) and its own `claude agents`
# entry (name). No output: the expansion is not blocked, the front skill still runs.
assert run(expand("front-uuid")) == ""
front = json.loads(REG.read_text())["front"]
assert (front["session_id"], front["name"], front["permission_mode"]) == ("front-uuid", "boss", "plan"), front

gone = subprocess.Popen(["true"])
gone.wait()  # reaped: its pid is a process that no longer exists (like a retired worker's)
REG.write_text(json.dumps({
    "front": front,
    "sessions": {
        "api": {"session_id": "w-uuid", "job_id": "aaaa1111", "state": "active", "topic": "API", "pid": os.getpid()},
        "ui": {"job_id": "bbbb2222", "state": "active", "topic": "UI"},
        "db": {"job_id": "cccc3333", "state": "idle", "topic": "DB", "pid": gone.pid},
    },
}))
before = REG.read_bytes()

# UserPromptSubmit: non-front sessions (other, worker) → no output, no write. A worker's message that reads
# "/router:front" arrives in the front as UserPromptSubmit only (never expanded), so it registers nothing either.
assert run(prompt("someone-else")) == ""
assert run({**prompt("w-uuid"), "permission_mode": "bypassPermissions", "prompt": "/router:front"}) == ""
assert REG.read_bytes() == before
# front → its permission mode recorded (the workers' mode), additionalContext JSON with the registry and that mode
out = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]
assert out["hookEventName"] == "UserPromptSubmit"
ctx = out["additionalContext"]
assert "@boss (mode acceptEdits)" in ctx and "- ui [active]" in ctx, ctx
# liveness: pid shown only while the process exists; a recorded pid that is gone reads as exited
assert f"- api [active pid {os.getpid()}]" in ctx and "- db [exited]" in ctx, ctx
after = json.loads(REG.read_text())
assert after["front"]["permission_mode"] == "acceptEdits" and after["front"]["mode_updated"], after["front"]
assert after["sessions"] == json.loads(before)["sessions"]  # only the front's mode is written
before = REG.read_bytes()

# Stop: front and unknown sessions → no output, no write
assert run(stop("front-uuid")) == "" and run(stop("stranger")) == ""
assert run(stop("stranger"), CLAUDE_JOB_DIR="/tmp/jobs/ffff9999") == ""
assert REG.read_bytes() == before
# worker by session id → last_result recorded and state idle (turn finished), no output
assert run(stop("w-uuid", "API done: 3 endpoints")) == ""
api = json.loads(REG.read_text())["sessions"]["api"]
assert api["last_result"] == "API done: 3 endpoints" and api["state"] == "idle", api
# worker not yet mapped → found via $CLAUDE_JOB_DIR job id, session id backfilled
assert run({**stop("ui-uuid", "UI blocked: need token"), "agent_type": "router:topic-worker"},
           CLAUDE_JOB_DIR="/Users/x/.claude/jobs/bbbb2222") == ""
ui = json.loads(REG.read_text())["sessions"]["ui"]
assert ui["session_id"] == "ui-uuid" and ui["last_result"].startswith("UI blocked") and ui["agent_type"], ui

# garbage stdin → still exit 0
r = subprocess.run([str(HOOK)], input="not json", capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == ""

print("PASS test_hooks")
