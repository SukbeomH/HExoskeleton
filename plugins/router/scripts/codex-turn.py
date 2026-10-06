#!/usr/bin/env python3
"""codex-turn.py — one Codex turn on a router-private `codex app-server` (stdio child) for codex-run.py (stdlib).

  codex-turn.py JOB_DIR NAME CWD SANDBOX APPROVAL MODEL|"" THREAD|""   (prompt on stdin)

Talks to codex-run.py like `codex exec --json -o JOB_DIR/last.txt`: prints {"type": "thread.started", "thread_id"}
once the thread is started (THREAD "") or resumed, an error as {"type": "turn.failed"}, writes the turn's last agent
message to JOB_DIR/last.txt and exits 0 (turn completed) or 1. SANDBOX and APPROVAL (backend-codex.sh maps the front's
mode) are pinned on thread/start and thread/resume, and the run fails if Codex reports another sandbox or policy.

Approval relay: the app-server asks its client, this process (stdio: no socket, so nothing else can answer; a
workspace-write worker cannot reach a socket or write the plugin data dir, 2026-10-06 live test), to approve a command
or a file change. Each request becomes <registry dir>/approvals/pending/<nonce>.json in router-hook.py's record shape,
so the front lists it and only a user-typed /router:approve there writes its decision; this reads it once
(registry.take_decision) and answers accept or decline, never acceptForSession. No decision within
ROUTER_APPROVAL_WAIT (300 s) → decline: unlike a Claude worker there is no attach fallback. If the approvals dir is
writable inside the thread's sandbox (cwd, writable roots, /tmp, $TMPDIR), every request is declined unseen: the
worker could write its own decision. Other server requests are refused, so the turn never waits on them.
"""

import contextlib
import itertools
import json
import os
import pathlib
import queue
import secrets
import signal
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import registry  # noqa: E402

WAIT = registry.seconds("ROUTER_APPROVAL_WAIT", 300.0, 0)
POLL = registry.seconds("ROUTER_POLL_INTERVAL", 0.5, 0.01)
POLICY = {"read-only": "readOnly", "workspace-write": "workspaceWrite", "danger-full-access": "dangerFullAccess"}
REFUSE = {"item/permissions/requestApproval": {"permissions": {}},  # grant nothing extra
          "mcpServer/elicitation/request": {"action": "decline", "content": None}}


class Failed(Exception):
    pass


def emit(ev):
    print(json.dumps(ev), flush=True)


def writable(res, d):
    """Could a command in this thread's sandbox (thread/start or /resume result) write D? Unknown → yes."""
    sb = res.get("sandbox") or {}
    if sb.get("type") == "readOnly":
        return False
    if sb.get("type") != "workspaceWrite":
        return True
    roots = [res.get("cwd"), *(res.get("runtimeWorkspaceRoots") or []), *(sb.get("writableRoots") or [])]
    roots += [] if sb.get("excludeSlashTmp") else ["/tmp"]
    roots += [] if sb.get("excludeTmpdirEnvVar") else [os.environ.get("TMPDIR")]
    d = os.path.realpath(d)
    return any(d == r or d.startswith(r.rstrip("/") + "/") for r in (os.path.realpath(x) for x in roots if x))


def main(jd, name, cwd, sandbox, approval, model, thread):
    jd = pathlib.Path(jd)
    p = jd.parent.parent / "registry.json"  # backend-codex.sh: runs live in <registry dir>/codex/<job>/
    prompt = sys.stdin.read()
    srv = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    inbox, lock, ids, open_ = queue.Queue(), threading.Lock(), itertools.count(1), set()
    st = {"last": "", "files": {}, "turn": None, "err": None, "relay": False, "tid": thread}

    def bye(*_):
        for f in list(open_):
            f.unlink(missing_ok=True)
        os._exit(143)

    signal.signal(signal.SIGTERM, bye)  # stop: codex-run.py signals the process group; drop open requests first

    def orphaned(ppid=os.getppid()):
        """The supervisor was killed (SIGKILL: no stop) → end like a stop. Its result could never be recorded, and an
        orphaned app-server would hold the thread's writer lock until its turn ends (9th live test). The parent-death
        signal (Linux prctl) is not portable to macOS: poll the parent pid instead."""
        while os.getppid() == ppid:
            time.sleep(POLL)
        srv.terminate()
        bye()

    threading.Thread(target=orphaned, daemon=True).start()

    def read():
        for line in srv.stdout:
            try:
                inbox.put(json.loads(line))
            except ValueError:
                pass
        inbox.put(None)

    def send(m):
        with lock, contextlib.suppress(OSError, ValueError):  # a late answer after the turn: nobody is listening
            srv.stdin.write(json.dumps(m) + "\n")
            srv.stdin.flush()

    def relay(tool, inp):
        """pending/<nonce>.json → the user's typed decision → "accept" | "decline"."""
        if not st["relay"]:
            return "decline"
        nonce, t0 = secrets.token_hex(4), time.time()
        pend = registry.approvals(p) / "pending" / f"{nonce}.json"
        # no session_id: Codex may ask twice at once in one thread, so a newer request must not supersede this one
        registry.save(pend, {"nonce": nonce, "worker": name, "backend": "codex", "thread": st["tid"],
                             "job_id": jd.name, "tool_name": tool, "tool_input": inp, "created": t0,
                             "expires": t0 + WAIT})
        open_.add(pend)
        try:
            while time.time() < t0 + WAIT and st["turn"] is None:
                b = registry.take_decision(p, nonce, t0)
                if b:
                    return "accept" if b == "allow" else "decline"
                time.sleep(POLL)
        finally:
            open_.discard(pend)
            pend.unlink(missing_ok=True)
        return "decline"

    def answer(m):
        meth, q = m["method"], m.get("params") or {}
        if meth == "item/commandExecution/requestApproval":
            inp = {"command": q.get("command"), "cwd": q.get("cwd"), "network": q.get("networkApprovalContext")}
            res = {"decision": relay("Bash", {k: v for k, v in inp.items() if v})}
        elif meth == "item/fileChange/requestApproval":
            inp = {"changes": st["files"].get(q.get("itemId")), "grantRoot": q.get("grantRoot")}
            res = {"decision": relay("apply_patch", {k: v for k, v in inp.items() if v})}
        elif meth in REFUSE:
            res = REFUSE[meth]
        else:
            return send({"id": m["id"], "error": {"code": -32601, "message": f"router: {meth} not supported"}})
        send({"id": m["id"], "result": res})

    def handle(m):
        meth, q = m.get("method"), m.get("params") or {}
        if meth and "id" in m:  # a server request: answered in its own thread (an approval waits for the user)
            threading.Thread(target=answer, args=(m,), daemon=True).start()
        elif meth in ("item/started", "item/completed"):
            it = q.get("item") or {}
            if it.get("type") == "fileChange":
                st["files"][it.get("id")] = it.get("changes")
            elif it.get("type") == "agentMessage" and meth == "item/completed" and it.get("text"):
                st["last"] = it["text"]
        elif meth == "turn/completed":
            st["turn"] = q.get("turn") or {}
        elif meth == "error" and not q.get("willRetry"):
            st["err"] = (q.get("error") or {}).get("message")

    def call(method, params):
        i = next(ids)
        send({"id": i, "method": method, "params": params})
        while True:
            m = inbox.get()
            if m is None:
                raise Failed("codex app-server exited")
            if m.get("id") == i and "method" not in m:
                if "error" in m:
                    raise Failed(f"{method}: {(m['error'] or {}).get('message')}")
                return m["result"]
            handle(m)

    threading.Thread(target=read, daemon=True).start()
    try:
        call("initialize", {"clientInfo": {"name": "router", "version": "0"}})
        send({"method": "initialized"})
        args = {"cwd": cwd, "sandbox": sandbox, "approvalPolicy": approval, **({"model": model} if model else {})}
        res = call("thread/resume", {"threadId": thread, "excludeTurns": True, **args}) if thread else \
            call("thread/start", args)
        got = ((res.get("sandbox") or {}).get("type"), res.get("approvalPolicy"))
        if got != (POLICY[sandbox], approval):
            raise Failed(f"codex applied sandbox/approval {got}, not {(sandbox, approval)}")
        st["tid"] = res["thread"]["id"]
        st["relay"] = approval == "on-request" and not writable(res, registry.approvals(p))
        emit({"type": "thread.started", "thread_id": st["tid"]})
        call("turn/start", {"threadId": st["tid"], "input": [{"type": "text", "text": prompt}]})
        while st["turn"] is None:
            m = inbox.get()
            if m is None:
                raise Failed(st["err"] or "codex app-server exited mid-turn")
            handle(m)
        (jd / "last.txt").write_text(st["last"])
        if st["turn"].get("status") != "completed":
            raise Failed(((st["turn"].get("error") or {}).get("message")) or st["err"] or
                         f"turn {st['turn'].get('status')}")
        return 0
    except Failed as e:
        emit({"type": "turn.failed", "error": {"message": str(e)}})
        return 1
    finally:
        for f in list(open_):  # requests still open when the turn ended: their relay threads may not get to it
            f.unlink(missing_ok=True)
        with lock, contextlib.suppress(OSError):
            srv.stdin.close()  # stdin EOF ends the app-server
        try:
            srv.wait(5)
        except subprocess.TimeoutExpired:
            srv.kill()


if __name__ == "__main__":
    if len(sys.argv) != 8 or sys.argv[4] not in POLICY or sys.argv[5] not in ("on-request", "never"):
        sys.exit(__doc__.split("\n\n")[1])
    sys.exit(main(*sys.argv[1:]))
