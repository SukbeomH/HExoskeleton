---
name: context-health-monitor
description: Monitors context complexity and triggers state dumps before quality degrades
allowed-tools:
  - memory_store
  - memory_search
  - memory_list
---

# Context Health Monitor

## Purpose

Prevent "Context Rot" — the quality degradation that occurs as the agent processes more information in a single session.

## When This Skill Activates

The agent should self-monitor for these warning signs:

### Warning Signs

| Signal | Threshold | Action |
|--------|-----------|--------|
| Repeated debugging | 3+ failed attempts | Trigger state dump |
| Going in circles | Same approach tried twice | Stop and reassess |
| Confusion indicators | "I'm not sure", backtracking | Document uncertainty |
| Context window filling | >60% token usage | Run `/compact` proactively |
| Session length | Extended back-and-forth | Recommend `/pause` or `/handoff` |

## Behavior Rules

### Rule 1: The 3-Strike Rule

If debugging the same issue fails 3 times:

1. **STOP** attempting fixes
2. **Document** in `.gsd/STATE.md`:
   - What was tried
   - What errors occurred
   - Current hypothesis
3. **Recommend** user start fresh session
4. **Do NOT** continue with more attempts

### Rule 2: Circular Detection

If the same approach is being tried again:

1. **Acknowledge** the repetition
2. **List** what has already been tried
3. **Propose** a fundamentally different approach
4. **Or** recommend `/pause` for fresh perspective

### Rule 3: Uncertainty Logging

When uncertain about an approach:

1. **State** the uncertainty clearly
2. **Document** in `.gsd/DECISIONS.md`:
   - The uncertain decision
   - Why it's uncertain
   - Alternatives considered
3. **Ask** user for guidance rather than guessing

### Rule 4: Proactive Compaction

When context window usage exceeds ~60%:

1. **Run** `/compact` before auto-compaction kicks in (~80%)
2. **If task is nearly done**: finish first, then compact
3. **If task is complex with much remaining work**: compact now to preserve budget
4. **If context is beyond recovery** (repeated compactions, degrading quality): use `/handoff` and start fresh

## Pattern Memory

### Prerequisites

- mcp-memory-service MCP server must be configured in `.mcp.json`

### Purpose

Detect recurring failure patterns across sessions. Store health events for trend analysis so systemic issues are surfaced early.

### On 3-Strike Trigger

Check if the same issue has recurred, then store the event:

```
memory_search(query: "3-strike {issue}", tags: ["3-strike"])
```

```
memory_store(
  content: "## 3-Strike: {issue}\n\n{approaches tried, errors seen, current hypothesis}",
  metadata: {
    tags: "health,3-strike,{component}",
    type: "health-event"
  }
)
```

If the search reveals the same issue appeared before, flag it as a recurring problem in the state dump.

### On Circular Detection

Check if the same loop pattern was seen before, then store:

```
memory_search(query: "circular {approach}", tags: ["circular"])
```

```
memory_store(
  content: "## Circular: {approach}\n\n{what repeated, why it looped}",
  metadata: {
    tags: "health,circular,{component}",
    type: "health-event"
  }
)
```

### On Session Handoff

Persist session context for the next session:

```
memory_store(
  content: "## Handoff: {reason}\n\n{current state, recommendations for next session}",
  metadata: {
    tags: "health,handoff",
    type: "session-handoff"
  }
)
```

### Proactive Check

When this skill activates, scan recent memory activity for failure trends:

```
memory_list(page: 1, page_size: 10)
```

Review the results for clusters of `3-strike`, `circular`, or `blocked` tags. If a trend is detected (2+ similar events), warn the user proactively before beginning work.

---

## State Dump Format

When triggered, write to `.gsd/STATE.md`:

```markdown
## Context Health: State Dump

**Triggered**: [date/time]
**Reason**: [3 failures / circular / uncertainty]

### What Was Attempted
1. [Approach 1] — Result: [outcome]
2. [Approach 2] — Result: [outcome]
3. [Approach 3] — Result: [outcome]

### Current Hypothesis
[Best guess at root cause]

### Recommended Next Steps
1. [Fresh perspective action]
2. [Alternative approach to try]

### Files Involved
- [file1.ext] — [what state it's in]
- [file2.ext] — [what state it's in]
```

## Pattern Extraction

When valuable patterns are discovered during a session, extract to `.gsd/PATTERNS.md`:

### What to Extract

| Category | Examples |
|----------|----------|
| Architecture | "jose > jsonwebtoken for Edge runtime" |
| Conventions | "API routes: src/app/api/{resource}/route.ts" |
| Gotchas | "httpOnly cookies require HTTPS even on localhost" |
| Integrations | "Stripe webhooks need raw body parser disabled" |

### Extraction Protocol

1. **During task completion**, identify reusable learnings
2. **Check current count**: `grep -c "^-" .gsd/PATTERNS.md`
3. **If < 20 items**: Append new pattern
4. **If >= 20 items**: Replace oldest (least referenced) pattern
5. **Size check**: Keep under 2KB

```bash
# Check PATTERNS.md size
wc -c .gsd/PATTERNS.md  # Should be < 2048
```

### Pattern Format

```markdown
## {Category}
- {Concise pattern description} — {file:line if applicable}
```

---

## Context File Management

### Active Layer (Read Every Session)

| File | Size Limit | Purpose |
|------|------------|---------|
| PATTERNS.md | 2KB | Core learnings |
| CURRENT.md | 1KB | Session context |
| prd-active.json | 3KB | Pending tasks |

### Archive Layer (Don't Read Routinely)

| File/Folder | Purpose |
|-------------|---------|
| JOURNAL.md | Session history |
| CHANGELOG.md | Change history |
| prd-done.json | Completed tasks |
| reports/ | Analysis reports |
| research/ | Research docs |
| archive/ | Monthly archives |

---

## Integration

This skill integrates with:
- `/compact` — Proactive context compaction (Rule 4)
- `/handoff` — Lightweight session transfer when context is beyond recovery
- `/pause` — Full GSD session handoff with state archival
- `/resume` — Loads the state dump context
- `PATTERNS.md` — Pattern extraction on session end
- `.gemini/GEMINI.md` Rule 3 (Context Hygiene) — After 3 failed debug attempts: STOP, summarize to STATE.md, document blocker in DECISIONS.md, recommend fresh session

## Scripts

- `scripts/dump_state.sh`: Dump current context state to .gsd/STATE.md with git info, task status, and recommendations
- `scripts/compact-context.sh`: Archive old entries, prune PATTERNS.md to 2KB limit
