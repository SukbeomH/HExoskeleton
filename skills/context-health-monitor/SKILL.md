---
name: context-health-monitor
description: "Detects context rot (3 failed attempts, a repeating approach, context usage above 60%) and dumps session state to .hxsk/STATE.md for recovery or a fresh session. Use when debugging keeps failing, work goes in circles, or the context window is filling up (컨텍스트 상태, 세션 덤프, 3-strike)."
allowed-tools:
- Read
- Write
- Grep
- Glob
- Bash
---

## Quick Reference
- **3-Strike Rule**: 동일 이슈 3회 실패 → STOP → STATE.md 저장 → fresh session 권장
- **Circular Detection**: 동일 접근 2회 반복 → 근본적 대안 제안 또는 일시 중단(`handoff` 스킬 → `.hxsk/SESSION_HANDOFF.md`)
- **Uncertainty**: 명확하지 않을 시 추측 금지 → `architecture-decision` 메모리 기록 후 사용자 확인
- **Context >60%**: 토큰 사용량 60% 초과 시 즉시 `/compact` 실행 (80% 자동 전)
- **Pattern Extraction**: 핵심 학습 시 PATTERNS.md 저장 (2KB/20개 이내 유지)

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
| Session length | Extended back-and-forth | Recommend pausing with the `handoff` skill (`/hxsk:handoff`) |

## Behavior Rules

### Rule 1: The 3-Strike Rule

If debugging the same issue fails 3 times:

1. **STOP** attempting fixes
2. **Document** in `.hxsk/STATE.md`:
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
4. **Or** recommend pausing (`/hxsk:handoff`, then a fresh session) for fresh perspective

### Rule 3: Uncertainty Logging

When uncertain about an approach:

1. **State** the uncertainty clearly
2. **Store** an `architecture-decision` memory (`bash ../memory-protocol/scripts/md-store-memory.sh "<title>" "<content>" "decision,uncertain" architecture-decision`):
   - The uncertain decision
   - Why it's uncertain
   - Alternatives considered
3. **Ask** user for guidance rather than guessing

### Rule 4: Proactive Compaction

When context window usage exceeds ~60%:

1. **Run** `/compact` before auto-compaction kicks in (~80%)
2. **If task is nearly done**: finish first, then compact
3. **If task is complex with much remaining work**: compact now to preserve budget
4. **If context is beyond recovery** (repeated compactions, degrading quality): use the `handoff` skill (`/hxsk:handoff`) and start fresh

## Pattern Memory

### Prerequisites

- `.hxsk/memories/` directory structure must exist

### Purpose

Detect recurring failure patterns across sessions. Store health events for trend analysis so systemic issues are surfaced early.

### On 3-Strike Trigger

Check if the same issue has recurred, then store the event:

```
Grep(pattern: "3-strike|{issue}", path: ".hxsk/memories/health-event/", output_mode: "files_with_matches")
```

```bash
bash ../memory-protocol/scripts/md-store-memory.sh \
  "3-Strike: {issue}" \
  "{approaches tried, errors seen, current hypothesis}" \
  "health,3-strike,{component}" \
  "health-event"
```

If the search reveals the same issue appeared before, flag it as a recurring problem in the state dump.

### On Circular Detection

Check if the same loop pattern was seen before, then store:

```
Grep(pattern: "circular|{approach}", path: ".hxsk/memories/health-event/", output_mode: "files_with_matches")
```

```bash
bash ../memory-protocol/scripts/md-store-memory.sh \
  "Circular: {approach}" \
  "{what repeated, why it looped}" \
  "health,circular,{component}" \
  "health-event"
```

### On Session Handoff

Persist session context for the next session:

```bash
bash ../memory-protocol/scripts/md-store-memory.sh \
  "Handoff: {reason}" \
  "{current state, recommendations for next session}" \
  "health,handoff" \
  "session-handoff"
```

### Proactive Check

When this skill activates, scan recent memory files for failure trends:

```
Glob(pattern: ".hxsk/memories/health-event/*.md")
```

Read the most recent files and review for clusters of `3-strike`, `circular`, or `blocked` keywords. If a trend is detected (2+ similar events), warn the user proactively before beginning work.

---

## State Dump Format

When triggered, append this section to `.hxsk/STATE.md` (hooks never rewrite STATE.md):

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

When valuable patterns are discovered during a session, extract to `.hxsk/PATTERNS.md`:

### What to Extract

| Category | Examples |
|----------|----------|
| Architecture | "jose > jsonwebtoken for Edge runtime" |
| Conventions | "API routes: src/app/api/{resource}/route.ts" |
| Gotchas | "httpOnly cookies require HTTPS even on localhost" |
| Integrations | "Stripe webhooks need raw body parser disabled" |

### Extraction Protocol

1. **During task completion**, identify reusable learnings
2. **Check current count**: `grep -c "^-" .hxsk/PATTERNS.md`
3. **If < 20 items**: Append new pattern
4. **If >= 20 items**: Replace oldest (least referenced) pattern
5. **Size check**: Keep under 2KB

```bash
# Check PATTERNS.md size
wc -c .hxsk/PATTERNS.md  # Should be < 2048
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
| CURRENT.md | 1KB | Session context (rewritten by the Stop hook) |
| STATE.md | — | Current position, blockers (curated) |
| SESSION_HANDOFF.md | ~1KB | Re-entry note (curated, `handoff` skill) |

### On Demand (Don't Read Routinely)

| File/Folder | Purpose |
|-------------|---------|
| VERIFICATION.md | Verification runs (dated sections) |
| memories/ | Searched with `../memory-protocol/scripts/md-recall-memory.sh` |
| reports/ | `write-report` output |

---

## Integration

This skill integrates with:
- `/compact` — Proactive context compaction (Rule 4)
- `handoff` skill (`/hxsk:handoff`) — commit, test, store a session-handoff memory and update `.hxsk/SESSION_HANDOFF.md` when pausing or when context is beyond recovery
- Resuming — on Claude Code the session-start hook injects `.hxsk/SESSION_HANDOFF.md` and `.hxsk/STATE.md`; in other harnesses read them first (the project `AGENTS.md` HXSK block says so)
- `PATTERNS.md` — Pattern extraction on session end
- 3-Strike Rule (Context Hygiene) — After 3 failed debug attempts: STOP, summarize to STATE.md (blocker under `## Blockers`), recommend fresh session

## Scripts

None. On Claude Code, the plugin's PreCompact hook (`pre-compact-save.sh`) backs up the `.hxsk/` state files and runs its `compact-context.sh` helper, which warns when PATTERNS.md exceeds 2KB / 20 items and prunes local-tier memories.

## Iron Laws
NO CONTINUE DEBUGGING WITHOUT STATE.md DUMP FIRST (After 3 failures)
NO REPEAT APPROACH WITHOUT ALTERNATIVE PROPOSAL OR PAUSE (handoff) FIRST (After 2 loops)
NO EXCEED 80% CONTEXT WITHOUT /compact FIRST (Trigger at 60%)
NO APPEND TO PATTERNS.md WITHOUT SIZE/COUNT CHECK FIRST (Max 2KB, 20 items)
NO GUESS SOLUTION WITHOUT USER GUIDANCE FIRST (When uncertain)
NO STORE MEMORY WITHOUT .hxsk/memories/ DIRECTORY FIRST
NO RECOMMEND FRESH SESSION WITHOUT DOCUMENTING STATE FIRST
NO COMPACT MID-FINISH WITHOUT COMPLETING TASK FIRST (If task is nearly done)
