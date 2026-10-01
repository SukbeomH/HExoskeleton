---
description: 'Use when PLAN.md exists after /plan and before /execute to validate
  6 dimensions: requirement coverage, task completeness, dependencies, key links,
  scope sanity, and verification derivation.'
name: plan-checker
trigger: 플랜 검증, 계획 점검, PLAN.md 검사, validate plan, check plan before execution, plan
  audit, pre-execution check, plan sanity check, check for blockers, dependency cycle
  check, verify task completeness, plan quality gate, PLAN.md audit, check plan scope,
  validate plan dependencies, find plan issues, plan validation, pre-flight plan check
---

## Quick Reference
- **Task 필수 요소**: 모든 task 는 `<files>`, `<action>`, `<verify>`, `<done>` 필수 (누락 시 Blocker)
- **의존성 검증**: 순환 참조, 존재하지 않는 참조, 미래 참조 금지 (Blocker)
- **스코프 임계**: Plan 당 Task 5 개 이상 또는 File 15 개 이상 시 Blocker, 4~10 개 시 Warning
- **상태 판정**: Blocker 0 개 + Warning 2 개 이내는 PASSED, 그 외는 ISSUES_FOUND
- **행동 지침**: Blocker 발견 시 즉시 중단, 수정 후 재검증 필수

## Validation Dimensions

### Dimension 1: Requirement Coverage

**Question:** Does every phase requirement have task(s) addressing it?

**Process:**
1. Extract phase goal from ROADMAP.md
2. Decompose goal into requirements (what must be true)
3. For each requirement, find covering task(s)
4. Flag requirements with no coverage

**Red flags:**
- Requirement has zero tasks addressing it
- Multiple requirements share one vague task ("implement auth" for login, logout, session)
- Requirement partially covered

**Example issue:**
```yaml
issue:
  dimension: requirement_coverage
  severity: blocker
  description: "AUTH-02 (logout) has no covering task"
  plan: "1-01"
  fix_hint: "Add task for logout endpoint"
```

---

### Dimension 2: Task Completeness

**Question:** Does every task have Files + Action + Verify + Done?

**Required by task type:**
| Type | Files | Action | Verify | Done |
|------|-------|--------|--------|------|
| `auto` | Required | Required | Required | Required |
| `checkpoint:*` | N/A | N/A | N/A | N/A |
| `tdd` | Required | Behavior + Implementation | Test commands | Expected outcomes |

**Red flags:**
- Missing `<verify>` — can't confirm completion
- Missing `<done>` — no acceptance criteria
- Vague `<action>` — "implement auth" instead of specific steps
- Empty `<files>` — what gets created?

**Example issue:**
```yaml
issue:
  dimension: task_completeness
  severity: blocker
  description: "Task 2 missing <verify> element"
  plan: "1-01"
  task: 2
  fix_hint: "Add verification command"
```

---

### Dimension 3: Dependency Correctness

**Question:** Are plan dependencies valid and acyclic?

**Process:**
1. Parse `depends_on` from each plan frontmatter
2. Build dependency graph
3. Check for cycles, missing references, future references

**Red flags:**
- Plan references non-existent plan
- Circular dependency (A → B → A)
- Future reference (plan 01 referencing plan 03's output)
- Wave assignment inconsistent with dependencies

**Dependency rules:**
- `depends_on: []` = Wave 1 (can run parallel)
- `depends_on: ["01"]` = Wave 2 minimum
- Wave number = max(deps) + 1

**Example issue:**
```yaml
issue:
  dimension: dependency_correctness
  severity: blocker
  description: "Circular dependency between plans 02 and 03"
  plans: ["02", "03"]
  fix_hint: "Break cycle by reordering tasks"
```

---

### Dimension 4: Key Links Planned

**Question:** Are artifacts wired together, not just created in isolation?

**Red flags:**
- Component created but not imported anywhere
- API route created but component doesn't call it
- Database model created but API doesn't query it
- Form created but submit handler is stub

**What to check:**
```
Component → API: Does action mention fetch call?
API → Database: Does action mention Prisma/query?
Form → Handler: Does action mention onSubmit implementation?
State → Render: Does action mention displaying state?
```

**Example issue:**
```yaml
issue:
  dimension: key_links_planned
  severity: warning
  description: "Chat.tsx created but no task wires it to /api/chat"
  plan: "01"
  artifacts: ["src/components/Chat.tsx", "src/app/api/chat/route.ts"]
  fix_hint: "Add fetch call in Chat.tsx action"
```

---

### Dimension 5: Scope Sanity

**Question:** Will plans complete within context budget?

**Thresholds:**
| Metric | Target | Warning | Blocker |
|--------|--------|---------|---------|
| Tasks/plan | 2-3 | 4 | 5+ |
| Files/plan | 5-8 | 10 | 15+ |
| Context | ~50% | ~70% | 80%+ |

**Red flags:**
- Plan with 5+ tasks (quality degrades)
- Plan with 15+ file modifications
- Single task with 10+ files
- Complex work crammed into one plan

**Example issue:**
```yaml
issue:
  dimension: scope_sanity
  severity: warning
  description: "Plan 01 has 5 tasks - split recommended"
  plan: "01"
  metrics:
    tasks: 5
    files: 12
  fix_hint: "Split into 2 plans"
```

---

### Dimension 6: Verification Derivation

**Question:** Are must-haves derived from phase goal, not invented?

**Process:**
1. Extract phase goal
2. Check that each must-have traces to goal
3. Flag must-haves that don't contribute to goal

**Red flags:**
- Must-have unrelated to phase goal
- Missing must-haves for obvious requirements
- Over-specified must-haves (implementation details, not outcomes)

---

## Checking Process

### Step 1: Load Context
```
Read:
- .hxsk/ROADMAP.md (phase goals)
- .hxsk/REQUIREMENTS.md (if exists)
- .hxsk/phases/{N}/*-PLAN.md (all plans)
```

### Step 2: Parse Plans
```
For each PLAN.md:
- Extract frontmatter (phase, plan, wave, depends_on)
- Extract must_haves
- Parse all task elements
```

### Step 3: Check Each Dimension
Run all 6 dimension checks, collect issues.

### Step 4: Determine Status

**PASSED:** No blockers, 0-2 warnings
**ISSUES_FOUND:** Any blockers, or 3+ warnings

### Step 5: Output Results

---

## Output Formats

### VERIFICATION PASSED
```
## Plan Check Passed ✓

**Phase:** {N}
**Plans checked:** {count}
**Status:** PASSED

No blocking issues found.

Warnings (optional):
- {minor warning}
```

### ISSUES FOUND
```
## Plan Check Failed ✗

**Phase:** {N}
**Plans checked:** {count}
**Status:** ISSUES_FOUND

### Blockers
{issues with severity: blocker}

### Warnings
{issues with severity: warning}

### Recommended Fixes
1. {fix for issue 1}
2. {fix for issue 2}
```

---

## Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| blocker | Will cause execution failure | Must fix before /execute |
| warning | Quality/efficiency risk | Should fix, can proceed |
| info | Observation | No action needed |

---

## Issue Format

```yaml
issue:
  dimension: {which of 6 dimensions}
  severity: {blocker | warning | info}
  description: "{human-readable description}"
  plan: "{plan id}"
  task: {task number, if applicable}
  fix_hint: "{suggested fix}"
```

---

## When to Run

- After `/plan` completes
- Before `/execute` starts
- After plan modifications

Plan checker is the quality gate between planning and execution.

## 네이티브 도구 활용

PLAN.md 검증은 네이티브 도구로 수행:

```
# YAML frontmatter 확인
Read(file_path: ".hxsk/phases/{N}/{M}-PLAN.md") → frontmatter 파싱

# 필수 섹션 존재 확인
Grep(pattern: "^## (Objective|Tasks|Verification)", path: ".hxsk/phases/", output_mode: "content")

# Task XML 구조 검증
Grep(pattern: "<task id=.*>|<files>|<action>|<verify>|<done>", path: ".hxsk/phases/", output_mode: "content")
```

## Iron Laws
NO EXECUTE WITHOUT PLAN_CHECK_FIRST
NO MUST-HAVE WITHOUT GOAL_DERIVATION_FIRST
NO TASK WITHOUT VERIFY_AND_DONE_FIRST
NO DEPENDENCY WITHOUT A-CYCLE_CHECK_FIRST
NO PLAN_WITHOUT_SCOPE_SANITY_FIRST
NO ARTIFACT_WITHOUT_WIRED_LINKS_FIRST
