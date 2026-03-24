# Hooks Index

> 17 hook scripts. Claude Code only -- other agents use AGENTS.md rules instead.

| Hook | Event | Purpose | File |
|------|-------|---------|------|
| file-protect.py | PreToolUse (Edit/Write/Read) | Block sensitive file access | `hooks/file-protect.py` |
| bash-guard.py | PreToolUse (Bash) | Block destructive commands | `hooks/bash-guard.py` |
| session-start.sh | SessionStart | Load state, memory, context | `hooks/session-start.sh` |
| auto-format.sh | PostToolUse (Edit/Write) | Auto-format edited files | `hooks/auto-format.sh` |
| track-modifications.sh | PostToolUse (Edit/Write/Bash) | Track file modifications | `hooks/track-modifications.sh` |
| pre-compact-save.sh | PreCompact | Backup state before compaction | `hooks/pre-compact-save.sh` |
| post-turn-verify.sh | Stop | Code quality check | `hooks/post-turn-verify.sh` |
| stop-context-save.sh | Stop | Save session context + memory | `hooks/stop-context-save.sh` |
| save-transcript.sh | SessionEnd | Archive session transcript | `hooks/save-transcript.sh` |
| save-session-changes.sh | SessionEnd | Log changes to CHANGELOG | `hooks/save-session-changes.sh` |
| compact-context.sh | (utility) | Context rotation/pruning | `hooks/compact-context.sh` |
| organize-docs.sh | (utility) | Document organization | `hooks/organize-docs.sh` |
| md-store-memory.sh | (utility) | Store memory (A-Mem) | `hooks/md-store-memory.sh` |
| md-recall-memory.sh | (utility) | Recall memory (2-hop) | `hooks/md-recall-memory.sh` |
| scaffold-hxsk.sh | (utility) | Scaffold HXSK documents | `hooks/scaffold-hxsk.sh` |
| scaffold-infra.sh | (utility) | Compare infra files | `hooks/scaffold-infra.sh` |
| _json_parse.sh | (library) | JSON parse abstraction | `hooks/_json_parse.sh` |
