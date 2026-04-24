---
description: Use when SPEC.md exists and you must decompose phase goals into exactly
  2-3 tasks with specific file paths, actions, and verification criteria before execution.
name: planner
trigger: 플랜 작성, 계획 수립, 태스크 분해, create plan, break down tasks, make PLAN.md, goal-backward
  분석, 목표 역추적, wave 구조화, 파동 계획, 병렬 태스크 구성, discovery level 평가, 발견 수준 판단, L0~L3 평가,
  gap closure, 공백 메우기, gap plan 생성, checkpoint 도달, 휴먼 검증 요청, decision 포인트, human-action
  필요, must-haves 도출, 필수 조건 추출, phase plan 생성, 실행 계획 수립, dependency graph, 의존성 그래프,
  task sizing, 태스크 크기 조정, plan.md 템플릿 생성, invariant 확인, 불변 조건 검증, pre-planning 수행,
  SPEC.md 플레이스홀더 확인, lessons-learned 리콜, 과거 실행 결과 분석, task anatomy 검증, files 절대 경로
  지정, action avoid 명시, verify 명령어 생성, done 기준 측정 가능화, auto 태스크 자동화, checkpoint 타입
  결정, 휴먼 액션 필요성 판단, iron laws 준수 확인, 컨텍스트 예산 50% 체크, 네이티브 도구 활용, grep 패턴 검색, glob
  파일 검색, bash 리콜 스크립트 실행, 표준 모드 출력, gap closure 모드 출력, checkpoint 출력 형식, invariant
  위반 처리, 아키텍처 체크포인트 요청, TDD 적용 고려, cross_phase_inherit 복사, new invariant 추가, 파일 수정
  충돌 방지, 동일 wave 파일 분리, discovery level 키워드 기반 평가, auth security database api 검색,
  deviation 확인, manual checkpoint 방지, automation-first 규칙 적용, plan 구조 프론트매터 생성, user
  세팅 가이드, 의존성 그래프 시각화, 목표 역추적 anti-pattern 제거
---

## Quick Reference
- **Pre-Check**: SPEC.md 플레이스홀더 및 과거 교훈 (lessons-learned) 확인 필수
- **Plan 구조**: 2-3 tasks로 제한, Goal-Backward 유도, context budget 50% 도달 시 즉시 중단
- **Task 필수**: `<files>`(절대경로), `<action>`(Avoid 명시), `<verify>`(명령어), `<done>`(측정기준) 4필드 완비
- **Wave 규칙**: 동일 Wave 내 Plan들은 절대 같은 파일 수정 금지 (의존성 분리)
- **Checkpoint**: CLI/API 자동화 불가 시에만 `checkpoint` 사용, 그 외는 `auto` 우선

## Philosophy

**Solo Developer + AI**: One visionary (user) + one builder (AI). No team overhead.
**Plans Are Prompts**: PLAN.md IS the prompt. Contains objective, context, tasks, success criteria.
**Quality Curve**: 0-50% context = peak/good quality. Stop before 50% context.
**Ship Fast**: Plan → Execute → Ship → Learn. No enterprise theater.

---

## Pre-Planning (required before writing plans)

1. SPEC.md 플레이스홀더 확인
2. 과거 실행 결과 + lessons-learned recall

**상세** → `references/pre-planning.md`

---

## Discovery Protocol

| Level | When | Action |
|-------|------|--------|
| L0 | 기존 패턴만, 새 의존성 없음 | Skip |
| L1 | 단순 기능 추가 | Quick docs verify |
| L2 | 새 모듈/외부 통합 | Standard research |
| L3 | 아키텍처 결정 | Deep dive |

**상세 기준 + depth indicators** → `references/discovery-protocol.md`

---

## Task Anatomy

Every task has four required fields:

### `<files>`
Exact file paths created or modified.
- ✅ `src/app/api/auth/login/route.ts`
- ❌ "the auth files", "relevant components"

### `<action>`
Specific instructions including what to avoid and WHY.
- ✅ "Create POST endpoint accepting {email, password}, validates using bcrypt... AVOID: jsonwebtoken (CommonJS issues with Edge runtime)"
- ❌ "Add authentication"

### `<verify>`
Executable command to prove completion.
- ✅ `npm test` passes, `curl -X POST /api/auth/login` returns 200
- ❌ "It works"

### `<done>`
Measurable acceptance criteria.
- ✅ "Valid credentials return 200 + JWT cookie, invalid → 401"
- ❌ "Authentication is complete"

---

## Task Types

| Type | Use For | Autonomy |
|------|---------|----------|
| `auto` | Everything AI can do | Fully autonomous |
| `checkpoint:human-verify` | Visual/functional check | Pauses for user |
| `checkpoint:decision` | Implementation choices | Pauses for user |
| `checkpoint:human-action` | Unavoidable manual steps | Pauses for user |

**Automation-first rule:** If AI CAN do it via CLI/API, AI MUST do it. Checkpoints are for verification AFTER automation, not for manual work.

---

## Task & Plan Sizing

- Small: <10% budget, 1-2 files | Medium: 10-20%, 3-5 files | Large: SPLIT
- Plans: 2-3 tasks max
- Same-wave plans: MUST NOT modify same files

**상세 + Estimating table** → `references/task-sizing.md`

---

## PLAN.md Structure + Dependencies

**전체 PLAN.md 템플릿 + Frontmatter + User Setup + Dependency Graph + TDD** → `references/plan-structure.md`

**Goal-backward Methodology + Anti-patterns** → `references/goal-backward.md`

---

## Output Formats

### Standard Mode
```
PLANS_CREATED: {N}
WAVE_STRUCTURE:
  Wave 1: [plan-1, plan-2]
  Wave 2: [plan-3]
FILES: [list of PLAN.md paths]
```

### Gap Closure Mode
```
GAP_PLANS_CREATED: {N}
GAPS_ADDRESSED: [gap-ids]
FILES: [list of gap PLAN.md paths]
```

### Checkpoint Reached
```
CHECKPOINT: {type}
QUESTION: {what needs user input}
OPTIONS: [choices if applicable]
```

---

## Checklist Before Submitting Plans

- [ ] Each plan has 2-3 tasks max
- [ ] All files are specific paths, not descriptions
- [ ] All actions include what to avoid and why
- [ ] All verify steps are executable commands
- [ ] All done criteria are measurable
- [ ] Wave assignments reflect dependencies
- [ ] Same-wave plans don't modify same files
- [ ] Must-haves are derived from phase goal
- [ ] Discovery level assessed (0-3)
- [ ] TDD considered for complex logic
- [ ] cross_phase_invariants.inherit: 직전 plan의 (inherit + new) 복사
- [ ] cross_phase_invariants.new: 이번 phase에서 추가되는 불변 조건 명시
- [ ] invariant 위반 시 Rule 4 (아키텍처 체크포인트) 적용 명시

---

## 네이티브 도구 활용

PLAN.md 분석과 Discovery Level 평가는 네이티브 도구로 수행:

```
# Discovery Level 평가 (키워드 기반)
Grep(pattern: "auth|security|database|api", path: "src/", output_mode: "count")

# 기존 PLAN.md 검색
Glob(pattern: ".hxsk/phases/*/*.md")

# 과거 플랜 deviation 확인
bash .hxsk/hooks/md-recall-memory.sh "deviation" "." 5 compact
```

## Iron Laws
NO PLAN WITHOUT 2-3 TASKS MAX FIRST
NO PLAN WITHOUT 50% CONTEXT BUDGET FIRST
NO TASK WITHOUT EXACT FILE PATHS FIRST
NO TASK WITHOUT <FILES>, <ACTION>, <VERIFY>, <DONE> FIRST
NO SAME-WAVE PLANS WITHOUT DIFFERENT FILE MODIFICATIONS FIRST
NO PLAN WITHOUT SPEC.md CHECK FIRST
NO PLAN WITHOUT LESSONS-LEARNED RECALL FIRST
NO PLAN WITHOUT GOAL-BACKWARD DERIVATION FIRST
NO MANUAL CHECKPOINT WITHOUT AUTOMATION IMPOSSIBILITY FIRST
NO PLAN WITHOUT DISCOVERY LEVEL ASSESSMENT FIRST
NO PLAN WITHOUT INHERITED INVARIANTS FIRST
NO PLAN WITHOUT INARIANT VIOLATION HANDLING FIRST
NO COMPLEX LOGIC WITHOUT TDD CONSIDERATION FIRST
NO DISCOVERY ASSESSMENT WITHOUT NATIVE TOOLS FIRST
NO TASK ACTION WITHOUT EXPLICIT AVOIDANCE FIRST
