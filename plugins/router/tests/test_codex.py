#!/usr/bin/env python3
"""Codex workers (backend-codex.sh + codex-run.py) with a stub `codex` on PATH, no real sessions: spawn/resume/list/
stop/summarize contract, the front mode → sandbox map on every spawn and resume (danger-full-access only from a
bypassPermissions front), result recording, follow-ups held while a run is going and sent after it, backend dispatch
in registry.py, and Codex's own permission_mode label never written back.
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
ENV = {**os.environ, "ROUTER_REGISTRY": str(REG), "PATH": f"{BIN}{os.pathsep}{os.environ['PATH']}"}


@atexit.register
def cleanup():
    for f in RUNS.glob("*/run.json"):  # no supervisor outlives the test, even a failed one
        st = json.loads(f.read_text())
        if st.get("state") == "working" and registry.alive(st.get("pid")):
            os.killpg(st["pid"], signal.SIGKILL)
    shutil.rmtree(TMP, True)


# stub codex: logs argv (+ whether ROUTER_REGISTRY reached it) and the prompt; `exec fork` prints a summary; otherwise
# JSONL like `codex exec --json` (thread.started first), waits while BIN/hold exists, fails on BIN/fail (turn.failed),
# exits without a thread on BIN/nothread, else writes "pong <n>" to the -o file.
(BIN / "codex").write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys, time, uuid
B = pathlib.Path(__file__).parent
a = sys.argv[1:]
with open(B / "codex.log", "a") as f:
    f.write(json.dumps({"argv": a, "reg": os.environ.get("ROUTER_REGISTRY")}) + "\\n")
if a[:2] == ["exec", "fork"]:
    print("summary of " + a[-2])
    sys.exit(0)
with open(B / "prompts.log", "a") as f:
    f.write(json.dumps(sys.stdin.read()) + "\\n")
if (B / "nothread").exists():
    sys.exit(print("boom: not logged in", file=sys.stderr) or 1)
def emit(ev):
    print(json.dumps(ev), flush=True)
emit({"type": "thread.started", "thread_id": a[-2] if a[1] == "resume" else str(uuid.uuid4())})
emit({"type": "turn.started", "permission_mode": "bypassPermissions"})  # Codex's own label for sandboxed exec
end = time.time() + 20
while (B / "hold").exists() and time.time() < end:
    time.sleep(0.02)
if (B / "fail").exists():
    emit({"type": "turn.failed", "error": {"message": "boom"}})
    sys.exit(1)
pathlib.Path(a[a.index("-o") + 1]).write_text("pong %d" % len((B / "codex.log").read_text().splitlines()))
emit({"type": "turn.completed"})
""")
(BIN / "claude").write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" | head -n1 >> "$(dirname "$0")/claude.log"
[ "$1" = agents ] && { echo '[]'; exit 0; }
echo 'backgrounded · c1a0de01 · stub'
""")
for f in ("codex", "claude"):
    (BIN / f).chmod(0o755)


def cli(*args, stdin=None):
    return subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), *args], env=ENV, input=stdin,
                          capture_output=True, text=True, timeout=30)


def backend(*args, stdin="Topic: t"):
    return subprocess.run(["bash", str(ROOT / "scripts/backend-codex.sh"), *args], input=stdin, env=ENV,
                          capture_output=True, text=True, timeout=30)


def reg():
    return json.loads(REG.read_text())


def calls():
    return [json.loads(x) for x in (BIN / "codex.log").read_text().splitlines()] if (BIN / "codex.log").exists() else []


def prompts():
    return [json.loads(x) for x in (BIN / "prompts.log").read_text().splitlines()]


def run_of(job):
    """The codex call of run JOB (a resume returns before codex exec starts: its thread id is known)."""
    out = str(RUNS / job / "last.txt")
    until(lambda: any(out in c["argv"] for c in calls()), f"codex call of {job}")
    return next(c for c in calls() if out in c["argv"])


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
assert c["argv"] == ["exec", "--json", "-o", str(RUNS / job / "last.txt"), "-C", str(CWD), "-s", "workspace-write",
                     "-m", "gpt-mini", "-"], c
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

# the front's recorded mode → sandbox, on every spawn: danger-full-access only when the front itself is bypass
SANDBOX = {"default": "workspace-write", "acceptEdits": "workspace-write", "auto": "workspace-write",
           "dontAsk": "workspace-write", "plan": "read-only", "bypassPermissions": "danger-full-access"}
for mode, sb in SANDBOX.items():
    registry.record_mode(REG, "front-uuid", mode)
    assert cli("spawn", f"m-{mode.lower()}", "--backend", "codex", "--cwd", str(CWD), "--request", "x").returncode == 0
    argv = calls()[-1]["argv"]
    assert argv[argv.index("-s") + 1] == sb and ("danger-full-access" in argv) == (mode == "bypassPermissions"), argv
    assert "--dangerously-bypass-approvals-and-sandbox" not in argv
for mode in SANDBOX:
    idle(f"m-{mode.lower()}")
# Codex labels a sandboxed exec run bypassPermissions (the stub emits it on every run): never recorded. The front
# mode is what the front's hook last recorded; no worker carries a mode; a Codex thread id cannot record one either.
registry.record_mode(REG, "front-uuid", "default")
registry.record_mode(REG, thread, "bypassPermissions")
assert reg()["front"]["permission_mode"] == "default", reg()["front"]
assert not any("permission_mode" in s for s in reg()["sessions"].values())

# resume an idle worker: `codex exec resume` on its thread, sandbox again via -c (resume has no -s), model kept
registry.record_mode(REG, "front-uuid", "plan")
r = cli("resume", "cx", "--request", "again")
assert r.returncode == 0 and re.fullmatch(r"[0-9a-f]{8}\n", r.stdout) and r.stdout.strip() != job, r
job = r.stdout.strip()
assert run_of(job)["argv"] == ["exec", "resume", "--json", "-o", str(RUNS / job / "last.txt"), "-c",
                               'sandbox_mode="read-only"', "-m", "gpt-mini", thread, "-"], calls()[-1]
cx = idle("cx")
assert prompts()[-1].endswith("Request from the user:\nagain")
assert cx["session_id"] == thread and cx["last_result"] == f"pong {len(calls())}", cx
registry.record_mode(REG, "front-uuid", "default")

# busy: a forward while a run is going is held (no second run on the thread), then sent as the next run when it ends
(BIN / "hold").touch()
r = cli("resume", "cx", "--request", "slow")
assert r.returncode == 0, r
busy = r.stdout.strip()
run_of(busy)
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
assert len(calls()) == n + 1 and calls()[-1]["argv"][:2] == ["exec", "resume"] and "held" not in cx, (calls(), cx)
assert prompts()[-1].endswith("Request from the user:\nfollow-up 1\n\nfollow-up 2"), prompts()[-1]
assert cx["last_result"] == f"pong {n + 1}" and cx["job_id"] != busy, cx

# stop: SIGTERM to the run's process group (supervisor and codex exec); refresh then shows it exited; resumable
(BIN / "hold").touch()
job = cli("resume", "cx", "--request", "long").stdout.strip()
run_of(job)  # codex exec is running, in the supervisor's process group
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

# a failed run: its error becomes last_result (not a stale result), the worker stays resumable (idle/failed)
(BIN / "fail").touch()
job = cli("resume", "cx", "--request", "x").stdout.strip()
until(lambda: worker("cx").get("last_result") == "codex exec failed (exit 1): boom", "failure recorded")
(BIN / "fail").unlink()
assert "- cx [idle/failed codex]" in cli("refresh").stdout
# a spawn whose codex exec never started a thread fails at once: exit 1, name exited without ids (reusable)
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

# dispatch by backend: a Claude worker next to Codex workers still goes to claude, refresh reads both lists
assert cli("spawn", "cl", "--cwd", str(CWD), "--request", "x").returncode == 0
assert (BIN / "claude.log").read_text().splitlines()[-1].startswith("--bg --name cl --agent router:topic-worker")
assert "backend" not in worker("cl")
r = cli("refresh", "--json")
assert r.returncode == 0 and json.loads(r.stdout)["sessions"]["cx"]["state"] == "idle", r
assert cli("stop", "cl").returncode == 0 and (BIN / "claude.log").read_text().splitlines()[-1] == "stop c1a0de01"

# no supervisor left running
assert not [f for f in RUNS.glob("*/run.json") if json.loads(f.read_text())["state"] == "working"]
print("PASS test_codex")
