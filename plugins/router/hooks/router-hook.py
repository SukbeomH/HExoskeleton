#!/usr/bin/env python3
"""router hooks — silent exit 0 unless this session has a router role.

UserPromptExpansion of a user-typed /router:front (command_name router:front, command_source plugin) → this
  session becomes the front: session_id, name (its `claude agents` entry) and permission_mode from the hook input.
  Only a typed command expands (a model Skill call or a cross-session message does not), so the front is
  human-registered; registry.py has no CLI for it.
UserPromptSubmit: only in the front session (session_id == registry front) → record its permission_mode (the mode
  every worker gets) and add additionalContext with the compact registry.
Stop: only in a worker (session_id, or $CLAUDE_JOB_DIR's job id, is in the registry) → store
  last_assistant_message as last_result. Anything else, including a missing registry: no output, no write.
"""

import json
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "scripts"))
import registry  # noqa: E402

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
        job = pathlib.Path(os.environ.get("CLAUDE_JOB_DIR", "")).name or None
        registry.record_result(p, sid, job, data.get("last_assistant_message") or "", data.get("agent_type"))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never break the session over router bookkeeping
        print(f"router-hook: {e}", file=sys.stderr)
    sys.exit(0)
