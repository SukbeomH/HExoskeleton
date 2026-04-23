---
phase: 9
plan: "1C"
wave: 1
depends_on: []
files_modified:
  - .hxsk/skills/planner/SKILL.md
  - .hxsk/skills/planner/references/discovery-protocol.md
  - .hxsk/skills/planner/references/task-sizing.md
  - .hxsk/skills/planner/references/plan-structure.md
  - .hxsk/skills/planner/references/goal-backward.md
  - .hxsk/skills/planner/references/pre-planning.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "planner/SKILL.md가 ≤200줄이 되어 콜드스타트 컨텍스트 비용이 ~65% 절감된다"
    - "Task Anatomy (<files><action><verify><done>)이 entry에 유지된다"
    - "Discovery Level 기준(L0~L3)이 references/discovery-protocol.md에서 완전하게 유지된다"
    - "PLAN.md 전체 구조 템플릿이 references/plan-structure.md에 보존된다"
  artifacts:
    - ".hxsk/skills/planner/SKILL.md 존재 (≤200줄)"
    - ".hxsk/skills/planner/references/discovery-protocol.md 존재"
    - ".hxsk/skills/planner/references/task-sizing.md 존재"
    - ".hxsk/skills/planner/references/plan-structure.md 존재"
    - ".hxsk/skills/planner/references/goal-backward.md 존재"
    - ".hxsk/skills/planner/references/pre-planning.md 존재"
  key_links:
    - "entry의 Discovery 섹션 → references/discovery-protocol.md"
    - "entry의 PLAN.md Structure 섹션 → references/plan-structure.md"
---

# Plan 9.1C: planner SKILL.md Progressive Disclosure 분할

<objective>
566줄 planner/SKILL.md를 Progressive Disclosure 패턴으로 분할한다.
Entry(≤200줄): 핵심 철학 + Task Anatomy + Task Types + Output Formats + references 링크
References: Discovery Protocol, Task Sizing, PLAN.md Structure, Goal-backward, Pre-planning

Purpose: planner 스킬 로드 시 불필요한 컨텍스트 폭발 방지 (~65% 절감)
Output: planner/SKILL.md (≤200줄) + references/ 5개 파일
</objective>

<context>
Load for context:
- .hxsk/skills/planner/SKILL.md (전체 — 분할 경계 파악)
</context>

<tasks>

<task type="auto">
  <name>리서치: planner 전체 읽기 + 분할 경계 매핑</name>
  <files>읽기 전용</files>
  <action>
    planner/SKILL.md 전체 읽기 후 각 섹션을 entry/reference로 분류:

    Entry (≤200줄에 들어가야 할 것):
    - frontmatter (13줄)
    - Quick Reference (5줄)
    - role (10줄)
    - Philosophy 핵심: Solo Dev + AI (10줄), Plans Are Prompts (8줄), Quality Curve (표 1개)
    - Task Anatomy: 4개 필드 정의 (30줄) — AI가 매번 참조하는 핵심
    - Task Types 표 (10줄)
    - Output Formats (15줄)
    - Checklist Before Submitting (15줄)
    - "상세 → references/XXX.md" 링크 섹션 (10줄)

    References (파일별 단일 주제):
    - pre-planning.md: SPEC Guard + Memory Recall
    - discovery-protocol.md: L0~L3 전체 + depth indicators
    - task-sizing.md: Context Budget Rules + Split Signals + Estimating table
    - plan-structure.md: Full PLAN.md Structure template + Frontmatter fields + User Setup + Dependency Graph + TDD
    - goal-backward.md: Goal-Backward Methodology + Anti-patterns

    AVOID: Task Anatomy를 references로 이동 — AI가 매 태스크마다 참조하는 핵심
    AVOID: Output Formats를 references로 이동 — 최종 출력 형식은 entry에 있어야 함
  </action>
  <verify>섹션별 분류 완료, entry 예상 줄수 ≤200 확인</verify>
  <done>분할 경계가 명확히 정의됨</done>
</task>

<task type="auto">
  <name>planner entry SKILL.md 재작성 (≤200줄) + references/ 5개 파일 생성</name>
  <files>
    .hxsk/skills/planner/SKILL.md
    .hxsk/skills/planner/references/pre-planning.md
    .hxsk/skills/planner/references/discovery-protocol.md
    .hxsk/skills/planner/references/task-sizing.md
    .hxsk/skills/planner/references/plan-structure.md
    .hxsk/skills/planner/references/goal-backward.md
  </files>
  <action>
    1. planner/SKILL.md 재작성:
       - frontmatter + Quick Reference + role 유지
       - Philosophy: 3개 절 각 3-4줄로 압축 + "상세 → references/ 없음 (원칙은 entry)"
       - Pre-planning: 2줄 요약 + "상세 → references/pre-planning.md"
       - Discovery: L0~L3 한 줄씩 요약 + "상세 → references/discovery-protocol.md"
       - Task Anatomy: <files><action><verify><done> 정의 완전 유지 (핵심)
       - Task Types 표 유지
       - Task Sizing: 한 줄 요약 + "상세 → references/task-sizing.md"
       - PLAN.md Structure: 한 줄 요약 + "상세 → references/plan-structure.md"
       - Goal-backward: 핵심 한 줄 + "상세 → references/goal-backward.md"
       - Output Formats: 유지 (짧음)
       - Checklist: 유지 (항상 필요)

    2. mkdir -p .hxsk/skills/planner/references/ 로 디렉토리 생성

    3. references/pre-planning.md: SPEC Guard bash snippet + Memory Recall 전체
    4. references/discovery-protocol.md: L0~L3 상세 + depth indicators
    5. references/task-sizing.md: Context Budget Rules + Split Signals + Estimating Context 표
    6. references/plan-structure.md: PLAN.md 전체 템플릿 + Frontmatter Fields 표 + User Setup + Dependency Graph + Vertical Slices + TDD Plan Structure
    7. references/goal-backward.md: Goal-backward Process + Must-haves Structure + Anti-patterns

    AVOID: 원본 내용 손실 — references에 빠짐없이 이동
    AVOID: Task Anatomy 단축 — 이는 entry에 완전히 유지
  </action>
  <verify>
    wc -l .hxsk/skills/planner/SKILL.md
    ls .hxsk/skills/planner/references/
    grep "references/" .hxsk/skills/planner/SKILL.md | wc -l
  </verify>
  <done>
    - planner/SKILL.md ≤200줄
    - references/ 디렉토리에 5개 파일 존재
    - Task Anatomy 4개 필드 정의가 entry에 완전히 포함됨
    - references 링크 5개 이상 포함
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] wc -l .hxsk/skills/planner/SKILL.md → ≤200
- [ ] ls .hxsk/skills/planner/references/ → 5개 파일
- [ ] grep "<files>\|<action>\|<verify>\|<done>" .hxsk/skills/planner/SKILL.md → 4개 모두 존재
- [ ] grep "L0\|L1\|L2\|L3" .hxsk/skills/planner/references/discovery-protocol.md → 존재
</verification>

<success_criteria>
- [ ] planner/SKILL.md ≤200줄 (분할 전 566줄 → ~65% 절감)
- [ ] references/ 5개 파일 모두 존재 + 비어있지 않음
- [ ] Task Anatomy가 entry에 완전히 유지됨
</success_criteria>
