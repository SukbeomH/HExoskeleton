#!/usr/bin/env python3
"""registry.py checks: unique names, upsert/mark/merged, refresh from an agents --json sample, atomic write,
spawn/resume through backend.sh with a stub `claude` on PATH (no real sessions).
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


# unique names: --new refuses a taken name; plain upsert updates in place; unsafe names rejected
assert cli("upsert", "api", "--new", "--job-id", "aaaa1111", "--cwd", "/r", "--topic", "API").returncode == 0
r = cli("upsert", "api", "--new")
assert r.returncode != 0 and "taken" in r.stderr, r
assert cli("upsert", "bad name", "--new").returncode != 0
assert cli("upsert", "api", "--topic", "API v2").returncode == 0
assert reg()["sessions"]["api"]["topic"] == "API v2" and reg()["sessions"]["api"]["job_id"] == "aaaa1111"
# empty ids (e.g. a failed $JOB capture) never overwrite a stored id
assert cli("upsert", "api", "--job-id", "", "--session-id", "").returncode == 0
assert reg()["sessions"]["api"]["job_id"] == "aaaa1111" and "session_id" not in reg()["sessions"]["api"]
assert cli("upsert", "ui", "--new", "--session-id", "ui-uuid", "--job-id", "bbbb2222").returncode == 0
assert cli("upsert", "old", "--new", "--job-id", "cccc3333").returncode == 0

# front: explicit id, and refusal of an unsubstituted ${CLAUDE_SESSION_ID}
assert cli("set-front", "front-uuid", "--name", "boss").returncode == 0
assert json.loads(cli("get-front").stdout)["session_id"] == "front-uuid"
assert cli("set-front", "${CLAUDE_SESSION_ID}").returncode != 0

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
r = cli("refresh", "-", stdin=json.dumps(agents))
assert r.returncode == 0, r.stderr
api, ui = reg()["sessions"]["api"], reg()["sessions"]["ui"]
assert api["session_id"] == "api-uuid" and api["state"] == "idle" and api["pid"] == 4242, api
assert ui["state"] == "active" and ui["agent_state"] == "working", ui
assert reg()["sessions"]["old"]["state"] == "merged"
# process gone (no pid) → exited; absent from the list → exited
agents[0].pop("pid")
agents[0].pop("status")
cli("refresh", "-", stdin=json.dumps(agents[:1]))
assert reg()["sessions"]["api"]["state"] == "exited" and reg()["sessions"]["api"]["pid"] is None
assert reg()["sessions"]["ui"]["state"] == "exited"

# resume started a copy: new job id wins over the stale session id
cli("upsert", "ui", "--job-id", "cafe0001")
agents.append({"id": "cafe0001", "kind": "background", "cwd": "/r", "startedAt": 4, "sessionId": "ui-copy",
               "state": "working", "pid": 4444, "status": "busy"})
cli("refresh", "-", stdin=json.dumps(agents))
assert reg()["sessions"]["ui"]["session_id"] == "ui-copy" and reg()["sessions"]["ui"]["state"] == "active"

# no ids recorded: matched by its unique name (ids backfilled); a name two agents share → left unchanged
cli("upsert", "noid", "--new", "--job-id", "")
cli("upsert", "twin", "--new")
agents += [
    {"id": "beef0001", "sessionId": "noid-uuid", "name": "noid", "pid": 4545, "status": "idle"},
    {"id": "beef0002", "sessionId": "twin-a", "name": "twin", "pid": 4646, "status": "busy"},
    {"id": "beef0003", "sessionId": "twin-b", "name": "twin", "state": "done"},
]
twin = reg()["sessions"]["twin"]
cli("refresh", "-", stdin=json.dumps(agents))
noid = reg()["sessions"]["noid"]
assert noid["job_id"] == "beef0001" and noid["session_id"] == "noid-uuid" and noid["state"] == "idle", noid
assert reg()["sessions"]["twin"] == twin, reg()["sessions"]["twin"]

# record_result: by session id, by job id (backfills session id), unknown → no write
assert registry.record_result(REG, "api-uuid", None, "pong") == "api"
assert reg()["sessions"]["api"]["last_result"] == "pong"
cli("upsert", "new", "--new", "--job-id", "dddd4444")
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
printf '%s\\n' "$*" >> "$(dirname "$0")/argv.log"
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
r = subprocess.run(["bash", str(ROOT / "scripts/backend.sh"), "spawn", "w1", str(TMP), "haiku", "default"],
                   input="Topic: t", env=ENV, capture_output=True, text=True)
assert r.returncode == 0 and r.stdout == "5eed0001\n" and "claude stop" in r.stderr and "Warning" in r.stderr, r
argv = (BIN / "argv.log").read_text()
assert "--agent router:topic-worker --model haiku --permission-mode default" in argv, argv
assert PROMPT.read_text() == "Topic: t"  # prompt from stdin, no file

# registry spawn: inputs are checked before the name is reserved (bad cwd, empty request, no front)
r = cli("spawn", "w1", "--cwd", str(TMP / "nope"), "--request", "x")
assert r.returncode == 1 and "w1" not in reg()["sessions"], r
r = cli("spawn", "w1", "--cwd", str(TMP), stdin=" \n")
assert r.returncode == 1 and "w1" not in reg()["sessions"], r
r = subprocess.run([sys.executable, str(ROOT / "scripts/registry.py"), "spawn", "w1", "--request", "x"],
                   env={**ENV, "ROUTER_REGISTRY": str(TMP / "frontless.json")}, capture_output=True, text=True)
assert r.returncode == 1 and "front" in r.stderr, r
# reserve + compose + start + record the job id in one command
r = cli("spawn", "w1", "--cwd", str(TMP), "--topic", "T", "--model", "haiku", "--mode", "default", "--request", "do X")
assert r.returncode == 0 and r.stdout.strip() == "5eed0001", r
w1 = reg()["sessions"]["w1"]
assert w1["job_id"] == "5eed0001" and w1["state"] == "active" and w1["cwd"] == str(TMP), w1
# composed prompt: current front, topic, started non-merged siblings (not twin: no ids; not old: merged), request
p = PROMPT.read_text()
assert p.startswith("Router front: @boss — send results there with SendMessage.\nTopic: T\nSiblings: api — API v2;"), p
assert "old —" not in p and "twin —" not in p and p.endswith("\n\nRequest from the user:\ndo X"), p
# the worker's model is kept for merge (only when given)
assert w1["model"] == "haiku" and (BIN / "argv.log").read_text().count("--model haiku") == 2
# taken: live/started (w1, has a job id), merged (old), dead but resumable (api, has ids)
for taken in ("w1", "old", "api"):
    r = cli("spawn", taken, "--request", "x")
    assert r.returncode != 0 and "taken" in r.stderr, (taken, r)
# the hook hint says --permission-mode; spawn accepts it as --mode. Request on stdin, cwd defaults to here
assert cli("spawn", "w3", "--permission-mode", "acceptEdits", stdin="from stdin").returncode == 0
assert "--permission-mode acceptEdits" in (BIN / "argv.log").read_text() and PROMPT.read_text().endswith("from stdin")
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

# resume: stored session id and cwd, job id recorded, state active; the prompt names the *current* front
assert cli("resume", "twin", "--request", "x").returncode != 0  # no session id
cli("upsert", "w2", "--session-id", "w2-uuid")
cli("set-front", "front-uuid", "--name", "boss-2")
r = cli("resume", "w2", "--request", "again")
w2 = reg()["sessions"]["w2"]
assert r.returncode == 0 and w2["job_id"] == "5eed0001" and w2["state"] == "active", (r, w2)
assert "--resume w2-uuid --bg" in (BIN / "argv.log").read_text()
assert PROMPT.read_text().startswith("Router front: @boss-2") and PROMPT.read_text().endswith("user:\nagain")

# render mentions every worker and the front name
out = cli("list").stdout
assert "@boss-2" in out and "- api [idle" in out and "→ w13" in out, out

print("PASS test_registry")
