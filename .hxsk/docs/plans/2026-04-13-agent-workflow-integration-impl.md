# Agent Workflow Integration — 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** `agent-workflow-template.md`의 4개 컴포넌트를 기존 HXSK 스킬 5개에 통합한다.

**Architecture:** 새 스크립트 없이 기존 `md-store-memory.sh` / `md-recall-memory.sh`를 활용하는 Approach C. 메모리 디렉토리 신규 생성 + 스킬 파일 텍스트 추가 방식.

**Design Doc:** [`.hxsk/docs/plans/2026-04-13-agent-workflow-integration-design.md`](2026-04-13-agent-workflow-integration-design.md)

**Tech Stack:** bash, markdown, HXSK memory hooks

---

## Task 1: lessons-learned 메모리 디렉토리 생성

**Files:**
- Create: `.hxsk/memories/lessons-learned/A-doc-drift/.gitkeep`
- Create: `.hxsk/memories/lessons-learned/B-test-quality/.gitkeep`
- Create: `.hxsk/memories/lessons-learned/C-state-sync/.gitkeep`
- Create: `.hxsk/memories/lessons-learned/D-lifecycle/.gitkeep`
- Create: `.hxsk/memories/lessons-learned/E-compat/.gitkeep`

**Step 1: 디렉토리 및 .gitkeep 파일 생성**

```bash
mkdir -p .hxsk/memories/lessons-learned/{A-doc-drift,B-test-quality,C-state-sync,D-lifecycle,E-compat}
touch .hxsk/memories/lessons-learned/A-doc-drift/.gitkeep
touch .hxsk/memories/lessons-learned/B-test-quality/.gitkeep
touch .hxsk/memories/lessons-learned/C-state-sync/.gitkeep
touch .hxsk/memories/lessons-learned/D-lifecycle/.gitkeep
touch .hxsk/memories/lessons-learned/E-compat/.gitkeep
```

**Step 2: 생성 확인**

```bash
ls -la .hxsk/memories/lessons-learned/
```

Expected: 5개 서브디렉토리 각각 `.gitkeep` 파일 포함

**Step 3: Commit**

```bash
git add .hxsk/memories/lessons-learned/
git commit -m "feat(memory): lessons-learned 메모리 타입 디렉토리 추가 (A-E 카테고리)"
```

---

## Task 2: templates/PLAN.md — cross_phase_invariants frontmatter 추가

**Files:**
- Modify: `.hxsk/templates/PLAN.md:6-11`

**Step 1: 현재 내용 확인**

Read `.hxsk/templates/PLAN.md` 라인 1-15.

Expected: frontmatter에 `phase`, `plan`, `wave`, `gap_closure` 필드만 존재.

**Step 2: cross_phase_invariants 필드 추가**

`.hxsk/templates/PLAN.md`의 frontmatter 내부 `gap_closure: false` 아래에 추가:

```markdown
cross_phase_invariants:
  inherit: []   # 직전 phase의 inherit + new를 그대로 복사
  new: []       # 이번 phase에서 새로 추가되는 불변 조건
```

전체 frontmatter 결과:

```markdown
---
phase: {N}
plan: {M}
wave: {W}
gap_closure: false
cross_phase_invariants:
  inherit: []   # 직전 phase의 inherit + new를 그대로 복사
  new: []       # 이번 phase에서 새로 추가되는 불변 조건
---
```

**Step 3: 검증**

Read `.hxsk/templates/PLAN.md` — `cross_phase_invariants` 필드가 frontmatter 내에 존재하는지 확인.

**Step 4: Commit**

```bash
git add .hxsk/templates/PLAN.md
git commit -m "feat(template): PLAN.md frontmatter에 cross_phase_invariants 필드 추가"
```

---

## Task 3: planner/SKILL.md — lessons-learned recall + invariants 체크리스트

**Files:**
- Modify: `.hxsk/skills/planner/SKILL.md`

**Step 1: 수정 위치 확인**

Read `.hxsk/skills/planner/SKILL.md`.

위치 A: `## Pre-Planning: Memory Recall` 섹션 내 bash 명령 블록 (약 82-97줄)
위치 B: `## Checklist Before Submitting Plans` 섹션 끝 (약 504-516줄)

**Step 2-A: Pre-Planning Memory Recall에 lessons-learned 조회 추가**

기존 Grep 명령 블록 바로 아래, `과거 execution-summary...` 문단 앞에 삽입:

```markdown
# lessons-learned 조회 — 반복 패턴 방지
bash .hxsk/hooks/md-recall-memory.sh "{phase/feature description}" \
  "." 5 compact
```

**Step 2-B: Checklist Before Submitting Plans에 invariants 항목 추가**

체크리스트 마지막 항목 뒤에 추가:

```markdown
- [ ] cross_phase_invariants.inherit: 직전 plan의 (inherit + new) 복사
- [ ] cross_phase_invariants.new: 이번 phase에서 추가되는 불변 조건 명시
- [ ] invariant 위반 시 Rule 4 (아키텍처 체크포인트) 적용 명시
```

**Step 3: 검증**

```bash
grep -n "lessons-learned" .hxsk/skills/planner/SKILL.md
grep -n "cross_phase_invariants" .hxsk/skills/planner/SKILL.md
```

Expected: 각각 1건 이상 매칭

**Step 4: Commit**

```bash
git add .hxsk/skills/planner/SKILL.md
git commit -m "feat(skill/planner): lessons-learned recall + cross_phase_invariants 체크리스트 추가"
```

---

## Task 4: executor/SKILL.md — invariants 로드 + deviation A/B/C/D/E 분류

**Files:**
- Modify: `.hxsk/skills/executor/SKILL.md`

**Step 1: 수정 위치 확인**

Read `.hxsk/skills/executor/SKILL.md`.

위치 A: `### Step 2: Load Plan` → `Parse:` 블록 끝 (약 53-65줄)
위치 B: `### Post-Deviation: Store Each Deviation` (약 259-268줄)

**Step 2-A: Step 2 내 Cross-Phase Invariants 파싱 섹션 추가**

`Parse:` 블록(frontmatter, Objective, Context files, Tasks, Verification, Success criteria 나열) 뒤에 추가:

```markdown
### Cross-Phase Invariants 파싱

`cross_phase_invariants.inherit + new` 필드를 읽어 내재화.
실행 중 코드/로직이 이 조건을 위반하면 → **즉시 Rule 4 (아키텍처 체크포인트) 적용**.

위반 신호:
- 이전 phase 테스트가 현재 코드에서 실패
- 명시된 불변 조건과 반대되는 로직 추가
- semantic 제약 (e.g. "status=='Y' ⟺ state ∈ {...}") 파괴
```

**Step 2-B: Post-Deviation Store에 A/B/C/D/E 분류 가이드 추가**

`### Post-Deviation: Store Each Deviation` 섹션의 bash 명령 **앞**에 추가:

```markdown
#### Deviation → A/B/C/D/E 카테고리 분류

| Rule | 기본 카테고리 | 저장 경로 |
|------|------|------|
| Rule 1 (Bug fix) | C (semantic) 또는 D (lifecycle) | `lessons-learned/C-state-sync` 또는 `lessons-learned/D-lifecycle` |
| Rule 2 (Missing Critical) | B (test) 또는 D (lifecycle) | `lessons-learned/B-test-quality` 또는 `lessons-learned/D-lifecycle` |
| Rule 3 (Blocking) | D (lifecycle) 또는 A (doc) | `lessons-learned/D-lifecycle` 또는 `lessons-learned/A-doc-drift` |
| Rule 4 (Architecture) | C (state sync) | `lessons-learned/C-state-sync` |

저장 시 타입 파라미터를 카테고리 경로로 지정:
```

기존 bash 명령의 마지막 파라미터를 수정 안내로 보강:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Lesson {카테고리}: {description}" \
  "{deviation 상세: 무엇을 발견했고, 무엇을 수정했고, 왜}" \
  "lessons-learned,category-{A|B|C|D|E},{phase-plan}" \
  "lessons-learned/{카테고리 디렉토리}"   # 예: lessons-learned/B-test-quality
```

**Step 3: 검증**

```bash
grep -n "cross_phase_invariants\|Rule 4.*Invariant\|lessons-learned" \
  .hxsk/skills/executor/SKILL.md
```

Expected: 3건 이상 매칭

**Step 4: Commit**

```bash
git add .hxsk/skills/executor/SKILL.md
git commit -m "feat(skill/executor): cross_phase_invariants 로드 + deviation A/B/C/D/E 분류 저장"
```

---

## Task 5: create-pr/SKILL.md — Pre-PR Self-Check A/B/C/D/E 추가

**Files:**
- Modify: `.hxsk/skills/create-pr/SKILL.md:125-131`

**Step 1: 수정 위치 확인**

Read `.hxsk/skills/create-pr/SKILL.md` 라인 120-135.

Expected: `## PR 생성 전 자가 점검` 섹션에 범위/크기 체크리스트만 존재.

**Step 2: 기존 섹션에 A/B/C/D/E 블록 추가**

`## PR 생성 전 자가 점검` 섹션 제목을 유지하고, 기존 4개 항목을 `### 범위 / 크기` 서브섹션으로 감싸고, 그 아래 새 서브섹션 추가:

```markdown
## PR 생성 전 자가 점검

### 범위 / 크기
- [ ] 변경 목적이 2개 이상 포함되어 있지 않은가?
- [ ] 프로덕션 코드 변경이 500줄을 넘지 않는가?
- [ ] "이것도 같이 고치면 좋겠다"로 범위를 넓히지 않았는가?
- [ ] PR 설명만 읽고도 왜 이 변경이 필요한지 이해할 수 있는가?

### A/B/C/D/E 품질 점검 (REQUIRED)

먼저 lessons-learned 조회:

```bash
bash .hxsk/hooks/md-recall-memory.sh "pr quality check" \
  "." 10 compact
```

**A. 코드 ↔ 문서 정합**
- [ ] 변경 함수/모듈의 docstring이 현재 구현과 일치
- [ ] PLAN.md 설명 ↔ 실제 구현 일치 (drift 시 둘 중 수정)

**B. 테스트 품질**
- [ ] 각 task에 real path 테스트 최소 1개 (mock-only 불가)
- [ ] DB/파일/연결 close() 또는 fixture teardown 존재
- [ ] 미사용 param은 `_` prefix 또는 제거됨

**C. 상태 동기화 / 의미론**
- [ ] cross_phase_invariants 위반 없음 (PLAN.md frontmatter 확인)
- [ ] 이전 phase 테스트 전원 통과

**D. Resource / Lifecycle**
- [ ] Threading 경계 resource 안전성 확인
- [ ] Shutdown/teardown path에 cleanup 존재

**E. Forward-compat**
- [ ] 현재 미사용 entity 제거 또는 명시적 사유 기재

**실패 항목 발견 시**: 수정 → 재검증 → 전 항목 통과 후 PR 생성.
```

**Step 3: 검증**

```bash
grep -n "A/B/C/D/E\|lessons-learned\|Forward-compat" \
  .hxsk/skills/create-pr/SKILL.md
```

Expected: 3건 이상 매칭

**Step 4: Commit**

```bash
git add .hxsk/skills/create-pr/SKILL.md
git commit -m "feat(skill/create-pr): Pre-PR Self-Check A/B/C/D/E 품질 점검 추가"
```

---

## Task 6: pr-review/SKILL.md — 리뷰 후 lessons-learned 저장

**Files:**
- Modify: `.hxsk/skills/pr-review/SKILL.md` (Post-Review Actions 섹션 뒤)

**Step 1: 수정 위치 확인**

Read `.hxsk/skills/pr-review/SKILL.md` 라인 198-216.

Expected: `## Post-Review Actions` 섹션에 gh pr review 명령만 존재.

**Step 2: Post-Review Actions 끝에 lessons-learned 저장 섹션 추가**

`## Scripts` 섹션 바로 앞에 삽입:

```markdown
## Lessons-Learned 저장 (REQUEST_CHANGES 또는 [High]/[Blocker] 발견 시)

리뷰에서 발견된 패턴을 A/B/C/D/E로 분류하여 저장한다.

**카테고리 판단 기준:**
- A (doc-drift): docstring/plan 불일치, stale 경로, 주석 오류
- B (test-quality): mock-only 테스트, coverage 부족, resource close 누락
- C (state-sync): invariant 위반, timing 오류, semantic 불일치
- D (lifecycle): thread safety, cleanup 누락, fixture scope 문제
- E (compat): 미사용 param, dead weight, forward-compat dead code

**저장 명령 (각 패턴별):**

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Lesson {카테고리}: {패턴 제목}" \
  "증상: {구체적 코드/상황}
PR: #{N}
예방: {다음에 이 실수를 방지하려면}" \
  "lessons-learned,category-{A|B|C|D|E},pr-{N}" \
  "lessons-learned/{카테고리 디렉토리}"
```

APPROVE인 경우에도 [High] 이상 발견이 있었다면 저장.
```

**Step 3: 검증**

```bash
grep -n "Lessons-Learned\|lessons-learned\|카테고리" \
  .hxsk/skills/pr-review/SKILL.md
```

Expected: 3건 이상 매칭

**Step 4: Commit**

```bash
git add .hxsk/skills/pr-review/SKILL.md
git commit -m "feat(skill/pr-review): 리뷰 후 lessons-learned A/B/C/D/E 분류 저장 추가"
```

---

## Task 7: dispatcher/SKILL.md — 서브에이전트 프롬프트에 lessons recall + ambiguity log 추가

**Files:**
- Modify: `.hxsk/skills/dispatcher/SKILL.md:111-124`

**Step 1: 수정 위치 확인**

Read `.hxsk/skills/dispatcher/SKILL.md` 라인 111-125.

Expected: **서브에이전트 프롬프트 템플릿** 내 Rules 블록에 파일 범위/커밋 형식만 존재.

**Step 2: 서브에이전트 프롬프트 템플릿 끝에 3개 블록 추가**

기존 `Rules:` 블록의 마지막 줄(`- 완료/실패 시 exit`) 뒤에 추가:

```
## LESSONS-LEARNED 참조 (REQUIRED)

실행 전 관련 패턴 조회:
```bash
bash .hxsk/hooks/md-recall-memory.sh "{WORK_ID} {task description}" \
  "." 5 compact
```
해당 A/B/C/D/E 패턴 확인 후 동일 실수 방지.

## Self-Review (REQUIRED)

완료 보고 전 아래 표를 명시적으로 작성:

| 카테고리 | 확인 항목 | 결과 |
|---|---|---|
| A | docstring ↔ 구현 일치 | PASS / FAIL |
| B | real path 테스트 포함 | PASS / FAIL |
| C | cross_phase_invariants 위반 없음 | PASS / FAIL |
| D | resource cleanup 존재 | PASS / FAIL |
| E | 미사용 entity 없음 | PASS / FAIL |

## Ambiguity Log (REQUIRED)

PLAN.md에 없는 결정을 내린 경우 각각 기록:
DECISION: {무엇을 결정}
REASON:   {왜 그렇게 결정}
ALT:      {고려한 다른 옵션}

결정이 없었다면: DECISION LOG: none
```

**Step 3: 검증**

```bash
grep -n "LESSONS-LEARNED\|Ambiguity Log\|Self-Review" \
  .hxsk/skills/dispatcher/SKILL.md
```

Expected: 3건 매칭

**Step 4: Commit**

```bash
git add .hxsk/skills/dispatcher/SKILL.md
git commit -m "feat(skill/dispatcher): 서브에이전트 프롬프트에 lessons recall + ambiguity log 추가"
```

---

## Must-Haves

모든 태스크 완료 후 검증:

- [ ] `.hxsk/memories/lessons-learned/` 아래 5개 서브디렉토리 존재
- [ ] `templates/PLAN.md` frontmatter에 `cross_phase_invariants` 필드 존재
- [ ] `planner/SKILL.md`에 `lessons-learned` recall 명령 존재
- [ ] `executor/SKILL.md`에 `cross_phase_invariants` 파싱 + A/B/C/D/E 분류 가이드 존재
- [ ] `create-pr/SKILL.md`에 A/B/C/D/E 품질 점검 블록 존재
- [ ] `pr-review/SKILL.md`에 `md-store-memory.sh` lessons 저장 섹션 존재
- [ ] `dispatcher/SKILL.md`에 Ambiguity Log + Self-Review 표 존재
- [ ] doc-lint PASS (7/7)

## Success Criteria

- [ ] 모든 태스크 verified passing (7개 커밋)
- [ ] Must-haves 전 항목 확인
- [ ] `git log --oneline -7` 으로 7개 atomic commit 확인
