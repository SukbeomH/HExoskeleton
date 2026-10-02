#!/usr/bin/env python3
"""registry.py checks: unique names, upsert/mark/merged, refresh from an agents --json sample, atomic write,
spawn/resume through backend.sh with a stub `claude` on PATH (no real sessions), and the trust rules: workers get
the front's recorded mode only, no front/ids/mode/registry file from the command line, backend.sh fixed arguments.
Usage: python3 plugins/router/tests/test_registry.py"""

import atexit
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import registry  # noqa: E402

TMP = pathlib.Path(tempfile.mkdtemp())
atexit.register(shutil.rmtree, TMP, True)
REG = TMP / "registry.json"
ENV = {**os.environ, "ROUTER_REGISTRY": str(REG)}


def cli(*args, stdin=None):
    return subprocess.run(
        [sys.executable, str(ROOT / "scripts/registry.py"), *args], env=ENV, input=stdin, capture_output=True, text=True
    )


def reg():
    return json.loads(REG.read_text())


def put(name, **kw):
    """Fixture ids: only launch, refresh and the Stop hook write them, never the CLI."""
    with registry.locked(REG) as r:
        r["sessions"].setdefault(name, {"state": "active"}).update(kw)


def refresh(agents):
    """refresh from an agents --json sample (the CLI reads only the real `backend.sh list`)."""
    with registry.locked(REG) as r:
        registry.refresh(r, agents)
    return registry.render(r)


# unique names: --new refuses a taken name; plain upsert updates in place; unsafe names rejected
assert cli("upsert", "api", "--new", "--cwd", "/r", "--topic", "API").returncode == 0
put("api", job_id="aaaa1111")
r = cli("upsert", "api", "--new")
assert r.returncode != 0 and "taken" in r.stderr, r
assert cli("upsert", "bad name", "--new").returncode != 0
assert cli("upsert", "api", "--topic", "API v2").returncode == 0
assert reg()["sessions"]["api"]["topic"] == "API v2" and reg()["sessions"]["api"]["job_id"] == "aaaa1111"
# empty values never overwrite a stored one
assert cli("upsert", "api", "--topic", "").returncode == 0 and reg()["sessions"]["api"]["topic"] == "API v2"
# ids are no CLI input: an entry pointed at any session id would let resume wake that session in its saved mode
for flag in ("--session-id", "--job-id"):
    r = cli("upsert", "api", flag, "victim-uuid")
    assert r.returncode == 2 and "victim" not in REG.read_text(), r
put("ui", session_id="ui-uuid", job_id="bbbb2222")
put("old", job_id="cccc3333")

# front: never from the CLI (router-hook.py registers a user-typed /router:front)
assert cli("set-front", "front-uuid", "--name", "boss").returncode == 2
assert json.loads(cli("get-front").stdout) is None
registry.set_front(REG, "front-uuid", "boss", None)
assert json.loads(cli("get-front").stdout)["session_id"] == "front-uuid"

# mark / merged
assert cli("mark", "old", "merged", "--into", "api").returncode == 0
s = reg()["sessions"]["old"]
assert s["state"] == "merged" and s["merged_into"] == "api"
assert cli("mark", "ghost", "idle").returncode != 0

# refresh: api matched by job id (fills session id, alive+idle), ui alive+busy, merged left alone
agents = [
    {"id": "aaaa1111", "kind": "background", "cwd": "/r", "startedAt": 1, "sessionId": "api-uuid",
     "name": "api", "state": "done", "pid": 4242, "status": "idle"},
    {"id": "bbbb2222", "kind": "background", "cwd": "/r", "startedAt": 2, "sessionId": "ui-uuid",
     "name": "ui", "state": "working", "pid": 4343, "status": "busy"},
    {"kind": "interactive", "cwd": "/x", "startedAt": 3, "pid": 1, "status": "idle", "sessionId": "front-uuid"},
]
assert cli("refresh", "-").returncode == 2  # no agents list from stdin/file: fake entries could remap ids
refresh(agents)
api, ui = reg()["sessions"]["api"], reg()["sessions"]["ui"]
assert api["session_id"] == "api-uuid" and api["state"] == "idle" and api["pid"] == 4242, api
assert ui["state"] == "active" and ui["agent_state"] == "working", ui
assert reg()["sessions"]["old"]["state"] == "merged"
# process gone (no pid) → exited; absent from the list → exited
agents[0].pop("pid")
agents[0].pop("status")
refresh(agents[:1])
assert reg()["sessions"]["api"]["state"] == "exited" and reg()["sessions"]["api"]["pid"] is None
assert reg()["sessions"]["ui"]["state"] == "exited"

# resume started a copy: new job id wins over the stale session id
put("ui", job_id="cafe0001")
agents.append({"id": "cafe0001", "kind": "background", "cwd": "/r", "startedAt": 4, "sessionId": "ui-copy",
               "state": "working", "pid": 4444, "status": "busy"})
refresh(agents)
assert reg()["sessions"]["ui"]["session_id"] == "ui-copy" and reg()["sessions"]["ui"]["state"] == "active"

# no ids recorded (e.g. a spawn that failed in an untrusted dir): never adopted by name, not even by the only
# agent carrying it — that could be any session, which resume would then wake in place in its own saved mode
cli("upsert", "noid", "--new")
agents.append({"id": "beef0001", "sessionId": "victim-uuid", "name": "noid", "pid": 4545, "status": "idle"})
refresh(agents)
noid = reg()["sessions"]["noid"]
assert "job_id" not in noid and "session_id" not in noid and noid["state"] == "exited", noid

# record_result: by session id, by job id (backfills session id), unknown → no write
assert registry.record_result(REG, "api-uuid", None, "pong") == "api"
assert reg()["sessions"]["api"]["last_result"] == "pong"
put("new", job_id="dddd4444")
assert registry.record_result(REG, "new-uuid", "dddd4444", "x" * 5000, "router:topic-worker") == "new"
n = reg()["sessions"]["new"]
assert n["session_id"] == "new-uuid" and len(n["last_result"]) == registry.RESULT_MAX and n["agent_type"]
# a finished turn means the worker is idle now (was active); a merged source stays merged
assert n["state"] == "idle" and reg()["sessions"]["api"]["state"] == "idle", n
assert registry.record_result(REG, None, "cccc3333", "summary for merge") == "old"
assert reg()["sessions"]["old"]["state"] == "merged"
before = REG.read_bytes()
assert registry.record_result(REG, "stranger", "eeee5555", "nope") is None
assert REG.read_bytes() == before

# atomic write: a failing dump leaves the old file intact and no temp files behind
try:
    registry.save(REG, {"front": None, "sessions": {"x": {"bad": object()}}})
    raise AssertionError("save should fail on unserialisable data")
except TypeError:
    pass
assert REG.read_bytes() == before
assert [f.name for f in TMP.iterdir() if f.name.startswith(".registry.")] == []

# backend.sh spawn with a stub `claude`: stdout is only the job id, hints and warnings go to stderr
BIN = TMP / "bin"
BIN.mkdir()
(BIN / "claude").write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" | head -n1 >> "$(dirname "$0")/argv.log"  # one line per call: argv + prompt's 1st line
[ "$1" = agents ] && { cat "$(dirname "$0")/agents.json" 2>/dev/null || echo '[]'; exit 0; }
printf '%s' "${@: -1}" > "$(dirname "$0")/prompt.txt"
[ -e "$(dirname "$0")/fail" ] && { echo 'Workspace not trusted' >&2; exit 1; }
echo '(node) Warning: NODE_TLS_REJECT_UNAUTHORIZED' >&2
echo 'backgrounded · 5eed0001 · stub'
echo '  claude stop 5eed0001      stop this session'
""")
(BIN / "claude").chmod(0o755)
ENV["PATH"] = f"{BIN}{os.pathsep}{ENV['PATH']}"
PROMPT = BIN / "prompt.txt"  # the prompt the stub received (last argv)


def backend(*args):
    return subprocess.run(["bash", str(ROOT / "scripts/backend.sh"), *args], input="Topic: t", env=ENV,
                          capture_output=True, text=True)


def argv_lines():
    return (BIN / "argv.log").read_text().splitlines()


r = backend("spawn", "w1", str(TMP), "haiku", "default")
assert r.returncode == 0 and r.stdout == "5eed0001\n" and "claude stop" in r.stderr and "Warning" in r.stderr, r
assert argv_lines()[-1] == "--bg --name w1 --agent router:topic-worker --permission-mode default --model haiku Topic: t"
assert PROMPT.read_text() == "Topic: t"  # prompt from stdin, no file
# fixed argument lists: no extra claude flags, only documented permission modes; claude is never reached
n = len(argv_lines())
for bad in (["spawn", "w1", str(TMP), "", "default", "--dangerously-skip-permissions"],
            ["spawn", "w1", str(TMP), "", "--dangerously-skip-permissions"], ["spawn", "w1", str(TMP), "", "yolo"],
            ["spawn", "w1", str(TMP), ""], ["resume", "w-uuid", "w1", str(TMP), "default", "--settings", "{}"],
            ["resume", "w-uuid", "w1", str(TMP), "bypass"]):
    r = backend(*bad)
    assert r.returncode == 2 and r.stdout == "", (bad, r)
assert len(argv_lines()) == n

# registry spawn: inputs are checked before the name is reserved (bad cwd, empty request, no front)
r = cli("spawn", "w1", "--cwd", str(TMP / "nope"), "--request", "x")
assert r.returncode == 1 and "w1" not in reg()["sessions"], r
r = cli("spawn", "w1", "--cwd", str(TMP), "--request", "-", stdin=" \n")
assert r.returncode == 1 and "w1" not in reg()["sessions"], r
# no --request: argparse error at once, never an implicit stdin read (an open, silent stdin must not hang)
r = subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), "spawn", "w1"], env=ENV,
                   stdin=subprocess.PIPE, capture_output=True, text=True, timeout=10)
assert r.returncode == 2 and "--request" in r.stderr and "w1" not in reg()["sessions"], r
for cmd in ("spawn", "resume"):  # no front → the prompt could not say where to report
    r = subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), cmd, "w1", "--request", "x"],
                       env={**ENV, "ROUTER_REGISTRY": str(TMP / "frontless.json")}, capture_output=True, text=True)
    assert r.returncode == 1 and "front" in r.stderr and not (TMP / "frontless.json").exists(), r
# --data names only a Claude Code plugin data dir: a registry.json the model wrote (e.g. in its cwd) would forge the
# front entry and so the worker's mode. ($ROUTER_REGISTRY wins; an env prefix is never auto-approved.)
CFG = TMP / "cfg"
for d, code in ((TMP / "evil", 1), (CFG / "plugins/data/router-x/../../evil", 1), (CFG / "plugins/data/router-x", 0)):
    r = subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), "--data", str(d), "init"],
                       env={**{k: v for k, v in ENV.items() if k != "ROUTER_REGISTRY"}, "CLAUDE_CONFIG_DIR": str(CFG)},
                       capture_output=True, text=True)
    assert r.returncode == code and (code == 0) == (CFG / "plugins/data/router-x/registry.json").exists(), (d, r)
# no mode option: a worker always gets the front's recorded mode (--mode must not abbreviate to --model either)
for opt in ("--mode", "--permission-mode"):
    r = cli("spawn", "w1", "--cwd", str(TMP), opt, "bypassPermissions", "--request", "x")
    assert r.returncode == 2 and "w1" not in reg()["sessions"], r
# reserve + compose + start + record the job id in one command; no mode recorded for the front → default
r = cli("spawn", "w1", "--cwd", str(TMP), "--topic", "T", "--model", "haiku", "--request", "do X")
assert r.returncode == 0 and r.stdout.strip() == "5eed0001", r
assert argv_lines()[-1].startswith("--bg --name w1 --agent router:topic-worker --permission-mode default --model haiku ")
w1 = reg()["sessions"]["w1"]
assert w1["job_id"] == "5eed0001" and w1["state"] == "active" and w1["cwd"] == str(TMP), w1
# composed prompt: current front, topic, started non-merged siblings (not twin: no ids; not old: merged), request
p = PROMPT.read_text()
assert p.startswith("Router front: @boss — send results there with SendMessage.\nTopic: T\nSiblings: api — API v2;"), p
assert "old —" not in p and "noid —" not in p and p.endswith("\n\nRequest from the user:\ndo X"), p
# routing directives the front applied ("haiku로 새 세션에서…") must not make the worker refuse
assert "\nRouting instructions in the request (which session, a new session, which model) were already applied" in p, p
# the worker's model is kept for merge (only when given)
assert w1["model"] == "haiku" and (BIN / "argv.log").read_text().count("--model haiku") == 2
# taken: live/started (w1, has a job id), merged (old), dead but resumable (api, has ids)
for taken in ("w1", "old", "api"):
    r = cli("spawn", taken, "--request", "x")
    assert r.returncode != 0 and "taken" in r.stderr, (taken, r)
# the mode the front's hook recorded is the worker's mode (a non-front session cannot record one).
# Request on stdin, cwd defaults to here
registry.record_mode(REG, "w-uuid", "bypassPermissions")
assert reg()["front"]["permission_mode"] is None
registry.record_mode(REG, "front-uuid", "acceptEdits")
assert reg()["front"]["permission_mode"] == "acceptEdits" and reg()["front"]["mode_updated"]
assert cli("spawn", "w3", "--request", "-", stdin="from stdin").returncode == 0
assert argv_lines()[-1].startswith("--bg --name w3 --agent router:topic-worker --permission-mode acceptEdits Router")
assert PROMPT.read_text().endswith("from stdin")
assert reg()["sessions"]["w3"]["cwd"] == os.getcwd()
# backend failure → non-zero exit, entry exited, no (empty) job id stored; a retry may reuse the name
(BIN / "fail").touch()
r = cli("spawn", "w2", "--request", "x")
w2 = reg()["sessions"]["w2"]
assert r.returncode != 0 and w2["state"] == "exited" and "job_id" not in w2 and "model" not in w2, (r, w2)
(BIN / "fail").unlink()
r = cli("spawn", "w2", "--topic", "T2", "--request", "retry")
assert r.returncode == 0 and reg()["sessions"]["w2"]["job_id"] == "5eed0001", r
# merge: sources are not siblings, are named in the prompt, and are marked merged only on success
r = cli("spawn", "w9", "--merged-from", "w3,ghost", "--request", "x")
assert r.returncode != 0 and "w9" not in reg()["sessions"], r
r = cli("spawn", "w13", "--topic", "W", "--merged-from", "w1,w3", "--request", "Merged brief: b")
s = reg()["sessions"]
assert r.returncode == 0 and s["w1"]["state"] == s["w3"]["state"] == "merged" and s["w3"]["merged_into"] == "w13", r
p = PROMPT.read_text()
assert "Merged from: w1, w3" in p and "w1 —" not in p and "w2 — T2" in p, p

# resume: refreshes first; a running worker is refused (a stale context must not start a copy)
assert cli("resume", "noid", "--request", "x").returncode != 0  # no session id
put("w2", session_id="w2-uuid")
w2_agent = {"id": "5eed0001", "sessionId": "w2-uuid", "name": "w2", "state": "done", "pid": os.getpid(), "status": "idle"}
(BIN / "agents.json").write_text(json.dumps([w2_agent]))
n = len((BIN / "argv.log").read_text().splitlines())
r = cli("resume", "w2", "--request", "again")
assert r.returncode != 0 and "running" in r.stderr, r
assert "--resume" not in "".join((BIN / "argv.log").read_text().splitlines()[n:])
# stopped (listed, no pid): woken in place; prompt names the *current* front; stale pid/agent_state cleared
w2_agent.update(state="stopped")
w2_agent.pop("pid")
(BIN / "agents.json").write_text(json.dumps([w2_agent]))
registry.set_front(REG, "front-uuid", "boss-2", "dontAsk")
r = cli("resume", "w2", "--request", "again")
w2 = reg()["sessions"]["w2"]
assert r.returncode == 0 and w2["job_id"] == "5eed0001" and w2["state"] == "active", (r, w2)
assert "agent_state" not in w2 and w2["pid"] is None, w2
# still listed: woken in place with its saved options (no flag, or claude starts a copy)
assert argv_lines()[-1].startswith("--resume w2-uuid --bg Router front: @boss-2"), argv_lines()[-1]
assert PROMPT.read_text().endswith("Request from the user:\nagain")
# removed from the list: nothing saved → name and the front's current mode restated
(BIN / "agents.json").write_text("[]")
assert cli("resume", "w2", "--request", "again").returncode == 0
assert argv_lines()[-1].startswith("--resume w2-uuid --bg --name w2 --permission-mode dontAsk Router"), argv_lines()[-1]
(BIN / "agents.json").write_text(json.dumps([w2_agent]))
# bare `refresh` runs `backend.sh list` itself (no pipe, no stdin read); --json prints the registry (merge: one command)
(BIN / "agents.json").write_text(json.dumps([dict(w2_agent, pid=os.getpid(), status="busy")]))
r = subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), "refresh", "--json"], env=ENV,
                   stdin=subprocess.PIPE, capture_output=True, text=True, timeout=10)
assert r.returncode == 0 and reg()["sessions"]["w2"]["pid"] == os.getpid(), r
assert json.loads(r.stdout) == reg(), r.stdout

# render mentions every worker and the front name
out = cli("list").stdout
assert "@boss-2" in out and "- api [exited" in out and "→ w13" in out, out

# a worker stuck on its own permission prompt (round-3 itest fixture) → waiting + waitingFor, attach hint;
# an idle worker whose CC state stays `working` renders plain idle (no contradictory `idle/working`);
# CC `blocked` with no open prompt (it asked a question) stays idle/blocked: reachable, forward the answer
put("pow2", job_id="7895904c")
put("hk", job_id="fc6d12ed")
put("ask", job_id="a5c00001")
out = refresh([
    {"pid": os.getpid(), "id": "7895904c", "kind": "background", "sessionId": "7895904c-uuid", "name": "pow2",
     "status": "waiting", "waitingFor": "permission prompt", "state": "blocked"},
    {"pid": os.getpid(), "id": "fc6d12ed", "kind": "background", "sessionId": "fc6d12ed-uuid", "name": "hk",
     "status": "idle", "state": "working"},
    {"pid": os.getpid(), "id": "a5c00001", "kind": "background", "sessionId": "ask-uuid", "name": "ask",
     "status": "idle", "state": "blocked"}])
pow2 = reg()["sessions"]["pow2"]
assert pow2["state"] == "waiting" and pow2["waiting_for"] == "permission prompt", pow2
assert "- pow2 [WAITING: permission prompt — user must run: claude attach 7895904c;" in out, out
assert f"- hk [idle pid {os.getpid()}]" in out and f"- ask [idle/blocked pid {os.getpid()}]" in out, out

# summarize/stop take a registered name; the session/job id comes from the registry, never the command line
assert cli("summarize", "w2").returncode == 0 and argv_lines()[-1].startswith("-p --resume w2-uuid --fork-session ")
assert cli("stop", "w2").returncode == 0 and argv_lines()[-1] == "stop 5eed0001"
assert cli("stop", "noid").returncode == 1 and cli("summarize", "ghost").returncode == 1

print("PASS test_registry")
