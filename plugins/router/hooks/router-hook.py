#!/usr/bin/env python3
"""router hooks — silent exit 0 unless this session has a router role.

UserPromptExpansion of a user-typed /router:front (command_name router:front, command_source plugin) → this
  session becomes the front: session_id, name (its `claude agents` entry) and permission_mode from the hook input.
  Only a typed command expands (a model Skill call or a cross-session message does not), so the front is
  human-registered; registry.py has no CLI for it.
UserPromptSubmit: only in the front session (session_id == registry front) → record its permission_mode (the mode
  every worker gets) and add additionalContext with the compact registry.
Stop: only in a worker (session_id, or $CLAUDE_JOB_DIR's job id, is in the registry) → store
  last_assistant_message as last_result.
PermissionRequest: only in a worker → approvals/pending/<nonce>.json (the exact tool_input), then wait for the decision
  a user-typed /router:approve writes in the front; answer allow/deny only. No decision in time → no output, so the
  normal prompt stays (claude attach).
Anything else, including a missing registry: no output, no write.
"""

import contextlib
import json
import os
import pathlib
import secrets
import signal
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "scripts"))
import registry  # noqa: E402

WAIT = float(os.environ.get("ROUTER_APPROVAL_WAIT", "300"))  # poll limit (s); well under the hook timeout (600)
TTL = 600  # the PermissionRequest timeout in hooks.json: an older file belongs to a hook that was killed

HINT = (
    "This is the router front session. Before answering, follow the router:route skill: classify the "
    "message against the workers above (forward / new / broadcast / status, or merge only on explicit "
    "request) instead of doing topic work here."
)


def main():
    data = json.load(sys.stdin)
    p = registry.path()
    sid = data.get("session_id")
    event = data.get("hook_event_name")
    if p is None or not sid:
        return
    if event == "UserPromptExpansion":
        if data.get("command_name") == "router:front" and data.get("command_source") == "plugin":
            me = [a for a in registry.backend_agents() or [] if a.get("sessionId") == sid]
            registry.set_front(p, sid, me[0].get("name") if me else None, data.get("permission_mode"))
        return
    if not p.exists():
        return
    if event == "UserPromptSubmit":
        if (registry.load(p).get("front") or {}).get("session_id") != sid:
            return
        reg = registry.record_mode(p, sid, data.get("permission_mode"))
        ctx = registry.render(reg) + "\n" + HINT
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": ctx}}))
    elif event == "Stop":
        registry.record_result(p, sid, job_id(), data.get("last_assistant_message") or "", data.get("agent_type"))
    elif event == "PermissionRequest":
        permission_request(p, sid, data)


def job_id():
    return pathlib.Path(os.environ.get("CLAUDE_JOB_DIR", "")).name or None


def permission_request(p, sid, data):
    """A worker's permission prompt → pending/<nonce>.json for the front, then poll decisions/<nonce>.json.
    A decision counts only if it names this nonce, is newer than the request, and is read once (deleted first)."""
    if data.get("permission_mode") == "dontAsk":  # that mode promises never to wait
        return
    name = registry.find_worker(registry.load(p), sid, job_id())
    if not name:
        return
    a = registry.approvals(p)
    for f in [*a.glob("pending/*.json"), *a.glob("decisions/*.json")]:
        with contextlib.suppress(FileNotFoundError):
            if time.time() - f.stat().st_mtime > TTL:
                f.unlink()
    nonce, t0 = secrets.token_hex(4), time.time()
    pend, dec = a / "pending" / f"{nonce}.json", a / "decisions" / f"{nonce}.json"
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))  # a cancelled hook still removes its pending file
    registry.save(pend, {"nonce": nonce, "worker": name, "session_id": sid, "job_id": job_id(),
                         "tool_name": data.get("tool_name"), "tool_input": data.get("tool_input"),
                         "created": t0, "expires": t0 + WAIT})
    try:
        while time.time() < t0 + WAIT:
            d = None
            with contextlib.suppress(FileNotFoundError, ValueError):
                raw = dec.read_text()
                dec.unlink()  # used once, valid or not
                d = json.loads(raw)
            if (isinstance(d, dict) and d.get("nonce") == nonce and isinstance(d.get("created"), (int, float))
                    and d["created"] >= t0 and d.get("behavior") in ("allow", "deny")):
                out = {"behavior": d["behavior"]}  # never updatedInput/updatedPermissions: this call, as shown
                if d["behavior"] == "deny":
                    out["message"] = f"The user denied this in the router front (/router:approve {nonce} deny)."
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": out}}))
                return
            time.sleep(0.5)
    finally:
        pend.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never break the session over router bookkeeping
        print(f"router-hook: {e}", file=sys.stderr)
    sys.exit(0)
