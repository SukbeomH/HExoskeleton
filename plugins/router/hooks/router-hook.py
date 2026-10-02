#!/usr/bin/env python3
"""router hooks — silent exit 0 unless this session has a router role.

UserPromptSubmit: only in the front session (session_id == registry front) → additionalContext
  with the compact registry and the front's permission mode.
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
    "request) instead of doing topic work here. Spawn workers with --permission-mode {mode}."
)


def main():
    data = json.load(sys.stdin)
    p = registry.path()
    sid = data.get("session_id")
    if p is None or not sid or not p.exists():
        return
    event = data.get("hook_event_name")
    if event == "UserPromptSubmit":
        reg = registry.load(p)
        if (reg.get("front") or {}).get("session_id") != sid:
            return
        ctx = registry.render(reg) + "\n" + HINT.format(mode=data.get("permission_mode") or "default")
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
