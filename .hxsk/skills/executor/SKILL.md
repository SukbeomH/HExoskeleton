---
allowed-tools:
- Read
- Write
- Edit
- Bash
- Grep
- Glob
description: Use when a PLAN.md file exists and requires execution to implement tasks
  atomically with commits.
name: executor
trigger: 플랜 실행, 계획 실행, PLAN.md 실행, execute plan, start implementation, PLAN.md 실행하기,
  plan execute, run plan, implement plan, task 실행, atomic execution, plan carry out,
  작업 시작, plan run, execute tasks, commit tasks, start plan execution, plan 구현
---

## Quick Reference
- **Deviation Judgment**: Rule 1-3(버그/기능/차단)은 자동 수정, Rule 4(아키텍처) 또는 불변 조건 위반 시 즉시 중단
- **Checkpoint Protocol**: 지정된 체크포인트 도달 시 즉시 STOP, 인간의 검증/결정/행동 요청
- **Commit Discipline**: 각 Task 완료 시 1 commit 원칙 준수 (`feat({phase}-{plan}): {task}`)
- **Output Generation**: Plan 완료 시 SUMMARY.md 생성 및 Execution Memory 저장 필수
- **Cross-Phase Safety**: 이전 Phase 불변 조건 위반 감지 시 즉시 Rule 4 적용

## Execution Flow

| Step | Action | Detail |
|------|--------|--------|
| 1 | Load Project State | `cat .hxsk/STATE.md` — parse phase/plan/status |
| 2 | Load Plan | Parse frontmatter, objective, tasks, success criteria |
| 3 | Determine Pattern | A=autonomous, B=checkpoints, C=continuation, D=parallel wave |
| 4 | Execute Tasks | auto→work+verify+commit; checkpoint→STOP |
| 5 | Handle Deviations | Rule 1-3=auto-fix; Rule 4=checkpoint |
| 6 | Commit Tasks | One task = one commit (see commit protocol) |
| 7 | Create SUMMARY.md | `.hxsk/phases/{N}/{plan}-SUMMARY.md` |
| 8 | Store Memory | `md-store-memory.sh` execution-summary |

**상세 흐름** → `references/execution-flow.md`

---

## Cross-Phase Invariants 파싱

`cross_phase_invariants.inherit + new` 필드를 읽어 내재화.
실행 중 코드/로직이 이 조건을 위반하면 → **즉시 Rule 4 (아키텍처 체크포인트) 적용**.

위반 신호:
- 이전 phase 테스트가 현재 코드에서 실패
- 명시된 불변 조건과 반대되는 로직 추가
- semantic 제약 (e.g. "status=='Y' ⟺ state ∈ {...}") 파괴

---

## Deviation Rules

| Rule | Trigger | Action |
|------|---------|--------|
| **Rule 1** | Bug / wrong behavior | Auto-fix + track |
| **Rule 2** | Missing critical functionality | Auto-add + track |
| **Rule 3** | Blocking issue | Auto-fix blocker + continue |
| **Rule 4** | Architectural change needed | STOP → checkpoint |

Priority: Rule 4 first. If unsure → Rule 4.

**상세 규칙 + Deviation Memory + Authentication Gates** → `references/deviation-rules.md`

---

## Checkpoint Protocol

Types: `human-verify` (90%) · `decision` (9%) · `human-action` (1%)

When checkpoint hit: **STOP immediately.** Return structured message.

**Return format + Continuation Handling** → `references/checkpoint-protocol.md`

---

## Task Commit & Output

```bash
git add -A && git commit -m "feat({phase}-{plan}): {task}"
```

SUMMARY.md → `.hxsk/phases/{N}/{plan}-SUMMARY.md`
Memory → `md-store-memory.sh "Plan {phase}-{plan} Summary" ...`

**전체 프로토콜 (Phase Checkpoint, PRD Update, SUMMARY format, Anti-Patterns, 관련스킬, 네이티브도구)** → `references/commit-protocol.md`

## Iron Laws
NO EXECUTION WITHOUT STATE AND PLAN LOADING FIRST
NO ARCHITECTURAL CHANGE WITHOUT CHECKPOINT FIRST
NO TASK COMPLETION WITHOUT ATOMIC COMMIT FIRST
NO CONTINUATION WITHOUT CHECKPOINT HANDLING FIRST
NO CODE LOGIC VIOLATION WITHOUT ARCHITECTURAL CHECKPOINT FIRST
NO SUMMARY GENERATION WITHOUT TASK EXECUTION FIRST
