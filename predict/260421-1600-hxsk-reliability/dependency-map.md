# HXSK Reliability Predict — Dependency Map

**Session**: 260421-1600-hxsk-reliability

---

## Hook Call Chain

```
Claude Code Events
├── SessionStart → bootstrap.sh (mode check)
│   └── .bootstrap-version → MODE: fresh / verify / upgrade
├── PreToolUse → check-consistency.sh (validation)
│   └── settings.json hooks count, placeholder check
├── PostToolUse → stop-context-save.sh (incremental save)
│   └── .modified-this-session flag
│   └── md-store-memory.sh → TYPE_DIR → memories/
├── PreCompact → pre-compact-save.sh (context save)
│   └── python3 (JSON output) → additionalContext
├── Stop / SubagentStop → stop-context-save.sh
│   └── background subshell → summary generation
└── SessionEnd → md-store-memory.sh (session memory)

Opportunistic (triggered from md-store/recall/bootstrap)
└── prune-tick.sh (lock: .hxsk/.prune-lock/)
    └── prune-memories.sh (config: .hxsk/.prune-config.sh)
```

---

## Data Flow: Memory Write

```
agent call
  → md-store-memory.sh "$TITLE" "$BODY" "$TAGS" "$TYPE"
      → PROJ="${CLAUDE_PROJECT_DIR:-.}"
      → MEMORIES_DIR="$PROJ/.hxsk/memories"
      → TYPE_DIR="$MEMORIES_DIR/$TYPE"
      [BUG] if TYPE_DIR missing → redirect to general (no warning)
      → write frontmatter + body to $TYPE_DIR/$SLUG.md
      → update tag index
      → [opportunistic] prune-tick.sh
```

---

## Data Flow: Memory Recall

```
agent call
  → md-recall-memory.sh "$QUERY" "$BASE" "$MAX" "$FORMAT"
      → PROJ="${CLAUDE_PROJECT_DIR:-.}"
      → find $PROJ/.hxsk/memories -name "*.md" | sort -r | head -100
      [BUG] head -100 hard cap
      → grep -li "$QUERY" → matched_files
      [BUG] if empty → fallback to most-recent N files (no [NO_MATCH])
      → 2-hop: extract related field from matched → re-search
      [BUG] sed end pattern may trigger early
      → output by FORMAT: compact / full / list
```

---

## Shared State (경쟁 조건 위험)

| 공유 자원 | 접근자 | 동기화 메커니즘 |
|---------|--------|----------------|
| `.hxsk/.prune-lock/` | prune-tick.sh | mkdir + trap EXIT (SIGKILL 취약) |
| `.hxsk/memories/*` | store + recall + prune | 없음 (단일 에이전트 가정) |
| `.modified-this-session` | stop-context-save.sh | 없음 (삭제 경쟁 가능) |
| `.hxsk/.bootstrap-version` | bootstrap.sh + prune | 없음 |
