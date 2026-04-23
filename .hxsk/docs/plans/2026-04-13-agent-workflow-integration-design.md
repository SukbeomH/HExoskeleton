# Agent Workflow Integration — 설계 문서

> **날짜**: 2026-04-13
> **원본 템플릿**: 로컬 홈 디렉토리의 `agent-workflow-template.md` 기반
> **상태**: 구현 완료 (2026-04-23)

---

## 목차

1. [개요 및 목적](#1-개요-및-목적)
2. [범위 및 통합 대상](#2-범위-및-통합-대상)
3. [컴포넌트 1 — LESSONS-LEARNED 메모리 타입](#3-컴포넌트-1--lessons-learned-메모리-타입)
4. [컴포넌트 2 — Cross-Phase Invariants (PLAN.md 확장)](#4-컴포넌트-2--cross-phase-invariants-planmd-확장)
5. [컴포넌트 3 — Pre-PR Self-Check A/B/C/D/E](#5-컴포넌트-3--pre-pr-self-check-abcde)
6. [컴포넌트 4 — Subagent Dispatch Prompt 개선](#6-컴포넌트-4--subagent-dispatch-prompt-개선)
7. [전체 워크플로우 연결](#7-전체-워크플로우-연결)
8. [변경 파일 요약](#8-변경-파일-요약)
9. [5 카테고리 참조 (A-E)](#9-5-카테고리-참조-a-e)

---

## 1. 개요 및 목적

**문제**: AI 에이전트 주도 개발에서 PR 리뷰가 같은 5개 카테고리에서 반복적으로 지적됨.

| 카테고리 | 증상 |
|---|---|
| **A.** 코드 ↔ 문서 drift | docstring/plan 불일치, stale 경로 |
| **B.** 테스트 품질 | mock-only 검증, resource close 누락 |
| **C.** 상태 동기화 / 의미론 | 단계 간 invariant 파괴, timing 오류 |
| **D.** Resource / Lifecycle | thread safety, cleanup 누락 |
| **E.** Forward-compat | 미사용 param, dead weight |

**해결 방향**: 기존 HXSK 시스템에 4개 컴포넌트를 Approach C(하이브리드)로 통합.
- 기존 `md-store-memory.sh` / `md-recall-memory.sh` 그대로 활용
- 새 스크립트 없음, 새 독립 스킬 없음
- 기존 5개 스킬 확장 + 디렉토리 구조 추가

---

## 2. 범위 및 통합 대상

### 수정 대상 스킬

| 스킬 파일 | 추가 내용 |
|---|---|
| [`skills/planner/SKILL.md`](../../skills/planner/SKILL.md) | cross_phase_invariants 작성 지침 + lessons-learned recall |
| [`skills/executor/SKILL.md`](../../skills/executor/SKILL.md) | deviation 시 A/B/C/D/E 분류 저장 |
| [`skills/create-pr/SKILL.md`](../../skills/create-pr/SKILL.md) | Pre-PR Self-Check 블록 (A-E) |
| [`skills/pr-review/SKILL.md`](../../skills/pr-review/SKILL.md) | 리뷰 후 A/B/C/D/E 분류 저장 |
| [`skills/dispatcher/SKILL.md`](../../skills/dispatcher/SKILL.md) | lessons recall + ambiguity log 강제 |

### 수정 대상 템플릿

| 파일 | 추가 내용 |
|---|---|
| [`templates/PLAN.md`](../../templates/PLAN.md) | `cross_phase_invariants` frontmatter 필드 |

### 신규 디렉토리 구조

```
.hxsk/memories/lessons-learned/   ← 신규
├── A-doc-drift/
├── B-test-quality/
├── C-state-sync/
├── D-lifecycle/
└── E-compat/
```

---

## 3. 컴포넌트 1 — LESSONS-LEARNED 메모리 타입

> **저장 위치**: [`memories/lessons-learned/`](../../memories/lessons-learned/)
> **사용 스크립트**: [`.hxsk/hooks/md-store-memory.sh`](../../hooks/md-store-memory.sh), [`.hxsk/hooks/md-recall-memory.sh`](../../hooks/md-recall-memory.sh)

### 메모리 파일 포맷

```markdown
---
category: B
pr: #126
severity: important   # critical / important / minor
tags: test,mock,e2e
---

패턴: E2E 없이 mock interaction만 검증

증상: test_foo()가 mock.assert_called() 통과했지만
      실제 경로에서 KeyError 발생

예방: <verify> 태스크에 real path command 포함 필수
```

### 저장 명령 (에이전트 사용)

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Lesson B: {패턴 제목}" \
  "{증상 + 예방 내용}" \
  "lessons-learned,category-B,pr-{N}" \
  "lessons-learned/B-test-quality"
```

서브디렉토리 매핑:

| 카테고리 | 저장 경로 |
|---|---|
| A | `lessons-learned/A-doc-drift` |
| B | `lessons-learned/B-test-quality` |
| C | `lessons-learned/C-state-sync` |
| D | `lessons-learned/D-lifecycle` |
| E | `lessons-learned/E-compat` |

### 조회 명령 (에이전트 사용)

```bash
# 전체 lessons-learned 조회
bash .hxsk/hooks/md-recall-memory.sh "{task description}" \
  "." 5 compact

# 특정 카테고리만
bash .hxsk/hooks/md-recall-memory.sh "B-test-quality test" \
  "." 3 compact
```

### 트리거 시점

| 시점 | 스킬 | 동작 |
|---|---|---|
| PR 리뷰 후 | [`pr-review`](../../skills/pr-review/SKILL.md) | 리뷰 지적을 A-E 분류 후 저장 |
| Deviation 발생 시 | [`executor`](../../skills/executor/SKILL.md) | Rule 1-4 적용 후 해당 카테고리 저장 |
| 계획 수립 전 | [`planner`](../../skills/planner/SKILL.md) | 과거 lessons 조회 후 plan에 반영 |

---

## 4. 컴포넌트 2 — Cross-Phase Invariants (PLAN.md 확장)

> **수정 대상**: [`templates/PLAN.md`](../../templates/PLAN.md), [`skills/planner/SKILL.md`](../../skills/planner/SKILL.md), [`skills/executor/SKILL.md`](../../skills/executor/SKILL.md)

### PLAN.md frontmatter 확장

```yaml
---
phase: 3
plan: 1
wave: 1
depends_on: [2.3]
files_modified: []
autonomous: true

must_haves:
  truths: []
  artifacts: []

cross_phase_invariants:
  inherit:            # 이전 phase에서 물려받은 불변 조건 (복사)
    - "gate는 phase 6까지 shadow mode — blocking 없음"
    - "status=='Y' ⟺ state ∈ {HELD, SELL_PLACED}"
  new:                # 이번 phase에서 추가되는 불변 조건
    - "store write는 broker 성공 후 atomic"
---
```

### `<verification>` 블록 자동 포함

```xml
<verification>
## Cross-Phase Invariants 검증
- [ ] inherit invariants 위반 없음 (이전 phase 테스트 전원 통과)
- [ ] new invariants가 이번 phase 코드에 반영됨

## 기능 검증
- [ ] {must-have truths[0]}
- [ ] {must-have artifacts[0]}
</verification>
```

### planner SKILL.md 추가 지침

[`planner/SKILL.md`](../../skills/planner/SKILL.md)의 **Checklist Before Submitting Plans** 섹션에 추가:

```markdown
- [ ] cross_phase_invariants.inherit: 직전 plan의 inherit + new 복사
- [ ] cross_phase_invariants.new: 이번 phase에서 추가된 불변 조건 명시
- [ ] invariant 위반 감지 시 Rule 4 (아키텍처 체크포인트) 적용
```

### executor SKILL.md 추가 지침

[`executor/SKILL.md`](../../skills/executor/SKILL.md)의 **Step 2: Load Plan** 섹션 직후에 추가:

```markdown
### Cross-Phase Invariants 로드
PLAN.md frontmatter의 cross_phase_invariants를 파싱.
실행 중 invariant 위반이 감지되면 → Rule 4 즉시 적용.
```

---

## 5. 컴포넌트 3 — Pre-PR Self-Check A/B/C/D/E

> **수정 대상**: [`skills/create-pr/SKILL.md`](../../skills/create-pr/SKILL.md)

### create-pr SKILL.md 추가 블록

PR 생성 직전 단계에 다음 섹션 강제 삽입:

```markdown
## Pre-PR Self-Check (REQUIRED — 전 항목 통과 후 PR 생성)

lessons-learned 조회:
```bash
bash .hxsk/hooks/md-recall-memory.sh "pr check lessons-learned" \
  "." 10 compact
```

### A. 코드 ↔ 문서 정합
- [ ] 변경 함수/모듈의 docstring이 현재 구현과 일치
- [ ] PLAN.md 설명 ↔ 실제 구현 일치 (drift 시 둘 중 수정)
- [ ] 이전 phase SUMMARY.md의 본 단계 언급이 일관

### B. 테스트 품질
- [ ] 각 task에 real path 테스트 최소 1개 (mock-only 불가)
- [ ] DB/파일/연결 close() 또는 fixture teardown 존재
- [ ] 미사용 param은 `_` prefix 또는 제거됨

### C. 상태 동기화 / 의미론
- [ ] cross_phase_invariants 위반 없음 (PLAN.md frontmatter 확인)
- [ ] 이전 phase 테스트 전원 통과

### D. Resource / Lifecycle
- [ ] Threading 경계 resource 안전성 확인
- [ ] Shutdown/teardown path에 cleanup 존재

### E. Forward-compat
- [ ] 현재 미사용 entity 제거 또는 명시적 사유 기재

**실패 항목 발견 시**: 수정 → 재검증 → 전 항목 통과 후 PR 생성.
```

---

## 6. 컴포넌트 4 — Subagent Dispatch Prompt 개선

> **수정 대상**: [`skills/dispatcher/SKILL.md`](../../skills/dispatcher/SKILL.md)

### dispatcher SKILL.md 서브에이전트 프롬프트 템플릿 확장

각 서브에이전트 dispatch 프롬프트 끝에 다음 블록 추가:

```markdown
---

## LESSONS-LEARNED 참조 (REQUIRED)

실행 전 관련 lessons 조회:
```bash
bash .hxsk/hooks/md-recall-memory.sh "{task description}" \
  "." 5 compact
```
해당 카테고리(A/B/C/D/E) 패턴 확인 후 동일 실수 방지.

## Self-Review (REQUIRED)

완료 보고 전 다음 항목을 **명시적으로** 체크:

| 카테고리 | 확인 항목 | 결과 |
|---|---|---|
| A | docstring ↔ 구현 일치 | PASS / FAIL |
| B | real path 테스트 포함 | PASS / FAIL |
| C | cross_phase_invariants 위반 없음 | PASS / FAIL |
| D | resource cleanup 존재 | PASS / FAIL |
| E | 미사용 entity 없음 | PASS / FAIL |

## Ambiguity Log (REQUIRED)

구현 중 PLAN.md에 없는 결정을 내린 경우 각각 기록:

```
DECISION: {무엇을 결정했는지}
REASON:   {왜 그렇게 결정했는지}
ALT:      {고려한 다른 옵션}
```

모호성이 없었다면: `DECISION LOG: none`
```

---

## 7. 전체 워크플로우 연결

```
[planner] ─────────────────────────────────────────────────
  1. md-recall-memory.sh → .hxsk/memories/lessons-learned/
  2. cross_phase_invariants 필드 작성 (inherit + new)
  └→ PLAN.md 생성 (skills/planner/SKILL.md)

        ↓

[dispatcher → subagent] ────────────────────────────────────
  1. 서브에이전트 프롬프트에 lessons recall 삽입
  2. Self-Review 표 강제
  3. Ambiguity Log 강제
  └→ (skills/dispatcher/SKILL.md)

        ↓

[executor] ─────────────────────────────────────────────────
  1. cross_phase_invariants 로드 → invariant 위반 시 Rule 4
  2. deviation 발생 시 A/B/C/D/E 분류 후 lessons-learned 저장
  3. SUMMARY.md에 카테고리별 deviation 기록
  └→ (skills/executor/SKILL.md)

        ↓

[create-pr] ────────────────────────────────────────────────
  1. Pre-PR Self-Check A/B/C/D/E 전 항목 통과 필수
  2. lessons-learned 조회 후 체크리스트 실행
  └→ (skills/create-pr/SKILL.md)

        ↓

[pr-review] ────────────────────────────────────────────────
  1. 6 Persona 리뷰 수행 (기존)
  2. 리뷰 지적을 A/B/C/D/E 분류
  3. md-store-memory.sh → lessons-learned/{category}/ 저장
  └→ (skills/pr-review/SKILL.md)
```

---

## 8. 변경 파일 요약

| 파일 | 변경 유형 | 핵심 추가 내용 |
|---|---|---|
| [`memories/lessons-learned/A-doc-drift/`](../../memories/lessons-learned/A-doc-drift/) | 신규 디렉토리 | — |
| [`memories/lessons-learned/B-test-quality/`](../../memories/lessons-learned/B-test-quality/) | 신규 디렉토리 | — |
| [`memories/lessons-learned/C-state-sync/`](../../memories/lessons-learned/C-state-sync/) | 신규 디렉토리 | — |
| [`memories/lessons-learned/D-lifecycle/`](../../memories/lessons-learned/D-lifecycle/) | 신규 디렉토리 | — |
| [`memories/lessons-learned/E-compat/`](../../memories/lessons-learned/E-compat/) | 신규 디렉토리 | — |
| [`templates/PLAN.md`](../../templates/PLAN.md) | 수정 | `cross_phase_invariants` frontmatter 추가 |
| [`skills/planner/SKILL.md`](../../skills/planner/SKILL.md) | 수정 | invariants 작성 지침 + lessons recall |
| [`skills/executor/SKILL.md`](../../skills/executor/SKILL.md) | 수정 | A/B/C/D/E deviation 저장 + invariants 로드 |
| [`skills/create-pr/SKILL.md`](../../skills/create-pr/SKILL.md) | 수정 | Pre-PR Self-Check 블록 |
| [`skills/pr-review/SKILL.md`](../../skills/pr-review/SKILL.md) | 수정 | 리뷰 후 lessons 저장 |
| [`skills/dispatcher/SKILL.md`](../../skills/dispatcher/SKILL.md) | 수정 | lessons recall + ambiguity log |

**신규 파일**: 5개 디렉토리 (메모리 타입)
**수정 파일**: 6개 (템플릿 1 + 스킬 5)
**새 스크립트**: 0개

---

## 9. 5 카테고리 참조 (A-E)

> 원본 출처: 로컬 홈 디렉토리의 `agent-workflow-template.md` §2.1

| 카테고리 | 메모리 저장 경로 | 증상 | 근본 원인 |
|---|---|---|---|
| **A.** 코드 ↔ 문서 drift | [`A-doc-drift/`](../../memories/lessons-learned/A-doc-drift/) | docstring/plan 불일치 | literal copy + 구현 변경 반영 안 됨 |
| **B.** 테스트 품질 | [`B-test-quality/`](../../memories/lessons-learned/B-test-quality/) | mock-only 검증 | 최소 통과 테스트에 안주 |
| **C.** 상태 동기화 | [`C-state-sync/`](../../memories/lessons-learned/C-state-sync/) | invariant 파괴, timing 오류 | phase 간 상호작용 모델링 부족 |
| **D.** Resource / Lifecycle | [`D-lifecycle/`](../../memories/lessons-learned/D-lifecycle/) | thread safety, cleanup 누락 | 런타임 gotcha |
| **E.** Forward-compat | [`E-compat/`](../../memories/lessons-learned/E-compat/) | 미사용 param, dead weight | 다음 단계 미리 대비 |
