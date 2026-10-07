#!/usr/bin/env python3
"""router-hook.py checks: front registered only by a user-typed /router:front (UserPromptExpansion), front-only
mode recording and injection, worker-only Stop recording, the approval relay (a worker's PermissionRequest waits for
the decision only a user-typed /router:approve in the front writes), silent exit 0 otherwise.
Usage: python3 plugins/router/tests/test_hooks.py"""

import atexit
import contextlib
import datetime
import json
import os
import pathlib
import re
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
[ "$1" = agents ] && {{ cat "${{STUB_AGENTS:-{AGENTS}}}" 2>/dev/null || echo '{json.dumps(AGENT_LIST)}'; }}
""")
(BIN / "claude").chmod(0o755)


def hook_env(**env):
    e = {k: v for k, v in os.environ.items() if k not in ("ROUTER_REGISTRY", "CLAUDE_JOB_DIR")}
    # the approval wait reads a decision every 0.5 s and `claude agents` every 3 s; tests look 10x and 30x as often
    e.update(CLAUDE_PLUGIN_DATA=str(DATA), PATH=f"{BIN}{os.pathsep}{os.environ['PATH']}",
             ROUTER_POLL_INTERVAL="0.05", ROUTER_AGENTS_CHECK_INTERVAL="0.1")
    return e | env


def put(f, obj):
    """Write JSON whole (temp file + rename): a hook polling F must never read it half-written."""
    tmp = f.with_name(f".{f.name}.tmp")
    tmp.write_text(json.dumps(obj))
    os.replace(tmp, f)


def run(payload, **env):
    r = subprocess.run([str(HOOK)], input=json.dumps(payload), env=hook_env(**env), capture_output=True, text=True,
                       timeout=60)
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
# its background subagent still running (Stop input background_tasks) will wake it again: result recorded, not idle.
# A background shell task alone (e.g. a dev server) does not keep it busy.
for tasks, state in (([{"id": "t1", "type": "subagent", "status": "running"}], "active"),
                     ([{"id": "t2", "type": "shell", "status": "running"}, "junk"], "idle")):
    assert run({**stop("w-uuid", f"API: {state}"), "background_tasks": tasks}) == ""
    api = json.loads(REG.read_text())["sessions"]["api"]
    assert api["state"] == state and api["last_result"] == f"API: {state}", api
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
    put(APPR / "decisions" / f"{rec['nonce']}.json", d)


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
assert out["message"].endswith(" Report this as blocked to the front (not done)."), out  # not "done"/"완료" (7th test)
# ignored: older than the request (planted before it), another request's nonce (replay), unknown behavior; or nothing
# decided (timeout). Each is read once and deleted; no valid decision → no output, the normal prompt stays; pending
# removed. The four hooks wait side by side: each needs its whole wait, long enough to read the decision under load.
old = APPR / "pending/0ld0ld00.json"  # a killed hook's leftover → swept (older than the hook timeout)
old.write_text("{}")
os.utime(old, (time.time() - 700,) * 2)
(APPR / "expired").mkdir()  # an expired subagent request is kept an hour
for f, age in (("0ld0ld01", 700), ("0ld0ld02", 3700)):
    (APPR / f"expired/{f}.json").write_text("{}")
    os.utime(APPR / f"expired/{f}.json", (time.time() - age,) * 2)
waiting = []
for bad in ({"created": 0}, {"nonce": "deadbeef"}, {"behavior": "yes"}, None):
    proc, rec = ask(wait="2")
    assert not old.exists()
    if bad:
        decide(rec, **bad)
    waiting.append((proc, bad))
for proc, bad in waiting:
    assert proc.stdout.read() == "" and proc.wait(timeout=30) == 0, bad
assert not list(APPR.glob("pending/*.json")) and not list(APPR.glob("decisions/*.json"))
assert [f.name for f in APPR.glob("expired/*")] == ["0ld0ld01.json"]  # and a main-thread request leaves no record
(APPR / "expired/0ld0ld01.json").unlink()


# /router:approve (front side): the typed command's UserPromptExpansion hook writes the decision and blocks the prompt
def approve(sid="front-uuid", args="", source="plugin"):
    out = run(expand(sid, "router:approve", source, args))
    return json.loads(out) if out else None


proc, rec = ask()
n = rec["nonce"]
# the front's injected context shows the open request under its worker (id, exact call), but no ready-made approve
# command, and the rule never to write ids in replies (9th live test: the front wrote one, the suggestion offered it)
ctx = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]
assert "- api [WAITING: permission prompt — user types /router:approve (bare: lists ids), or runs:" in ctx, ctx
assert f"\n  approval {n}: @api Bash: echo relay-ok" in ctx and not re.search(r"/router:approve +[0-9a-f]{8}", ctx), ctx
assert "Never write a request id, or /router:approve with an id, in a reply" in ctx and "type /router:approve, " in ctx
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
# the front's model never sees a typed approve (blocked prompt): its context lists the last decisions of 10 minutes
(APPR / "decided").mkdir(exist_ok=True)  # approve made it; a missing decided record must fail an assert below
(APPR / "decided/0ld0ld00.json").write_text(json.dumps({"nonce": "0ld0ld00", "behavior": "allow",
                                                         "created": time.time() - 700, "what": "@api Bash: old"}))
(APPR / "decided/1af1af1a.json").write_text(json.dumps({"nonce": "1af1af1a", "behavior": "allow", "created": "inf"}))
ctx = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]
assert "\n[router] decided by the user's typed /router:approve (last 10 min;" in ctx, ctx
assert f" approved {n} @api Bash: echo relay-ok > /tmp/x⏎rm -rf ~\n- " in ctx, ctx
assert f" denied {rec['nonce']} @api Bash: echo relay-ok" in ctx, ctx
assert "0ld0ld00" not in ctx and "1af1af1a" not in ctx, ctx  # older than 10 minutes, or no real time


# answered in `claude attach` first: Claude Code keeps the hook running, so the hook watches `claude agents`. Once it
# saw its worker on the prompt (marks the request "seen") and no longer does, it ends without output, pending removed.
# Until then the front hides the request, and a typed approve says already answered and writes no decision.
def api_status(f=AGENTS, **kw):
    put(f, [{**a, **kw} if a["name"] == "api" else a for a in AGENT_LIST])


def seen(rec):
    for _ in range(100):  # the hook's first `claude agents` look
        if json.loads((APPR / "pending" / f"{rec['nonce']}.json").read_text()).get("seen"):
            return rec["nonce"]
        time.sleep(0.05)
    raise AssertionError("request never marked seen")


VIEW = BIN / "hook-agents.json"  # the hook's own `claude agents`: told of the answer only after the front's checks
api_status(status="waiting", waitingFor="permission prompt")
api_status(VIEW, status="waiting", waitingFor="permission prompt")
proc, rec = ask(wait="20", STUB_AGENTS=str(VIEW))
n = seen(rec)
assert f"approval {n}:" in approve()["reason"]  # still on its prompt → open
stuck()
api_status(status="busy")  # the user answered in claude attach
out = approve(args=n)
assert out["decision"] == "block" and "already answered (e.g. via claude attach)" in out["reason"], out
assert not out["reason"].startswith("router: approved") and not list(APPR.glob("decisions/*.json")), out
ctx = json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]
assert f"approval {n}" not in ctx, ctx
api_status(VIEW, status="busy")
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


# the worker's subagent (agent_id): a thread of its own. `claude agents` shows the worker busy while it waits (6th live
# test), so its hook reads the subagent's transcript, <main transcript>/subagents/agent-<id>.jsonl: the result of a
# tool_use with this exact tool and input, written after the request, means answered (claude attach).
def entry(t, kind, block):
    ts = datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    return json.dumps({"type": kind, "timestamp": ts, "message": {"content": [block]}}) + "\n"


def use(t, uid, cmd=CMD):
    return entry(t, "assistant", {"type": "tool_use", "id": uid, "name": "Bash",
                                  "input": {"command": cmd, "description": "harmless echo"}})


def result(t, uid):
    return entry(t, "user", {"type": "tool_result", "tool_use_id": uid, "content": "ok"})


SUB = TMP / "main-uuid/subagents/agent-a1b2c3d4e5f6a7b8c.jsonl"
SUB.parent.mkdir(parents=True)
t = time.time()
SUB.write_text(use(t - 9, "toolu_old") + result(t - 8, "toolu_old") + use(t, "toolu_now"))  # same call ran before
proc3, rec3 = ask(wait="20", extra={"agent_id": "a1b2c3d4e5f6a7b8c", "transcript_path": str(TMP / "main-uuid.jsonl")})
assert rec3["transcript"] == str(SUB) and rec3["size"] == SUB.stat().st_size, rec3
seen(rec2)
with SUB.open("a") as f:  # still open: another call's result, an older result of this one, attachments
    f.write(use(t, "toolu_other", "ls") + result(time.time(), "toolu_other") + result(t - 1, "toolu_now")
            + json.dumps({"type": "attachment", "timestamp": "x", "attachment": {"type": "hook_success"}}) + "\n")
time.sleep(0.3)  # several polls: a request taken as superseded or answered would have ended by now
listing = approve()["reason"]
assert proc2.poll() is None and proc3.poll() is None, listing
assert f"approval {rec2['nonce']}" in listing and f"approval {rec3['nonce']}" in listing, listing
assert "seen" not in json.loads((APPR / "pending" / f"{rec3['nonce']}.json").read_text())  # no `claude agents` look
relays(proc2, rec2)
with SUB.open("a") as f:  # answered in claude attach → the hook ends, no output, pending removed
    f.write(result(time.time(), "toolu_now"))
assert answer(proc3) == "" and time.time() - rec3["created"] < 10
# until its hook ends, the front hides it and a typed approve writes nothing; a FIFO transcript is never opened
planted = APPR / "pending" / "0b1c2d3e.json"
planted.write_text(json.dumps(rec3 | {"nonce": "0b1c2d3e"}))
os.mkfifo(TMP / "fifo")
(APPR / "pending" / "0c1d2e3f.json").write_text(
    json.dumps(rec3 | {"nonce": "0c1d2e3f", "transcript": str(TMP / "fifo"), "size": -1}))
out = approve(args="0b1c2d3e")
assert "already answered" in out["reason"] and "approval 0b1c2d3e" not in out["reason"], out
assert "approval 0c1d2e3f" in out["reason"] and not list(APPR.glob("decisions/*.json")), out
for f in APPR.glob("pending/*.json"):
    f.unlink()
# no decision before the router's wait is over: only then does claude attach show a background subagent's prompt (7th
# live test). It stays listed as WAITING on claude attach (no approve line; a typed approve refuses it) until its
# transcript has the result, the same subagent asks again, or an hour passed.
with SUB.open("a") as f:
    f.write(use(time.time(), "toolu_late"))
proc, rec = ask(wait="0.3", extra={"agent_id": "a1b2c3d4e5f6a7b8c", "transcript_path": str(TMP / "main-uuid.jsonl")})
assert answer(proc) == "" and json.loads((APPR / f"expired/{rec['nonce']}.json").read_text())["agent_id"], rec


def late():
    return json.loads(run(prompt("front-uuid")))["hookSpecificOutput"]["additionalContext"]


ctx = late()
assert "- api [WAITING: subagent prompt — claude attach aaaa1111 to answer;" in ctx, ctx
assert ("\n  subagent prompt (router wait over, /router:approve no longer answers it): @api Bash: echo relay-ok > "
        "/tmp/x⏎rm -rf ~") in ctx and f"approval {rec['nonce']}" not in ctx, ctx
out = approve(args=rec["nonce"])["reason"]
assert out.startswith(f"router: not sent. {rec['nonce']} expired: the router no longer relays it and its prompt now "
                      "waits in claude attach aaaa1111") and not list(APPR.glob("decisions/*.json")), out
(APPR / "expired/0e1f2a3b.json").write_text(json.dumps(rec | {"nonce": "0e1f2a3b", "created": rec["created"] + 0.001}))
(APPR / "expired/0f2a3b4c.json").write_text(json.dumps(rec | {  # another subagent's, an hour old
    "nonce": "0f2a3b4c", "created": rec["created"] - 3700, "agent_id": "a0", "transcript": str(TMP / "none")}))
ctx = late()  # the same subagent asked again: only the newer one is listed
assert ctx.count("subagent prompt (router wait over") == 1 and "WAITING: subagent prompt" in ctx, ctx
assert "approval 0e1f2a3b" not in ctx and "0e1f2a3b" in approve(args="0e1f2a3b")["reason"]
r = json.loads(REG.read_text())
r["sessions"]["api"]["pid"] = r["sessions"]["db"]["pid"]  # gone: the worker's process is gone: so is its subagent's prompt
REG.write_text(json.dumps(r))
assert "- api [exited]" in late() and "subagent prompt" not in late()
r["sessions"]["api"]["pid"] = os.getpid()
REG.write_text(json.dumps(r))
with SUB.open("a") as f:  # answered in claude attach → no longer listed
    f.write(result(time.time(), "toolu_late"))
assert "subagent prompt" not in late()
AGENTS.unlink()

# PreToolUse SendMessage in a worker: another live session of the user's (e.g. a stale front name's "Did you mean"
# suggestion) is refused; the front, siblings (by name or id), and names that are no session (its own subagents) pass


def send(sid, to):
    out = run({"session_id": sid, "hook_event_name": "PreToolUse", "tool_name": "SendMessage",
               "tool_input": {"to": to, "message": "[api] done: x"}})
    return json.loads(out)["hookSpecificOutput"] if out else None


def denied(to):
    out = send("w-uuid", to) or {}
    why = out.get("permissionDecisionReason") or ""
    return out.get("permissionDecision") == "deny" and "is another session, not your front" in why


# Claude Code's address forms (`name [ref]` when a name is shared, `@"quoted name"`), spacing and case are normalized;
# an address that is empty once normalized (a bare ref) is refused
for to in ("hexo-21", "@hexo-21", "other-uuid", "hexo-21 [b451e5]", "hexo-21[d15204]", "  @hexo-21  [31FA3A] ",
           '"hexo-21"', '@"hexo-21" [b451e5]', '"hexo-21 [b451e5]"', "HEXO-21", "other-uuid [abcdef]", "[09e9dd]", ""):
    assert denied(to), to
assert send("ui-unknown-sid", "hexo-21") is None  # not a worker (no job dir) → not ours to police
for to in ("boss", "@boss", "front-uuid", "ui", "bbbb2222", "my-subagent", "boss [09e9dd]", '@"boss" [09e9dd]',
           ' "boss" ', "ui [c0ffee]"):
    assert send("w-uuid", to) is None, to
# the front's name on another session (front relaunched or /clear-ed, not re-registered yet; or a stranger took the
# name): the name (with or without a ref) is that session's now. Denied, saying so, and the worker keeps reporting.
AGENTS.write_text(json.dumps([AGENT_LIST[1], {"kind": "interactive", "sessionId": "new-uuid", "name": "Boss", "pid": 4},
                              {"kind": "interactive", "sessionId": "rn-uuid", "name": "release notes", "pid": 5},
                              {"kind": "interactive", "sessionId": "wd-uuid", "name": "weird [ab12]", "pid": 6}]))
for to in ("boss", "boss [09e9dd]", '@"Boss"'):
    out = send("w-uuid", to)
    why = out["permissionDecisionReason"]
    assert out["permissionDecision"] == "deny" and "has not re-registered yet" in why and "/router:front" in why, out
    assert "Stop hook" in why and "keep reporting to the front on later turns" in why and "unreachable" not in why, out
for to in ('@"release notes"', '"release notes" [1a2b3c]', "weird [ab12]", "weird"):
    assert denied(to), to
assert send("w-uuid", "ui") is None
AGENTS.unlink()
# a worker that sends (its report) is running: a WAITING that refresh recorded earlier is cleared
stuck()
assert send("w-uuid", "boss") is None and unstuck()

# wait settings: only low..default counts (0 = the documented approval-wait off switch); anything else is the default,
# so a bad value never spins the loop or waits longer
def waits(wait, poll, check):
    env = hook_env(ROUTER_APPROVAL_WAIT=wait, ROUTER_POLL_INTERVAL=poll, ROUTER_AGENTS_CHECK_INTERVAL=check)
    code = f"import runpy; g = runpy.run_path({str(HOOK)!r}); print(g['WAIT'], g['POLL'], g['CHECK'])"
    return subprocess.run(["python3", "-c", code], env=env, capture_output=True, text=True).stdout.split()


assert waits("nan", "0", "9") == ["300.0", "0.5", "3.0"]
assert waits("0", "abc", "-1") == ["0.0", "0.5", "3.0"]
assert waits("1e9", "0.05", "0.1") == ["300.0", "0.05", "0.1"]

# garbage stdin → still exit 0
r = subprocess.run([str(HOOK)], input="not json", capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == ""

print("PASS test_hooks")
