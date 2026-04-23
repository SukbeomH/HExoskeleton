# Deviation Rules — Full Detail

**While executing tasks, you WILL discover work not in the plan.** This is normal.

Apply these rules automatically. Track all deviations for Summary documentation.

---

## RULE 1: Auto-fix Bugs

**Trigger:** Code doesn't work as intended

**Examples:**
- Wrong SQL query returning incorrect data
- Logic errors (inverted condition, off-by-one)
- Type errors, null pointer exceptions
- Broken validation
- Security vulnerabilities (SQL injection, XSS)
- Race conditions, deadlocks
- Memory leaks

**Process:**
1. Fix the bug inline
2. Add/update tests to prevent regression
3. Verify fix works
4. Continue task
5. Track: `[Rule 1 - Bug] {description}`

**No user permission needed.** Bugs must be fixed for correct operation.

---

## RULE 2: Auto-add Missing Critical Functionality

**Trigger:** Code is missing essential features for correctness, security, or basic operation

**Examples:**
- Missing error handling (no try/catch)
- No input validation
- Missing null/undefined checks
- No authentication on protected routes
- Missing authorization checks
- No CSRF protection
- No rate limiting on public APIs
- Missing database indexes

**Process:**
1. Add the missing functionality
2. Add tests for the new functionality
3. Verify it works
4. Continue task
5. Track: `[Rule 2 - Missing Critical] {description}`

**No user permission needed.** These are requirements for basic correctness.

---

## RULE 3: Auto-fix Blocking Issues

**Trigger:** Something prevents you from completing current task

**Examples:**
- Missing dependency
- Wrong types blocking compilation
- Broken import paths
- Missing environment variable
- Database connection config error
- Build configuration error
- Circular dependency

**Process:**
1. Fix the blocking issue
2. Verify task can now proceed
3. Continue task
4. Track: `[Rule 3 - Blocking] {description}`

**No user permission needed.** Can't complete task without fixing blocker.

---

## RULE 4: Ask About Architectural Changes

**Trigger:** Fix/addition requires significant structural modification

**Examples:**
- Adding new database table
- Major schema changes
- Introducing new service layer
- Switching libraries/frameworks
- Changing authentication approach
- Adding new infrastructure (queue, cache)
- Changing API contracts (breaking changes)

**Process:**
1. STOP current task
2. Return checkpoint with architectural decision
3. Include: what you found, proposed change, impact, alternatives
4. WAIT for user decision
5. Fresh agent continues with decision

**User decision required.** These changes affect system design.

---

## Rule Priority

1. **If Rule 4 applies** → STOP and return checkpoint
2. **If Rules 1-3 apply** → Fix automatically, track for Summary
3. **If unsure which rule** → Apply Rule 4 (return checkpoint)

**Edge case guidance:**
- "This validation is missing" → Rule 2 (security)
- "This crashes on null" → Rule 1 (bug)
- "Need to add table" → Rule 4 (architectural)
- "Need to add column" → Rule 1 or 2 (depends on context)

---

## Deviation Memory

### Prerequisites

- `.hxsk/memories/` directory structure must exist

### Purpose

Track deviation patterns across sessions. Before executing, check if similar tasks had deviations before. After deviations occur, store them for future sessions.

### Pre-Execution: Search Past Deviations

Before starting task execution, check for historical deviation patterns:

```
Grep(pattern: "deviation|{phase-plan}", path: ".hxsk/memories/deviation/", output_mode: "files_with_matches")
```

If results found, Read the matching files and review past deviations to anticipate similar issues.

### Post-Deviation: Store Each Deviation

After applying any deviation rule (Rules 1-4), persist it:

#### Deviation → A/B/C/D/E 카테고리 분류

| Rule | 기본 카테고리 | 저장 경로 |
|------|------|------|
| Rule 1 (Bug fix) | C (semantic) 또는 D (lifecycle) | `lessons-learned/C-state-sync` 또는 `lessons-learned/D-lifecycle` |
| Rule 2 (Missing Critical) | B (test) 또는 D (lifecycle) | `lessons-learned/B-test-quality` 또는 `lessons-learned/D-lifecycle` |
| Rule 3 (Blocking) | D (lifecycle) 또는 A (doc) | `lessons-learned/D-lifecycle` 또는 `lessons-learned/A-doc-drift` |
| Rule 4 (Architecture) | C (state sync) | `lessons-learned/C-state-sync` |

저장 시 타입 파라미터를 카테고리 경로로 지정:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Lesson {카테고리}: {description}" \
  "{deviation 상세: 무엇을 발견했고, 무엇을 수정했고, 왜}" \
  "lessons-learned,category-{A|B|C|D|E},{phase-plan}" \
  "lessons-learned/{카테고리 디렉토리}"   # 예: lessons-learned/B-test-quality
```

### Post-Execution: Store Execution Summary

After writing SUMMARY.md, store an execution summary memory for cross-session learning:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Plan {phase-plan} Summary" \
  "{tasks completed, deviations applied, verification results}" \
  "execution,{phase-plan}" \
  "execution-summary"
```

---

## Authentication Gates

When you encounter authentication errors during `type="auto"` task execution:

This is NOT a failure. Authentication gates are expected and normal.

**Authentication error indicators:**
- CLI returns: "Not authenticated", "Not logged in", "Unauthorized", "401", "403"
- API returns: "Authentication required", "Invalid API key"
- Command fails with: "Please run {tool} login" or "Set {ENV_VAR}"

**Authentication gate protocol:**
1. Recognize it's an auth gate — not a bug
2. STOP current task execution
3. Return checkpoint with type `human-action`
4. Provide exact authentication steps
5. Specify verification command

**Example:**
```
## CHECKPOINT REACHED

**Type:** human-action
**Plan:** 01-01
**Progress:** 1/3 tasks complete

### Current Task
**Task 2:** Deploy to Vercel
**Status:** blocked
**Blocked by:** Vercel CLI authentication required

### Checkpoint Details
**Automation attempted:** Ran `vercel --yes` to deploy
**Error:** "Not authenticated. Please run 'vercel login'"

**What you need to do:**
1. Run: `vercel login`
2. Complete browser authentication

**I'll verify after:** `vercel whoami` returns your account

### Awaiting
Type "done" when authenticated.
```
