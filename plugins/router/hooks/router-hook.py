#!/usr/bin/env python3
"""router hooks — silent exit 0 unless this session has a router role.

UserPromptExpansion of a user-typed /router:front (command_name router:front, command_source plugin) → this
  session becomes the front: session_id, name (its `claude agents` entry) and permission_mode from the hook input.
  Only a typed command expands (a model Skill call or a cross-session message does not), so the front is
  human-registered; registry.py has no CLI for it.
UserPromptExpansion of a user-typed /router:approve [<id> [deny]] (same rule) → only in the front: write the decision
  for that open request, then block the prompt with what was approved (no model turn). Bare → list open requests.
UserPromptSubmit: only in the front session (session_id == registry front) → record its permission_mode (the mode
  every worker gets) and add additionalContext with the compact registry.
Stop: only in a worker (session_id, or $CLAUDE_JOB_DIR's job id, is in the registry) → store
  last_assistant_message as last_result.
PermissionRequest: only in a worker → approvals/pending/<nonce>.json (the exact tool_input), then wait for the decision
  a user-typed /router:approve writes in the front; answer allow/deny only. No decision in time → no output, so the
  normal prompt stays (claude attach).
PreToolUse SendMessage: only in a worker → deny a recipient that is another live session (not the front, not a
  sibling): a stale front name's "Did you mean" hint must not carry a report to an unrelated session.
Anything else, including a missing registry: no output, no write.
"""

import contextlib
import json
import os
import pathlib
import re
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
        if data.get("command_source") != "plugin":
            return
        if data.get("command_name") == "router:front":
            me = [a for a in registry.backend_agents() or [] if a.get("sessionId") == sid]
            registry.set_front(p, sid, me[0].get("name") if me else None, data.get("permission_mode"))
        elif data.get("command_name") == "router:approve":
            try:
                msg = approve(p, sid, data.get("command_args") or "")
            except Exception as e:  # still block: the prompt must never reach the model
                msg = f"router: not sent ({e})"
            print(json.dumps({"decision": "block", "reason": msg}))
        return
    if not p.exists():
        return
    if event == "UserPromptSubmit":
        if (registry.load(p).get("front") or {}).get("session_id") != sid:
            return
        reg = registry.record_mode(p, sid, data.get("permission_mode"))
        ctx = registry.render(reg, p=p) + "\n" + HINT
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": ctx}}))
    elif event == "Stop":
        registry.record_result(p, sid, job_id(), data.get("last_assistant_message") or "", data.get("agent_type"))
    elif event == "PermissionRequest":
        permission_request(p, sid, data)
    elif event == "PreToolUse" and data.get("tool_name") == "SendMessage":
        guard_send(p, sid, data)


def guard_send(p, sid, data):
    """A worker may message its front and its siblings, never another of the user's sessions. A report to a front
    that is gone gets "Did you mean <some other session>?", and a worker that followed it leaked the report there.
    Only live sessions (`claude agents`) are refused, so a worker's own subagent ids/names still pass."""
    reg = registry.load(p)
    if not registry.find_worker(reg, sid, job_id()):
        return
    front = reg.get("front") or {}
    to = str((data.get("tool_input") or {}).get("to") or "").lstrip("@")
    ours = {front.get("name"), front.get("session_id"), *reg["sessions"],
            *(s.get(k) for s in reg["sessions"].values() for k in ("session_id", "job_id"))}
    live = {a.get(k) for a in registry.backend_agents() or [] for k in ("name", "sessionId", "id")}
    if to and to in live - ours:
        why = (f"router: '{to}' is another session, not your front @{front.get('name')} or a sibling. Message no other "
               "session, not even one SendMessage suggests; if the front is unreachable, end your turn with the summary "
               "(the router records it).")
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                                 "permissionDecisionReason": why}}))


def approve(p, sid, args):
    """User-typed /router:approve [<id> [deny]] → the decision file the worker's hook waits for. Returns the block
    reason, shown to the user only. The decision is written here and nowhere else (no registry.py command)."""
    if (registry.load(p).get("front") or {}).get("session_id") != sid:
        return "router: not sent. /router:approve works only in the router front session (type /router:front there)."
    open_ = registry.pending(p)
    listing = "\n".join(line for r in open_ for line in registry.approval_lines(r)) or "(none)"
    a = args.split()
    if not a:
        return "router: open approval requests:\n" + listing
    if len(a) > 2 or a[1:] not in ([], ["deny"]) or not re.fullmatch(r"[0-9a-f]{8}", a[0]):
        return "router: not sent. Usage: /router:approve <id> [deny]. Open requests:\n" + listing
    r = next((r for r in open_ if r["nonce"] == a[0]), None)
    if not r:
        return f"router: not sent. No open request {a[0]} (answered, expired or unknown). Open requests:\n" + listing
    behavior = "deny" if a[1:] else "allow"
    registry.save(registry.approvals(p) / "decisions" / f"{a[0]}.json",
                  {"nonce": a[0], "behavior": behavior, "created": time.time(), "by": sid})
    return f"router: {'approved' if behavior == 'allow' else 'denied'} {a[0]}: {registry.describe(r)}"


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
