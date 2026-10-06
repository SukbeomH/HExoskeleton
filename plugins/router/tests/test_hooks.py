#!/usr/bin/env python3
"""router-hook.py checks: front registered only by a user-typed /router:front (UserPromptExpansion), front-only
mode recording and injection, worker-only Stop recording, the approval relay (a worker's PermissionRequest waits for
the decision only a user-typed /router:approve in the front writes), silent exit 0 otherwise.
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
BIN = TMP / "bin"  # stub `claude`: `claude agents --json --all` names the sessions (front name lookup, SendMessage guard)
BIN.mkdir()
AGENTS = BIN / "agents.json"  # when present, the stub prints it instead (worker status for the approval relay)
AGENT_LIST = [{"kind": "interactive", "sessionId": "front-uuid", "name": "boss", "pid": 1},
              {"kind": "background", "id": "aaaa1111", "sessionId": "w-uuid", "name": "api", "pid": 2},
              {"kind": "interactive", "sessionId": "other-uuid", "name": "hexo-21", "pid": 3}]
(BIN / "claude").write_text(f"""#!/usr/bin/env bash
[ "$1" = agents ] && {{ cat "{AGENTS}" 2>/dev/null || echo '{json.dumps(AGENT_LIST)}'; }}
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


def expand(sid, name="router:front", source="plugin", args=""):
    return {"session_id": sid, "hook_event_name": "UserPromptExpansion", "expansion_type": "slash_command",
            "command_name": name, "command_args": args, "command_source": source, "prompt": f"/{name} {args}",
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


def ask(sid="w-uuid", wait="10", extra=(), **env):
    """Start the hook (EXTRA: more input fields); return (process, its pending record) once its pending file appears."""
    before = set(APPR.glob("pending/*.json"))
    proc = subprocess.Popen([str(HOOK)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
                            env=hook_env(ROUTER_APPROVAL_WAIT=wait, **env))
    proc.stdin.write(json.dumps(perm(sid) | dict(extra)))
    proc.stdin.close()
    for _ in range(200):
        for f in set(APPR.glob("pending/*.json")) - before:
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


def stuck():
    """What a refresh records while api's prompt holds its turn."""
    r = json.loads(REG.read_text())
    r["sessions"]["api"].update(state="waiting", waiting_for="permission prompt", agent_state="blocked")
    REG.write_text(json.dumps(r))


def unstuck():
    """Answered or moving on → no stale WAITING (or idle/blocked) left behind."""
    api = json.loads(REG.read_text())["sessions"]["api"]
    return api["state"] == "active" and not api.get("waiting_for") and "agent_state" not in api


# not a worker (front, stranger) or a dontAsk worker (never waits) → no output, nothing written, at once
assert run(perm("front-uuid")) == "" and run(perm("stranger")) == ""
assert run(perm("w-uuid", "dontAsk")) == ""
assert not APPR.exists()
# worker: pending holds the exact tool_input and the worker name; allow → allow only (no updatedInput/Permissions),
# the decision is consumed (one use)
proc, rec = ask()
assert rec["worker"] == "api" and rec["tool_name"] == "Bash" and rec["tool_input"]["command"] == CMD, rec
assert len(rec["nonce"]) == 8 and rec["expires"] > rec["created"], rec
stuck()
decide(rec)
out = json.loads(answer(proc))["hookSpecificOutput"]
assert out == {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}, out
assert not list(APPR.glob("decisions/*.json")) and unstuck()
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


# /router:approve (front side): the typed command's UserPromptExpansion hook writes the decision and blocks the prompt
def approve(sid="front-uuid", args="", source="plugin"):
    out = run(expand(sid, "router:approve", source, args))
    return json.loads(out) if out else None


proc, rec = ask()
n = rec["nonce"]
# the front's injected context shows the open request under its worker
ctx = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]
assert "- api [WAITING: permission prompt" in ctx and f"  approve: /router:approve {n}   deny:" in ctx, ctx
# not the front (a worker, a stranger) → refused, blocked (no model turn), no decision
for sid in ("w-uuid", "stranger"):
    out = approve(sid, n)
    assert out["decision"] == "block" and "not sent" in out["reason"] and "front" in out["reason"], out
# a same-named command from another source (user/project skill) → ignored entirely
assert approve(args=n, source="projectSettings") is None
# bare → lists the open request: id, worker, tool, exact command (newline visible), approve/deny line
out = approve()
assert out["decision"] == "block" and f"approval {n}: @api Bash: echo relay-ok > /tmp/x⏎rm -rf ~" in out["reason"], out
assert f"approve: /router:approve {n}   deny: /router:approve {n} deny" in out["reason"], out
# unknown id, bad syntax, path tricks → not sent
for bad in ("ffffffff", f"{n} yes", f"{n} deny x", "../../x", "F" + n[1:]):  # n.upper() is n when n is all digits
    out = approve(args=bad)
    assert out["decision"] == "block" and "not sent" in out["reason"], (bad, out)
assert not list(APPR.glob("decisions/*.json")) and proc.poll() is None
# none of the above reached the worker; the front's typed approve does: the block says exactly what was approved
out = approve(args=n)
assert out["decision"] == "block" and out["reason"].startswith(f"router: approved {n}: @api Bash: echo relay-ok"), out
assert json.loads(answer(proc))["hookSpecificOutput"]["decision"] == {"behavior": "allow"}
# deny, end to end
proc, rec = ask()
assert approve(args=f"{rec['nonce']} deny")["reason"].startswith(f"router: denied {rec['nonce']}")
assert json.loads(answer(proc))["hookSpecificOutput"]["decision"]["behavior"] == "deny"
# answered or expired → no longer open
assert "not sent" in approve(args=rec["nonce"])["reason"]
assert approve()["reason"].endswith("(none)")


# answered in `claude attach` first: Claude Code keeps the hook running, so the hook watches `claude agents`. Once it
# saw its worker on the prompt (marks the request "seen") and no longer does, it ends without output, pending removed.
# Until then the front hides the request, and a typed approve says already answered and writes no decision.
def api_status(**kw):
    AGENTS.write_text(json.dumps([{**a, **kw} if a["name"] == "api" else a for a in AGENT_LIST]))


def seen(rec):
    for _ in range(100):  # the hook's first `claude agents` look
        if json.loads((APPR / "pending" / f"{rec['nonce']}.json").read_text()).get("seen"):
            return rec["nonce"]
        time.sleep(0.05)
    raise AssertionError("request never marked seen")


api_status(status="waiting", waitingFor="permission prompt")
proc, rec = ask(wait="20")
n = seen(rec)
assert f"approval {n}:" in approve()["reason"]  # still on its prompt → open
stuck()
api_status(status="busy")  # the user answered in claude attach
out = approve(args=n)
assert out["decision"] == "block" and "already answered (e.g. via claude attach)" in out["reason"], out
assert not out["reason"].startswith("router: approved") and not list(APPR.glob("decisions/*.json")), out
ctx = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]
assert f"approval {n}" not in ctx, ctx
assert answer(proc) == "" and time.time() - rec["created"] < 10  # ended on the signal, long before its 20 s wait
assert unstuck()
# the normal path with the worker on its prompt (seen) still relays
api_status(status="waiting", waitingFor="permission prompt")
proc, rec = ask()
assert approve(args=seen(rec))["reason"].startswith(f"router: approved {rec['nonce']}")
assert json.loads(answer(proc))["hookSpecificOutput"]["decision"] == {"behavior": "allow"}


# parallel calls: the first prompt answered in claude attach, the same thread's next prompt within one CHECK (the worker
# never leaves the prompt). The newer request supersedes the older: its hook ends at once (no output, pending removed),
# the front hides it, a typed approve refuses it and writes no decision. Another thread's (a subagent's) request stays.
def relays(proc, rec):
    assert approve(args=rec["nonce"])["reason"].startswith(f"router: approved {rec['nonce']}")
    assert json.loads(proc.stdout.read())["hookSpecificOutput"]["decision"] == {"behavior": "allow"}
    assert proc.wait(timeout=30) == 0


proc, rec = ask(wait="20")
old = seen(rec)
proc2, rec2 = ask(wait="20")
assert proc.stdout.read() == "" and proc.wait(timeout=30) == 0 and time.time() - rec2["created"] < 5
assert not (APPR / "pending" / f"{old}.json").exists()
gone = APPR / "pending" / "0a1b2c3d.json"  # a superseded request whose hook has not ended yet
gone.write_text(json.dumps(rec2 | {"nonce": "0a1b2c3d", "created": rec2["created"] - 1, "seen": True}))
out = approve(args="0a1b2c3d")
assert "superseded" in out["reason"] and "nothing approved" in out["reason"], out
assert not list(APPR.glob("decisions/*.json")) and "0a1b2c3d" not in approve()["reason"]
gone.unlink()
proc3, rec3 = ask(wait="20", extra={"agent_id": "a1b2c3d4e5f6a7b8c"})  # the worker's subagent: a thread of its own
seen(rec2), seen(rec3)
time.sleep(1.5)
listing = approve()["reason"]
assert proc2.poll() is None and f"approval {rec2['nonce']}" in listing and f"approval {rec3['nonce']}" in listing
relays(proc2, rec2)
relays(proc3, rec3)
assert not list(APPR.glob("pending/*.json"))
AGENTS.unlink()

# PreToolUse SendMessage in a worker: another live session of the user's (e.g. a stale front name's "Did you mean"
# suggestion) is refused; the front, siblings (by name or id), and names that are no session (its own subagents) pass


def send(sid, to):
    out = run({"session_id": sid, "hook_event_name": "PreToolUse", "tool_name": "SendMessage",
               "tool_input": {"to": to, "message": "[api] done: x"}})
    return json.loads(out)["hookSpecificOutput"] if out else None


def denied(to):
    out = send("w-uuid", to) or {}
    return out.get("permissionDecision") == "deny" and "another session" in out["permissionDecisionReason"]


# Claude Code's address forms (`name [ref]` when a name is shared, `@"quoted name"`), spacing and case are normalized;
# an address that is empty once normalized (a bare ref) is refused
for to in ("hexo-21", "@hexo-21", "other-uuid", "hexo-21 [b451e5]", "hexo-21[d15204]", "  @hexo-21  [31FA3A] ",
           '"hexo-21"', '@"hexo-21" [b451e5]', '"hexo-21 [b451e5]"', "HEXO-21", "other-uuid [abcdef]", "[09e9dd]", ""):
    assert denied(to), to
assert send("ui-unknown-sid", "hexo-21") is None  # not a worker (no job dir) → not ours to police
for to in ("boss", "@boss", "front-uuid", "ui", "bbbb2222", "my-subagent", "boss [09e9dd]", '@"boss" [09e9dd]',
           ' "boss" ', "ui [c0ffee]"):
    assert send("w-uuid", to) is None, to
# the front is gone and an unrelated session took its name: the name (with or without a ref) is that session's now
AGENTS.write_text(json.dumps([AGENT_LIST[1], {"kind": "interactive", "sessionId": "new-uuid", "name": "Boss", "pid": 4},
                              {"kind": "interactive", "sessionId": "rn-uuid", "name": "release notes", "pid": 5},
                              {"kind": "interactive", "sessionId": "wd-uuid", "name": "weird [ab12]", "pid": 6}]))
for to in ("boss", "boss [09e9dd]", '@"release notes"', '"release notes" [1a2b3c]', "weird [ab12]", "weird"):
    assert denied(to), to
assert send("w-uuid", "ui") is None
AGENTS.unlink()
# a worker that sends (its report) is running: a WAITING that refresh recorded earlier is cleared
stuck()
assert send("w-uuid", "boss") is None and unstuck()

# garbage stdin → still exit 0
r = subprocess.run([str(HOOK)], input="not json", capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == ""

print("PASS test_hooks")
