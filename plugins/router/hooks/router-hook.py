#!/usr/bin/env python3
"""router hooks — silent exit 0 unless this session has a router role.

UserPromptExpansion of a user-typed /router:front (command_name router:front, command_source plugin) → this
  session becomes the front: session_id, name (its `claude agents` entry) and permission_mode from the hook input.
  Only a typed command expands (a model Skill call or a cross-session message does not), so the front is
  human-registered; registry.py has no CLI for it.
UserPromptExpansion of a user-typed /router:approve [<id> [deny]] (same rule) → only in the front: write the decision
  for that open request (and a record the front's context lists for 10 min), then block the prompt with what was
  approved (no model turn). Bare → list open requests.
UserPromptSubmit: only in the front session (session_id == registry front) → record its permission_mode (the mode
  every worker gets) and add additionalContext with the compact registry.
Stop: only in a worker (session_id, or $CLAUDE_JOB_DIR's job id, is in the registry) → store
  last_assistant_message as last_result.
PermissionRequest: only in a worker → approvals/pending/<nonce>.json (the exact tool_input), then wait for the decision
  a user-typed /router:approve writes in the front; answer allow/deny only. No decision in time → no output, so the
  normal prompt stays (claude attach); a subagent's request is kept as approvals/expired/<nonce>.json, which the front
  lists as waiting in claude attach (Claude Code shows a background subagent's prompt there only after the hook).
  Prompt answered in claude attach first (`claude agents`, the same thread's next request, or for a subagent the
  tool's result in its own transcript) → end, no output.
PreToolUse SendMessage: only in a worker → deny a recipient that is another live session (not the front, not a
  sibling; `name [ref]`, quotes and case normalized): a stale front name's "Did you mean" hint must not carry a
  report to an unrelated session.
A worker that sends, gets a decision or ends its turn is no longer WAITING: its recorded wait is cleared.
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

seconds = registry.seconds
WAIT = seconds("ROUTER_APPROVAL_WAIT", 300.0, 0)  # poll limit; 0 = off (README); well under the hook timeout (600)
TTL = 600  # the PermissionRequest timeout in hooks.json: an older file belongs to a hook that was killed
POLL = seconds("ROUTER_POLL_INTERVAL", 0.5, 0.01)  # between decision reads
CHECK = seconds("ROUTER_AGENTS_CHECK_INTERVAL", 3.0, 0.05)  # between `claude agents` looks (~0.3 s each)
REF = re.compile(r"(\s*\[[0-9A-Fa-f]+\])+\s*$")  # the ` [ref]` Claude Code appends to a name several sessions share

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


def address(to):
    """SendMessage's `to` as the name or id it reaches. Claude Code writes `name`, `@name`, `@"name with spaces"`
    and, when several live sessions share a name, `name [ref]` with a short hex ref (docs: cross-session messaging).
    The ref is not in `claude agents`, so it cannot be checked: dropped, the name decides."""
    t = REF.sub("", str(to).strip()).lstrip("@").strip()
    if len(t) > 1 and t[0] == t[-1] == '"':
        t = REF.sub("", t[1:-1]).strip()
    return t.casefold()  # matched only against other sessions (the deny side), so folding can only add refusals


def guard_send(p, sid, data):
    """A worker may message its front and its siblings, never another of the user's sessions. A report to a front
    that is gone gets "Did you mean <some other session>?", and a worker that followed it leaked the report there.
    Refused: a name or id of a live session (`claude agents`) that is not the front or a worker by id, so a name
    such a session shares with ours (a ref cannot say which), and an address that is empty once normalized. A
    worker's own subagent ids/names are no session and still pass."""
    reg = registry.load(p)
    name = registry.find_worker(reg, sid, job_id())
    if not name:
        return
    registry.unblock(p, name)  # it is sending (e.g. its report), so no prompt holds its turn: no stale WAITING
    front = reg.get("front") or {}
    raw = str((data.get("tool_input") or {}).get("to") or "")
    ours = {front.get("session_id"), *(s.get(k) for s in reg["sessions"].values() for k in ("session_id", "job_id"))}
    ours.discard(None)
    others = {x for a in registry.backend_agents() or [] if not {a.get("sessionId"), a.get("id")} & ours
              for k in ("name", "sessionId", "id") if a.get(k) for x in (str(a[k]).casefold(), address(a[k]))}
    to = address(raw)
    if to and to in others and to == address(front.get("name") or ""):
        # the front's name, but not on the registered front's session: it was relaunched or /clear-ed and not yet
        # re-registered (a stranger taking the name looks the same). Denied either way; the worker must not give up.
        why = (f"router: not sent. '{raw}' is your front's name, but that session is not registered as the front: the "
               "front has not re-registered yet (the user must type /router:front there), or another session took its "
               "name. Your result is saved via the Stop hook: end this turn with your summary, and keep reporting to "
               "the front on later turns. Message no other session.")
    elif not to or to in others:
        why = (f"router: '{raw}' is another session, not your front @{front.get('name')} or a sibling. Message no other "
               "session, not even one SendMessage suggests; if the front is unreachable, end your turn with the summary "
               "(the router records it).")
    else:
        return
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
    late = next((r for r in registry.expired(p) if r["nonce"] == a[0]), None)
    if not r and late:
        job = (registry.load(p)["sessions"].get(late.get("worker")) or {}).get("job_id") or "<job_id>"
        return (f"router: not sent. {a[0]} expired: the router no longer relays it and its prompt now waits in "
                f"claude attach {registry.clean(job, 64)} (answer it there). Open requests:\n" + listing)
    if not r and (registry.approvals(p) / "pending" / f"{a[0]}.json").exists():  # its hook waits, its prompt doesn't
        return (f"router: not sent. {a[0]} was already answered (e.g. via claude attach) or superseded by the same "
                "worker's next request; nothing approved. Open requests:\n" + listing)
    if not r:
        return f"router: not sent. No open request {a[0]} (answered, expired or unknown). Open requests:\n" + listing
    behavior, now = "deny" if a[1:] else "allow", time.time()
    registry.save(registry.approvals(p) / "decisions" / f"{a[0]}.json",
                  {"nonce": a[0], "behavior": behavior, "created": now, "by": sid})
    # what the front's context lists as recently decided (the blocked prompt never reaches its model); display only
    registry.save(registry.approvals(p) / "decided" / f"{a[0]}.json",
                  {"nonce": a[0], "behavior": behavior, "created": now, "what": registry.describe(r)})
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
    for f in [f for d in ("pending", "decisions", "decided", "expired") for f in a.glob(f"{d}/*.json")]:
        with contextlib.suppress(FileNotFoundError):
            if time.time() - f.stat().st_mtime > (registry.EXPIRED_TTL if f.parent.name == "expired" else TTL):
                f.unlink()
    nonce, t0 = secrets.token_hex(4), time.time()
    pend = a / "pending" / f"{nonce}.json"
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))  # a cancelled hook still removes its pending file
    aid = data.get("agent_id")  # set only inside a subagent: its prompts are a thread of their own
    rec = {"nonce": nonce, "worker": name, "session_id": sid, "job_id": job_id(), "tool_name": data.get("tool_name"),
           "tool_input": data.get("tool_input"), "created": t0, "expires": t0 + WAIT, "agent_id": aid}
    if aid and data.get("transcript_path") and re.fullmatch(r"[\w-]+", str(aid)):
        # the subagent's own transcript, <main transcript minus .jsonl>/subagents/agent-<agent_id>.jsonl (docs:
        # sub-agents; transcript_path is the main one here too, -p probe), and its size now: only growth is read
        t = pathlib.Path(data["transcript_path"]).with_suffix("") / "subagents" / f"agent-{aid}.jsonl"
        rec.update(transcript=str(t), size=t.stat().st_size if t.is_file() else 0)
    registry.save(pend, rec)
    check = t0
    try:
        while time.time() < t0 + WAIT:
            b = registry.take_decision(p, nonce, t0)
            if b:
                out = {"behavior": b}  # never updatedInput/updatedPermissions: this call, as shown
                if b == "deny":
                    out["message"] = (f"The user denied this in the router front (/router:approve {nonce} deny). "
                                      "Report this as blocked to the front (not done).")  # 7th live test: "완료"
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": out}}))
                registry.unblock(p, name)
                return
            # Answered elsewhere (claude attach): Claude Code does not stop this hook. End, no output, once this worker
            # was seen on the prompt (the first look may precede it) and then either is off it (`claude agents`) or
            # its thread asked again: a newer request (parallel calls: the next prompt within 0.6–4.3 s) means this
            # prompt was answered; the worker stays on a prompt, so `claude agents` cannot tell. A subagent's prompt
            # never shows there (the worker reads busy): its transcript tells instead, so `claude agents` is skipped.
            # ponytail: a main-thread approve typed between an attach answer and the next look or request still says
            # approved, and Claude Code ignores that late answer. Upgrade: answered() on the main transcript too.
            if rec.get("seen") and registry.superseded(rec, registry.requests(p)):
                return  # no output; the newer request's hook relays the prompt the worker is on now
            if aid:
                if registry.answered(rec):  # a stat per poll; read only when the file grew
                    return  # no output; the worker's own (main-thread) state is not this prompt's
            elif time.time() >= check:
                check = time.time() + CHECK
                on = registry.on_prompt(registry.backend_agents(), sid, job_id())
                if on and not rec.get("seen"):
                    registry.save(pend, rec | {"seen": True})  # lets the front hide it once answered elsewhere
                    rec["seen"] = True
                elif on is False and rec.get("seen"):
                    registry.unblock(p, name)
                    return  # no output: the prompt is already answered
            time.sleep(POLL)
        if aid and not registry.superseded(rec, registry.requests(p)):
            # no decision in time: only now does claude attach show a background subagent's prompt (7th live test),
            # so the front lists it as waiting there (registry.expired) until the subagent's transcript has the result
            registry.save(a / "expired" / f"{nonce}.json", rec)
    finally:
        pend.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never break the session over router bookkeeping
        print(f"router-hook: {e}", file=sys.stderr)
    sys.exit(0)
