#!/usr/bin/env python3
"""router-hook.py checks: front registered only by a user-typed /router:front (UserPromptExpansion), front-only
mode recording and injection, worker-only Stop recording, the worker-side approval relay (PermissionRequest),
silent exit 0 otherwise.
Usage: python3 plugins/router/tests/test_hooks.py"""

import atexit
import contextlib
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import time

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


def hook_env(**env):
    e = {k: v for k, v in os.environ.items() if k not in ("ROUTER_REGISTRY", "CLAUDE_JOB_DIR")}
    e.update(CLAUDE_PLUGIN_DATA=str(DATA), PATH=f"{BIN}{os.pathsep}{os.environ['PATH']}", **env)
    return e


def run(payload, **env):
    r = subprocess.run([str(HOOK)], input=json.dumps(payload), env=hook_env(**env), capture_output=True, text=True)
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

# PermissionRequest (approval relay, worker side)
APPR = DATA / "approvals"
CMD = "echo relay-ok > /tmp/x\nrm -rf ~"


def perm(sid, mode="default"):
    return {"session_id": sid, "hook_event_name": "PermissionRequest", "permission_mode": mode, "tool_name": "Bash",
            "tool_input": {"command": CMD, "description": "harmless echo"}, "permission_suggestions": []}


def ask(sid="w-uuid", wait="10", **env):
    """Start the hook; return (process, its pending record) once the pending file appears."""
    proc = subprocess.Popen([str(HOOK)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
                            env=hook_env(ROUTER_APPROVAL_WAIT=wait, **env))
    proc.stdin.write(json.dumps(perm(sid)))
    proc.stdin.close()
    for _ in range(200):
        for f in APPR.glob("pending/*.json"):
            with contextlib.suppress(FileNotFoundError):  # the hook may sweep the planted leftover meanwhile
                rec = json.loads(f.read_text())
                if rec.get("nonce"):  # not the planted leftover below
                    return proc, rec
        time.sleep(0.05)
    raise AssertionError("no pending file")


def decide(rec, behavior="allow", **kw):
    """What the front's /router:approve writes: decisions/<nonce>.json naming the nonce, newer than the request."""
    d = {"nonce": rec["nonce"], "behavior": behavior, "created": time.time(), **kw}
    (APPR / "decisions").mkdir(parents=True, exist_ok=True)
    (APPR / "decisions" / f"{rec['nonce']}.json").write_text(json.dumps(d))


def answer(proc):
    out = proc.stdout.read()
    assert proc.wait(timeout=30) == 0
    assert not list(APPR.glob("pending/*.json")), "pending file left behind"
    return out


# not a worker (front, stranger) or a dontAsk worker (never waits) → no output, nothing written, at once
assert run(perm("front-uuid")) == "" and run(perm("stranger")) == ""
assert run(perm("w-uuid", "dontAsk")) == ""
assert not APPR.exists()
# worker: pending holds the exact tool_input and the worker name; allow → allow only (no updatedInput/Permissions),
# the decision is consumed (one use)
proc, rec = ask()
assert rec["worker"] == "api" and rec["tool_name"] == "Bash" and rec["tool_input"]["command"] == CMD, rec
assert len(rec["nonce"]) == 8 and rec["expires"] > rec["created"], rec
decide(rec)
out = json.loads(answer(proc))["hookSpecificOutput"]
assert out == {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}, out
assert not list(APPR.glob("decisions/*.json"))
# worker found by $CLAUDE_JOB_DIR job id; deny → deny with a message
proc, rec = ask("ui-unknown-sid", CLAUDE_JOB_DIR="/x/jobs/bbbb2222")
assert rec["worker"] == "ui", rec
decide(rec, "deny")
out = json.loads(answer(proc))["hookSpecificOutput"]["decision"]
assert out["behavior"] == "deny" and rec["nonce"] in out["message"], out
# ignored: older than the request (planted before it), another request's nonce (replay), unknown behavior.
# Each is read once and deleted; no valid decision → no output, the normal prompt stays; pending removed.
old = APPR / "pending/0ld0ld00.json"  # a killed hook's leftover → swept (older than the hook timeout)
old.write_text("{}")
os.utime(old, (time.time() - 700,) * 2)
for bad in ({"created": 0}, {"nonce": "deadbeef"}, {"behavior": "yes"}):
    proc, rec = ask(wait="2")
    assert not old.exists()
    decide(rec, **bad)
    assert answer(proc) == "", bad
    assert not list(APPR.glob("decisions/*.json")), bad
# timeout, nothing decided → no output, pending removed
proc, rec = ask(wait="1")
assert answer(proc) == ""

# garbage stdin → still exit 0
r = subprocess.run([str(HOOK)], input="not json", capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == ""

print("PASS test_hooks")
