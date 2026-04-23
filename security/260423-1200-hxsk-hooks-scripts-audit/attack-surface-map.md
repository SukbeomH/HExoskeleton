# HXSK Attack Surface Map

---

## Entry Points

| Entry Point | Script | Input Vector | Risk |
|-------------|--------|--------------|------|
| `md-store-memory.sh $1 $2` | hooks/md-store-memory.sh | CLI args from AI | Grep injection, YAML injection |
| `md-recall-memory.sh $1` | hooks/md-recall-memory.sh | CLI args from AI | Grep option injection, path traversal |
| `prune-tick.sh` (auto-triggered) | scripts/prune-tick.sh | File: .prune-config | Shell code injection via source |
| `bash-guard.py` stdin | hooks/bash-guard.py | JSON stdin from Claude | Pattern bypass |
| `file-protect.py` stdin | hooks/file-protect.py | JSON stdin from Claude | Path traversal bypass |
| `stop-context-save.sh` | hooks/stop-context-save.sh | git log output | Information from git history |
| `bootstrap.sh` | scripts/bootstrap.sh | .bootstrap-version file | Version state manipulation |

---

## Data Flows

```
AI generates memory title/content
  └→ md-store-memory.sh $TITLE $CONTENT
      ├→ grep -li "title: \"$TITLE\"" (QUERY INJECTION RISK)
      ├→ yaml_safe() sanitizer (partial: only \n\r and ")
      └→ written to .hxsk/memories/{type}/{date}_{slug}.md

AI generates memory query
  └→ md-recall-memory.sh $QUERY
      ├→ xargs grep -li "$QUERY" (GREP OPTION INJECTION RISK)
      ├→ find "$MEMORIES_DIR" -name "*${related_ref}*" (PATH TRAVERSAL RISK)
      └→ returned to AI context

prune-tick.sh triggered
  └→ source .hxsk/.prune-config (SHELL CODE EXECUTION RISK)
      └→ bash prune-memories.sh --auto

stop-context-save.sh triggered
  └→ git log | heredoc → CURRENT.md (commit msg expansion)
  └→ md-store-memory.sh (memory stored with git metadata)

bootstrap.sh
  └→ .env.example → .env copy (unattended)
  └→ .bootstrap-version version state read
```

---

## Abuse Paths

1. **Grep Option Injection → File Read Outside memories/**
   - QUERY = `--include=*.sh -r /etc`
   - Result: grep searches system files instead of memories
   - Chain: AI-generated memory query → grep misuse

2. **related_ref Path Traversal → Find Scope Escape**  
   - Memory file contains: `related:\n  - ../../etc/passwd`
   - Result: `find $MEMORIES_DIR -name "*../../etc/passwd*"` silently fails (safe by luck, not design)

3. **.prune-config Shell Injection**
   - Attacker writes: `PRUNE_TICK_COOLDOWN=60; rm -rf $HXSK_DIR`
   - IF permission check fails (mode check bypass) → executed
   - Mitigation exists (owner+mode check) but requires testing

4. **bash-guard Bypass via Command Chaining**
   - `echo safe && rm -rf .hxsk` — only `echo safe` is pattern-checked
   - Wait, bash-guard checks the whole command string with re.search()
   - But multi-line commands split across newlines might not be caught

5. **Memory Information Disclosure**
   - session-summary memories store commit messages, branch names, file lists
   - No expiry enforcement (prune only enforces count, not age)
   - Old sensitive context could remain in memories for weeks
