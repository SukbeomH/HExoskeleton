#!/usr/bin/env python3
"""Codex workers (backend-codex.sh + codex-run.py + codex-turn.py) with a stub `codex` on PATH (a scriptable stdio
`codex app-server`), no real sessions: spawn/resume/list/stop/summarize contract, the front mode → sandbox and
approval policy pinned on every thread/start and thread/resume (danger-full-access only from a bypassPermissions
front; a run Codex reports another sandbox for fails), result recording, follow-ups held while a run is going and sent
after it, backend dispatch in registry.py, Codex's own permission_mode label never written back, and the approval
relay: a request → pending record the front lists → only a typed /router:approve (router-hook.py) answers it, accept
or decline; expiry, a stale decision, never-mode, a sandbox that could write the approvals dir and stop all decline or
drop it; other server requests are refused.
Usage: python3 plugins/router/tests/test_codex.py"""

import atexit
import json
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import registry  # noqa: E402

TMP = pathlib.Path(tempfile.mkdtemp())
REG = TMP / "registry.json"
RUNS = TMP / "codex"
BIN = TMP / "bin"
BIN.mkdir()
CWD = TMP / "repo"
CWD.mkdir()
APPR = TMP / "approvals"
ENV = {**os.environ, "ROUTER_REGISTRY": str(REG), "PATH": f"{BIN}{os.pathsep}{os.environ['PATH']}",
       "ROUTER_POLL_INTERVAL": "0.02"}


@atexit.register
def cleanup():
    for f in RUNS.glob("*/run.json"):  # no supervisor outlives the test, even a failed one
        st = json.loads(f.read_text())
        if st.get("state") == "working" and registry.alive(st.get("pid")):
            os.killpg(st["pid"], signal.SIGKILL)
    shutil.rmtree(TMP, True)


# stub codex: `exec fork` logs its argv and prints a summary. `app-server` speaks stdio JSON-RPC: logs each
# thread/start|resume (params, and whether ROUTER_REGISTRY reached it) and each turn's prompt; reports the requested
# sandbox (workspace-write: /tmp and $TMPDIR excluded, writable roots = BIN/roots if present; any other type on
# BIN/badsandbox) and policy; a turn sends the server requests named in BIN/script (cmd, patch, or a method) and logs
# their answers, waits while BIN/hold exists, fails on BIN/fail, else ends with "pong <n>" (n = codex.log lines). It
# exits at once on BIN/nothread.
(BIN / "codex").write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys, time, uuid
B = pathlib.Path(__file__).parent
a = sys.argv[1:]
def log(f, obj):
    with open(B / f, "a") as fh:
        fh.write(json.dumps(obj) + "\\n")
if a[:2] == ["exec", "fork"]:
    log("codex.log", {"argv": a})
    sys.exit(print("summary of " + a[-2]))
assert a == ["app-server"], a
if (B / "nothread").exists():
    sys.exit(print("boom: not logged in", file=sys.stderr) or 1)
def out(m):
    print(json.dumps(m), flush=True)
def recv():
    line = sys.stdin.readline()
    if not line:
        sys.exit(0)
    return json.loads(line)
def ask(i, method, params):
    out({"id": i, "method": method, "params": params})
    while True:
        m = recv()
        if m.get("id") == i and "method" not in m:
            return log("answers.log", {"method": method, **{k: m[k] for k in ("result", "error") if k in m}})
WW = {"type": "workspaceWrite", "writableRoots": [], "excludeSlashTmp": True, "excludeTmpdirEnvVar": True}
POL = {"read-only": {"type": "readOnly"}, "danger-full-access": {"type": "dangerFullAccess"}, "workspace-write": WW}
while True:
    m = recv()
    meth, p = m.get("method"), m.get("params") or {}
    if meth in ("thread/start", "thread/resume"):
        log("codex.log", {"argv": a, "call": meth, "params": p, "reg": os.environ.get("ROUTER_REGISTRY")})
        tid, cwd = p.get("threadId") or str(uuid.uuid4()), p["cwd"]
        sb = dict(POL[p["sandbox"]])
        if (B / "roots").exists():
            sb["writableRoots"] = [(B / "roots").read_text()]
        if (B / "badsandbox").exists():
            sb = {"type": "dangerFullAccess"}
        out({"id": m["id"], "result": {"thread": {"id": tid}, "sandbox": sb, "approvalPolicy": p["approvalPolicy"],
                                       "cwd": p["cwd"]}})
    elif meth == "turn/start":
        log("prompts.log", p["input"][0]["text"])
        out({"id": m["id"], "result": {"turn": {"id": "t1", "status": "inProgress"}}})
        out({"method": "item/completed", "params": {"item": {"type": "agentMessage", "text": "on it"}}})
        for n, step in enumerate((B / "script").read_text().split() if (B / "script").exists() else []):
            if step == "cmd":
                ask(100 + n, "item/commandExecution/requestApproval", {"threadId": tid, "itemId": "c1",
                    "command": "/bin/zsh -lc 'touch x'", "cwd": cwd, "reason": "MODEL TEXT"})
            elif step == "patch":
                out({"method": "item/started", "params": {"item": {"type": "fileChange", "id": "f1",
                     "changes": [{"path": "/w/a.txt", "kind": {"type": "add"}}]}}})
                ask(100 + n, "item/fileChange/requestApproval", {"threadId": tid, "itemId": "f1", "reason": "x"})
            else:
                ask(100 + n, step, {"threadId": tid})
        end = time.time() + 20
        while (B / "hold").exists() and time.time() < end:
            time.sleep(0.02)
        if (B / "fail").exists():
            out({"method": "turn/completed", "params": {"turn": {"status": "failed", "error": {"message": "boom"}}}})
            continue
        n = len((B / "codex.log").read_text().splitlines())
        out({"method": "item/completed", "params": {"item": {"type": "agentMessage", "text": "pong %d" % n}}})
        out({"method": "turn/completed", "params": {"turn": {"status": "completed"}}})
    elif meth and "id" in m:
        out({"id": m["id"], "result": {}})
""")
(BIN / "claude").write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" | head -n1 >> "$(dirname "$0")/claude.log"
[ "$1" = agents ] && { echo '[]'; exit 0; }
echo 'backgrounded · c1a0de01 · stub'
""")
for f in ("codex", "claude"):
    (BIN / f).chmod(0o755)


def cli(*args, stdin=None, env=None):
    return subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), *args], env={**ENV, **(env or {})},
                          input=stdin, capture_output=True, text=True, timeout=30)


def backend(*args, stdin="Topic: t"):
    return subprocess.run(["bash", str(ROOT / "scripts/backend-codex.sh"), *args], input=stdin, env=ENV,
                          capture_output=True, text=True, timeout=30)


def reg():
    return json.loads(REG.read_text())


def calls():
    return [json.loads(x) for x in (BIN / "codex.log").read_text().splitlines()] if (BIN / "codex.log").exists() else []


def prompts():
    return [json.loads(x) for x in (BIN / "prompts.log").read_text().splitlines()]


def call_after(n):
    """The first codex call after the first N (a resume returns before its run reaches codex: the thread id is known)."""
    until(lambda: len(calls()) > n, f"codex call {n + 1}")
    return calls()[n]


def pend():
    return sorted(APPR.glob("pending/*.json"))


def answers():
    return [json.loads(x) for x in (BIN / "answers.log").read_text().splitlines()] if (BIN / "answers.log").exists() \
        else []


def approve(args):
    """The front's user types /router:approve ARGS: router-hook.py's UserPromptExpansion, as Claude Code runs it."""
    r = subprocess.run([sys.executable, str(ROOT / "hooks/router-hook.py")], env=ENV, capture_output=True, text=True,
                       input=json.dumps({"session_id": "front-uuid", "hook_event_name": "UserPromptExpansion",
                                         "command_source": "plugin", "command_name": "router:approve",
                                         "command_args": args}))
    return json.loads(r.stdout)["reason"]


def until(cond, what, timeout=15):
    end = time.time() + timeout
    while not cond():
        assert time.time() < end, f"timed out: {what}"
        time.sleep(0.02)


def worker(name):
    return reg()["sessions"][name]


def idle(name, job=None):
    until(lambda: worker(name).get("state") == "idle" and (job is None or worker(name).get("job_id") != job),
          f"{name} idle")
    return worker(name)


registry.set_front(REG, "front-uuid", "boss", None)

# backend-codex.sh: fixed argument lists; bad mode, model, thread/job id or arity → exit 2, codex never reached
for bad in (["spawn", "w", str(CWD), "", "yolo"], ["spawn", "w", str(CWD), "--dangerously-bypass-approvals-and-sandbox",
            "default"], ["spawn", "w", str(CWD), "", "default", "--json"], ["spawn", "w", str(CWD), ""],
            ["resume", "--last", "w", str(CWD), "default", ""], ["resume", "0199-a", "w", str(CWD), "bypass", ""],
            ["resume", "0199-a", "w", str(CWD), "default"], ["stop", "../x"], ["summarize", "-x"], ["frob"]):
    r = backend(*bad)
    assert r.returncode == 2 and r.stdout == "", (bad, r)
assert calls() == []
r = subprocess.run(["bash", str(ROOT / "scripts/backend-codex.sh"), "list"], env={**ENV, "ROUTER_REGISTRY": ""},
                   capture_output=True, text=True)
assert r.returncode != 0 and "ROUTER_REGISTRY" in r.stderr, r  # runs live next to the registry: never a guess
assert backend("list").stdout.strip() == "[]"
# the backend is a choice on spawn only; nothing else names one
assert cli("spawn", "x", "--backend", "evil", "--request", "x").returncode == 2
assert cli("upsert", "x", "--backend", "codex").returncode == 2 and "x" not in reg()["sessions"]

# spawn: one command reserves the name, composes the Codex prompt, starts the supervised run, records the job id;
# stdout is only the job id. The run's last message becomes last_result and the worker idle (the Stop hook's job).
r = cli("spawn", "cx", "--backend", "codex", "--cwd", str(CWD), "--topic", "T", "--model", "gpt-mini",
        "--request", "reply pong")
assert r.returncode == 0 and re.fullmatch(r"[0-9a-f]{8}\n", r.stdout), r
job = r.stdout.strip()
c = calls()[-1]
assert c["argv"] == ["app-server"] and c["call"] == "thread/start", c
assert c["params"] == {"cwd": str(CWD), "sandbox": "workspace-write", "approvalPolicy": "on-request",
                       "model": "gpt-mini"}, c
assert c["reg"] is None  # the registry path is not handed to the worker's environment
cx = idle("cx")
thread = cx["session_id"]
assert cx["backend"] == "codex" and cx["job_id"] == job and cx["last_result"] == "pong 1" and cx["pid"] is None, cx
assert re.fullmatch(r"[0-9a-f-]{36}", thread), cx
# Codex worker prompt: no SendMessage (it cannot), its last message is the report, worker rules, request last
p = prompts()[-1]
assert p.startswith("Router front: @boss — you cannot message it: your last message is your report"), p
assert registry.CODEX_WORKER in p and registry.ROUTED in p and "SendMessage" not in p, p
assert p.endswith("\n\nRequest from the user:\nreply pong"), p
# list: one claude-agents-shaped entry per run; a finished run has no pid and leaves the worker idle on refresh
e = json.loads(backend("list").stdout)
assert e == [{"id": job, "kind": "codex", "sessionId": thread, "name": "cx", "startedAt": e[0]["startedAt"],
              "state": "done", "status": "idle"}], e
r = cli("refresh")
assert r.returncode == 0 and "- cx [idle codex] topic: T" in r.stdout and "last: pong 1" in r.stdout, r

# the front's recorded mode → sandbox + approval policy, on every spawn: danger-full-access only when the front itself
# is bypass; modes that ask before acting → on-request (relayed), the others never ask
SANDBOX = {"default": ("workspace-write", "on-request"), "acceptEdits": ("workspace-write", "on-request"),
           "auto": ("workspace-write", "on-request"), "dontAsk": ("workspace-write", "never"),
           "plan": ("read-only", "never"), "bypassPermissions": ("danger-full-access", "never")}
for mode, (sb, ap) in SANDBOX.items():
    registry.record_mode(REG, "front-uuid", mode)
    assert cli("spawn", f"m-{mode.lower()}", "--backend", "codex", "--cwd", str(CWD), "--request", "x").returncode == 0
    c = calls()[-1]["params"]
    assert (c["sandbox"], c["approvalPolicy"]) == (sb, ap), (mode, c)
for mode in SANDBOX:
    idle(f"m-{mode.lower()}")
# The front mode is what the front's hook last recorded (Codex labels a sandboxed exec run bypassPermissions): no
# worker carries a mode; a Codex thread id cannot record one either.
registry.record_mode(REG, "front-uuid", "default")
registry.record_mode(REG, thread, "bypassPermissions")
assert reg()["front"]["permission_mode"] == "default", reg()["front"]
assert not any("permission_mode" in s for s in reg()["sessions"].values())

# resume an idle worker: thread/resume on its thread, sandbox and policy pinned again from the current front mode,
# model kept
registry.record_mode(REG, "front-uuid", "plan")
n = len(calls())
r = cli("resume", "cx", "--request", "again")
assert r.returncode == 0 and re.fullmatch(r"[0-9a-f]{8}\n", r.stdout) and r.stdout.strip() != job, r
job = r.stdout.strip()
c = call_after(n)
assert c["call"] == "thread/resume" and c["params"] == {
    "threadId": thread, "excludeTurns": True, "cwd": str(CWD), "sandbox": "read-only", "approvalPolicy": "never",
    "model": "gpt-mini"}, c
cx = idle("cx")
assert prompts()[-1].endswith("Request from the user:\nagain")
assert cx["session_id"] == thread and cx["last_result"] == f"pong {len(calls())}", cx
registry.record_mode(REG, "front-uuid", "default")

# busy: a forward while a run is going is held (no second run on the thread), then sent as the next run when it ends
(BIN / "hold").touch()
n = len(calls())
r = cli("resume", "cx", "--request", "slow")
assert r.returncode == 0, r
busy = r.stdout.strip()
call_after(n)
n = len(calls())
r = cli("refresh")
assert re.search(r"- cx \[active codex pid \d+\]", r.stdout), r.stdout
for i, text in enumerate(("follow-up 1", "follow-up 2"), 1):
    r = cli("resume", "cx", "--request", text)
    assert r.returncode == 0 and r.stdout.startswith("held: 'cx' is running"), r
    assert worker("cx")["held"][-1] == text and f"held {i}]" in cli("list").stdout
assert len(calls()) == n  # nothing started
(BIN / "hold").unlink()
cx = idle("cx", busy)
assert len(calls()) == n + 1 and calls()[-1]["call"] == "thread/resume" and "held" not in cx, (calls(), cx)
assert prompts()[-1].endswith("Request from the user:\nfollow-up 1\n\nfollow-up 2"), prompts()[-1]
assert cx["last_result"] == f"pong {n + 1}" and cx["job_id"] != busy, cx
# both chained runs stay visible to the front: the held run's result does not hide the one before it (7th live test)
assert [(r["job"], r["text"], r.get("chained")) for r in cx["results"][-2:]] == [
    (busy, f"pong {n}", True), (cx["job_id"], f"pong {n + 1}", None)], cx["results"]
out = cli("list").stdout
assert f"last: pong {n + 1}\n  earlier result (its held follow-ups ran right after): pong {n}\n" in out, out

# stop: SIGTERM to the run's process group (supervisor, codex-turn.py, app-server); refresh then shows it exited;
# resumable
(BIN / "hold").touch()
n = len(calls())
job = cli("resume", "cx", "--request", "long").stdout.strip()
call_after(n)  # the app-server is running, in the supervisor's process group
pid = json.loads((RUNS / job / "run.json").read_text())["pid"]
assert cli("stop", "cx").returncode == 0
until(lambda: json.loads((RUNS / job / "run.json").read_text())["state"] == "stopped", "run stopped")


def gone():
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return True
    return False


until(gone, "process group gone")
(BIN / "hold").unlink()
assert "- cx [exited/stopped codex]" in cli("refresh").stdout
r = cli("resume", "cx", "--request", "back")
assert r.returncode == 0 and idle("cx")["last_result"] == f"pong {len(calls())}", r
assert "earlier result" not in cli("list").stdout  # a run the front sent itself ends the chain's listing

# a failed run: its error becomes last_result (not a stale result), the worker stays resumable (idle/failed)
(BIN / "fail").touch()
job = cli("resume", "cx", "--request", "x").stdout.strip()
until(lambda: worker("cx").get("last_result") == "codex run failed (exit 1): boom", "failure recorded")
(BIN / "fail").unlink()
assert "- cx [idle/failed codex]" in cli("refresh").stdout
# Codex reports another sandbox than the one asked for (e.g. a config profile): the run fails before any turn
(BIN / "badsandbox").touch()
n = len(prompts())
job = cli("resume", "cx", "--request", "x").stdout.strip()
until(lambda: worker("cx").get("last_result", "").startswith("codex run failed (exit 1): codex applied sandbox"),
      "sandbox mismatch")
(BIN / "badsandbox").unlink()
assert len(prompts()) == n and "'dangerFullAccess'" in worker("cx")["last_result"], worker("cx")
# a spawn whose app-server never started a thread fails at once: exit 1, name exited without ids (reusable)
(BIN / "nothread").touch()
r = cli("spawn", "cx-bad", "--backend", "codex", "--cwd", str(CWD), "--request", "x")
assert r.returncode == 1 and "boom: not logged in" in r.stderr and "job_id" not in worker("cx-bad"), r
assert worker("cx-bad")["state"] == "exited"
(BIN / "nothread").unlink()

# summarize: an ephemeral read-only fork of the recorded thread (never the command line's), model kept
r = cli("summarize", "cx")
assert r.returncode == 0 and r.stdout == f"summary of {thread}\n", r
argv = calls()[-1]["argv"]
assert argv[:6] == ["exec", "fork", "--ephemeral", "--skip-git-repo-check", "-c", 'sandbox_mode="read-only"']
assert argv[6:9] == ["-m", "gpt-mini", thread], argv

# approval relay (front mode default → on-request): the run's command approval → pending/<nonce>.json, router-hook.py's
# record shape (worker, job, exact command and cwd, never the model's reason; no session_id: never superseded), listed
# in the front as WAITING without a claude attach hint; a stale decision is ignored; the typed /router:approve answers.
# The same run's file change next: relayed as apply_patch with its changes; deny → decline.
assert worker("cx")["state"] == "idle" and registry.front_mode(reg()) == "default"
(BIN / "script").write_text("cmd patch")
job = cli("resume", "cx", "--request", "touch x").stdout.strip()
until(pend, "request pending")
r = json.loads(pend()[0].read_text())
assert {k: r[k] for k in ("worker", "backend", "job_id", "thread", "tool_name", "tool_input")} == {
    "worker": "cx", "backend": "codex", "job_id": job, "thread": thread, "tool_name": "Bash",
    "tool_input": {"command": "/bin/zsh -lc 'touch x'", "cwd": str(CWD)}} and "session_id" not in r, r
out = cli("list").stdout
assert "- cx [WAITING: permission prompt — user types /router:approve below; codex" in out, out
assert f"approval {r['nonce']}: @cx Bash: /bin/zsh -lc 'touch x' [input: " in out and "claude attach" not in out, out
registry.save(APPR / "decisions" / f"{r['nonce']}.json",
              {"nonce": r["nonce"], "behavior": "allow", "created": r["created"] - 1})  # older than the request
until(lambda: not (APPR / "decisions" / f"{r['nonce']}.json").exists(), "stale decision consumed")
assert answers() == [] and pend(), answers()
assert approve(r["nonce"]).startswith(f"router: approved {r['nonce']}: @cx Bash: /bin/zsh -lc 'touch x'")
until(lambda: pend() and pend()[0].stem != r["nonce"], "patch request pending")
r = json.loads(pend()[0].read_text())
assert (r["tool_name"], r["tool_input"]) == ("apply_patch", {"changes": [{"path": "/w/a.txt", "kind": {"type": "add"}}]})
assert approve(f"{r['nonce']} deny").startswith(f"router: denied {r['nonce']}")
assert idle("cx")["last_result"].startswith("pong") and not pend()
assert answers() == [{"method": "item/commandExecution/requestApproval", "result": {"decision": "accept"}},
                     {"method": "item/fileChange/requestApproval", "result": {"decision": "decline"}}], answers()
# no answer in time → decline (no attach fallback), the request is gone
(BIN / "script").write_text("cmd")
cli("resume", "cx", "--request", "x", env={"ROUTER_APPROVAL_WAIT": "0.3"})
idle("cx")
assert answers()[-1]["result"] == {"decision": "decline"} and not pend(), answers()
# declined at once, nothing pending: a sandbox that could write the approvals dir (a writable root over it), and a
# never-asking mode's run (dontAsk) should Codex ask anyway. Other server requests are refused (no turn waits on them).
(BIN / "script").write_text("cmd item/permissions/requestApproval mcpServer/elicitation/request item/tool/requestUserInput")
(BIN / "roots").write_text(str(TMP))
n = len(answers())
cli("resume", "cx", "--request", "x")
until(lambda: len(answers()) == n + 4, "declined at once")
idle("cx")
(BIN / "roots").unlink()
(BIN / "script").write_text("cmd")
registry.record_mode(REG, "front-uuid", "dontAsk")
cli("resume", "cx", "--request", "x")
until(lambda: len(answers()) == n + 5, "never-mode declined")
idle("cx")
registry.record_mode(REG, "front-uuid", "default")
a = answers()[n:]
assert a[0] == a[4] == {"method": "item/commandExecution/requestApproval", "result": {"decision": "decline"}}, a
assert a[1]["result"] == {"permissions": {}} and a[2]["result"] == {"action": "decline", "content": None}, a
assert a[3]["error"]["message"] == "router: item/tool/requestUserInput not supported" and not pend(), a
# stop while a request is open: the pending file goes with the run
(BIN / "script").write_text("cmd")
job = cli("resume", "cx", "--request", "x").stdout.strip()
until(pend, "request pending")
assert cli("stop", "cx").returncode == 0
until(lambda: not pend(), "pending removed on stop")
until(lambda: json.loads((RUNS / job / "run.json").read_text())["state"] == "stopped", "stopped")
(BIN / "script").unlink()

# dispatch by backend: a Claude worker next to Codex workers still goes to claude, refresh reads both lists
assert cli("spawn", "cl", "--cwd", str(CWD), "--request", "x").returncode == 0
assert (BIN / "claude.log").read_text().splitlines()[-1].startswith("--bg --name cl --agent router:topic-worker")
assert "backend" not in worker("cl")
r = cli("refresh", "--json")
assert r.returncode == 0 and json.loads(r.stdout)["sessions"]["cx"]["state"] == "exited", r  # stopped above
assert cli("stop", "cl").returncode == 0 and (BIN / "claude.log").read_text().splitlines()[-1] == "stop c1a0de01"

# no supervisor left running
assert not [f for f in RUNS.glob("*/run.json") if json.loads(f.read_text())["state"] == "working"]
print("PASS test_codex")
