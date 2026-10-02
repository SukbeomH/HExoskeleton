#!/usr/bin/env python3
"""router-hook.py checks: front-only injection, worker-only Stop recording, silent exit 0 otherwise.
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


def run(payload, **env):
    e = {k: v for k, v in os.environ.items() if k not in ("ROUTER_REGISTRY", "CLAUDE_JOB_DIR")}
    e.update(CLAUDE_PLUGIN_DATA=str(DATA), **env)
    r = subprocess.run([str(HOOK)], input=json.dumps(payload), env=e, capture_output=True, text=True)
    assert r.returncode == 0, r
    return r.stdout


def prompt(sid):
    return {"session_id": sid, "hook_event_name": "UserPromptSubmit", "prompt": "hi", "permission_mode": "acceptEdits"}


def stop(sid, msg="done: pong"):
    return {"session_id": sid, "hook_event_name": "Stop", "stop_hook_active": False, "last_assistant_message": msg}


# no registry yet → nothing, and nothing created
assert run(prompt("front-uuid")) == "" and run(stop("w-uuid")) == ""
assert not DATA.exists()

DATA.mkdir()
REG.write_text(json.dumps({
    "front": {"session_id": "front-uuid", "name": "boss"},
    "sessions": {
        "api": {"session_id": "w-uuid", "job_id": "aaaa1111", "state": "active", "topic": "API"},
        "ui": {"job_id": "bbbb2222", "state": "active", "topic": "UI"},
    },
}))
before = REG.read_bytes()

# UserPromptSubmit: non-front sessions (other, worker) → no output
assert run(prompt("someone-else")) == ""
assert run(prompt("w-uuid")) == ""
# front → additionalContext JSON with the registry and the front's permission mode
out = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]
assert out["hookEventName"] == "UserPromptSubmit"
ctx = out["additionalContext"]
assert "@boss" in ctx and "- api [active]" in ctx and "- ui [active]" in ctx and "acceptEdits" in ctx, ctx
assert REG.read_bytes() == before  # injection never writes

# Stop: front and unknown sessions → no output, no write
assert run(stop("front-uuid")) == "" and run(stop("stranger")) == ""
assert run(stop("stranger"), CLAUDE_JOB_DIR="/tmp/jobs/ffff9999") == ""
assert REG.read_bytes() == before
# worker by session id → last_result recorded, no output
assert run(stop("w-uuid", "API done: 3 endpoints")) == ""
assert json.loads(REG.read_text())["sessions"]["api"]["last_result"] == "API done: 3 endpoints"
# worker not yet mapped → found via $CLAUDE_JOB_DIR job id, session id backfilled
assert run({**stop("ui-uuid", "UI blocked: need token"), "agent_type": "router:topic-worker"},
           CLAUDE_JOB_DIR="/Users/x/.claude/jobs/bbbb2222") == ""
ui = json.loads(REG.read_text())["sessions"]["ui"]
assert ui["session_id"] == "ui-uuid" and ui["last_result"].startswith("UI blocked") and ui["agent_type"], ui

# garbage stdin → still exit 0
r = subprocess.run([str(HOOK)], input="not json", capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == ""

print("PASS test_hooks")
