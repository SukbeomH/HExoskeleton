#!/usr/bin/env python3
"""codex-run.py — supervises one Codex run for backend-codex.sh (stdlib only): a command speaking `codex exec --json`
(codex-turn.py: thread.started first, turn.failed on error, last message in JOB_DIR/last.txt).

  start JOB_DIR NAME CODEX_ARGV...  prompt on stdin → `run` in a session of its own (outlives the caller), then waits
        for the run's thread.started (thread started or resumed) and prints the job id (JOB_DIR's name); exit 1 with
        the run's error if it ended without one (e.g. thread/resume refused: `already has an active writer`)
  run   (same arguments)  the supervisor, internal
  list  DIR       one claude-agents-shaped entry per run: id, sessionId (thread), name, state, status, pid (live only)
  stop  JOB_DIR   SIGTERM to the run's process group (supervisor, codex-turn.py and its app-server)

JOB_DIR/run.json {pid, name, thread, state: working|done|failed|stopped, exit, error}. When the run ends, its last
message (JOB_DIR/last.txt) becomes the worker's last_result, as the Stop hook does for Claude workers, and follow-ups the
front held meanwhile go out as the next run (`backend-codex.sh resume` in the front's current mode). Only the
registry's own fields are written: nothing Codex reports (e.g. its hooks' permission_mode) reaches the registry.
$ROUTER_REGISTRY (set by registry.py) names the registry; it is not passed on to the run.
"""

import contextlib
import json
import os
import pathlib
import signal
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import registry  # noqa: E402

WAIT_THREAD = 60  # start: seconds for the run to report its thread id
WAIT_JOB = 10  # run: seconds for registry.py to record this job id (it does so right after start returns)


def read(jd):
    with contextlib.suppress(OSError, ValueError):
        return json.loads((jd / "run.json").read_text())
    return {}


def write(jd, st):
    registry.save(jd / "run.json", st)


def start(jd, name, argv):
    jd.mkdir(parents=True)
    prompt = sys.stdin.read()
    proc = subprocess.Popen([sys.executable, __file__, "run", str(jd), name, *argv], stdin=subprocess.PIPE,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, text=True)
    proc.stdin.write(prompt)
    proc.stdin.close()
    end = time.time() + WAIT_THREAD
    while time.time() < end:
        st = read(jd)
        if st.get("thread"):
            print(jd.name)
            return 0
        if proc.poll() is not None or st.get("state", "working") != "working":
            break
        time.sleep(0.05)
    if proc.poll() is None:  # no thread in time: end the run, the caller keeps its request (no second copy later)
        with contextlib.suppress(OSError):
            os.killpg(proc.pid, signal.SIGTERM)
    err = (jd / "stderr").read_text(errors="replace")[-2000:] if (jd / "stderr").exists() else ""
    print(f"backend-codex: no thread id from codex: {read(jd).get('error') or '?'}\n{err}".rstrip(), file=sys.stderr)
    return 1


def run(jd, name, argv):
    p = pathlib.Path(os.environ["ROUTER_REGISTRY"])
    prompt = sys.stdin.read()
    # no thread until the run reports it: a resume Codex refuses (e.g. another writer holds the thread) never counts
    # as started, so registry.py keeps its request and held follow-ups (requeue) instead of losing them
    st = {"pid": os.getpid(), "name": name, "thread": None, "state": "working", "started": time.time()}
    write(jd, st)
    signal.signal(signal.SIGTERM, lambda *_: (write(jd, st | {"state": "stopped"}), os._exit(143)))
    env = {k: v for k, v in os.environ.items() if k != "ROUTER_REGISTRY"}
    err = None
    with open(jd / "stderr", "w") as ef:
        try:
            c = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=ef, text=True, env=env)
        except OSError as e:
            c, err, rc = None, str(e), 127
        if c:
            with contextlib.suppress(BrokenPipeError):
                c.stdin.write(prompt)
                c.stdin.close()
            for line in c.stdout:
                with contextlib.suppress(ValueError, AttributeError, TypeError):
                    ev = json.loads(line)
                    if ev.get("type") == "thread.started" and not st["thread"]:
                        st["thread"] = str(ev["thread_id"])
                        write(jd, st)
                    elif ev.get("type") in ("error", "turn.failed"):
                        err = ev.get("message") or (ev.get("error") or {}).get("message")
            rc = c.wait()
    text = (jd / "last.txt").read_text(errors="replace") if (jd / "last.txt").exists() else ""
    if rc:
        tail = (jd / "stderr").read_text(errors="replace").strip().splitlines()[-1:]
        text = f"codex run failed (exit {rc}): {err or ' '.join(tail) or '?'}"
    st.update(state="failed" if rc else "done", exit=rc, **({"error": text} if rc else {}))
    if st["thread"]:
        finish(p, jd, st, text)
    write(jd, st)


def finish(p, jd, st, text):
    """Record the run's result on its worker (matched by this job id, which registry.py records right after `start`
    returns), then send the held follow-ups as the next run. Until that run is recorded run.json stays `working`, so
    a forward meanwhile is held for the next run instead of starting a second one on the same thread."""
    end = time.time() + WAIT_JOB
    while True:
        with registry.locked(p) as reg:
            name, held = registry.finish_run(reg, jd.name, st["thread"], text)
            if name and not held:
                write(jd, st)  # under the lock: a forward that sees this run idle is never held
        if name or time.time() > end:
            break
        time.sleep(0.1)
    if not held:
        return
    reg = registry.load(p)
    s = reg["sessions"][name]
    args = ["resume", st["thread"], name, s.get("cwd") or ".", registry.front_mode(reg), s.get("model") or ""]
    if not registry.launch(p, name, args, registry.compose(reg, name, "\n\n".join(held)), "codex"):
        registry.requeue(p, name, held)


def agents(d):
    # ponytail: one small run dir per run, never pruned; prune finished ones older than a few days here if they pile up.
    out = []
    for f in sorted(pathlib.Path(d).glob("*/run.json")):
        st = read(f.parent)
        state = st.get("state")
        live = state == "working" and registry.alive(st.get("pid"))
        a = {"id": f.parent.name, "kind": "codex", "sessionId": st.get("thread"), "name": st.get("name"),
             "startedAt": st.get("started"), "state": "crashed" if state == "working" and not live else state,
             "status": "busy" if live else "idle"}
        if live:
            a["pid"] = st["pid"]
        out.append(a)
    return out


def stop(jd):
    st = read(jd)
    if st.get("state") == "working" and registry.alive(st.get("pid")):
        os.killpg(int(st["pid"]), signal.SIGTERM)


def main(argv):
    cmd, rest = (argv[0], argv[1:]) if argv else ("", [])
    if cmd in ("start", "run") and len(rest) > 2:
        return (start if cmd == "start" else run)(pathlib.Path(rest[0]), rest[1], rest[2:])
    if cmd == "list" and len(rest) == 1:
        print(json.dumps(agents(rest[0])))
    elif cmd == "stop" and len(rest) == 1:
        stop(pathlib.Path(rest[0]))
    else:
        sys.exit(__doc__.split("\n\n")[1])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
