---
phase: 9
plan: "1B"
wave: 1
depends_on: []
files_modified:
  - .hxsk/skills/executor/SKILL.md
  - .hxsk/skills/executor/references/execution-flow.md
  - .hxsk/skills/executor/references/deviation-rules.md
  - .hxsk/skills/executor/references/checkpoint-protocol.md
  - .hxsk/skills/executor/references/commit-protocol.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "executor/SKILL.md가 ≤200줄이 되어 콜드스타트 컨텍스트 비용이 ~70% 절감된다"
    - "핵심 실행 흐름(4단계 요약)이 entry에 유지되어 executor를 처음 읽어도 전체 흐름을 파악할 수 있다"
    - "references/ 파일이 각각 단일 주제로 한정되어 필요할 때만 로드된다"
    - "분할 전후 executor의 실행 의미(Deviation Rule 번호, Checkpoint 타입)가 변하지 않는다"
  artifacts:
    - ".hxsk/skills/executor/SKILL.md 존재 (≤200줄)"
    - ".hxsk/skills/executor/references/execution-flow.md 존재"
    - ".hxsk/skills/executor/references/deviation-rules.md 존재"
    - ".hxsk/skills/executor/references/checkpoint-protocol.md 존재"
    - ".hxsk/skills/executor/references/commit-protocol.md 존재"
  key_links:
    - "entry SKILL.md의 각 섹션이 대응되는 references/ 파일 경로를 명시"
---

# Plan 9.1B: executor SKILL.md Progressive Disclosure 분할

<objective>
681줄 executor/SKILL.md를 Progressive Disclosure 패턴으로 분할한다.
Entry(≤200줄): 흐름 요약 + references 링크
References: 상세 프로토콜 (필요시만 로드)

Purpose: executor 스킬 로드 시 불필요한 컨텍스트 폭발 방지 (~70% 절감)
Output: executor/SKILL.md (≤200줄) + references/ 4개 파일
</objective>

<context>
Load for context:
- .hxsk/skills/executor/SKILL.md (전체 — 분할 경계 파악)
</context>

<tasks>

<task type="auto">
  <name>리서치: executor 전체 읽기 + 분할 경계 매핑</name>
  <files>읽기 전용</files>
  <action>
    executor/SKILL.md 전체 읽기 후 각 섹션을 entry/reference로 분류:

    Entry (≤200줄에 들어가야 할 것):
    - frontmatter (12줄)
    - Quick Reference (21줄)
    - Execution Flow Steps 1-4 핵심만 (각 2-3줄 요약, 상세는 reference)
    - Deviation Rules 제목 + Rule 번호 + 1줄 요약 (상세는 reference)
    - "상세 → references/XXX.md 참조" 링크 섹션

    References (파일별 단일 주제):
    - execution-flow.md: Steps 1-8 전체 상세
    - deviation-rules.md: Rule 1-4 전체 + Deviation Memory + Authentication Gates
    - checkpoint-protocol.md: Checkpoint Protocol + Return Format + 모든 체크포인트 타입
    - commit-protocol.md: Task Commit Protocol + SUMMARY.md 템플릿 + Memory 저장

    AVOID: Deviation Rule 번호/이름 변경 — 다른 파일이 Rule 4 등을 참조함
    AVOID: Cross-Phase Invariants 섹션을 reference로 이동 — executor 핵심 규칙
  </action>
  <verify>섹션별 entry/reference 분류 완료, 총 entry 예상 줄수 ≤200 확인</verify>
  <done>분할 경계가 명확히 정의됨</done>
</task>

<task type="auto">
  <name>executor entry SKILL.md 재작성 (≤200줄) + references/ 4개 파일 생성</name>
  <files>
    .hxsk/skills/executor/SKILL.md
    .hxsk/skills/executor/references/execution-flow.md
    .hxsk/skills/executor/references/deviation-rules.md
    .hxsk/skills/executor/references/checkpoint-protocol.md
    .hxsk/skills/executor/references/commit-protocol.md
  </files>
  <action>
    1. executor/SKILL.md 재작성:
       - frontmatter + Quick Reference 유지 (그대로)
       - Execution Flow: Step 1~8 각 2줄 이하 요약 + "상세 → references/execution-flow.md"
       - Deviation Rules: Rule 1~4 제목+1줄 + "상세 → references/deviation-rules.md"
       - Checkpoint: 타입 목록만 + "상세 → references/checkpoint-protocol.md"
       - Commit Protocol: 1줄 요약 + "상세 → references/commit-protocol.md"
       - Cross-Phase Invariants 파싱: 그대로 유지 (핵심 동작)

    2. mkdir -p .hxsk/skills/executor/references/ 로 디렉토리 생성

    3. references/execution-flow.md: Step 1-8 전체 상세 내용
    4. references/deviation-rules.md: Rule 1-4 + Deviation Memory + Auth Gates
    5. references/checkpoint-protocol.md: 모든 체크포인트 타입 + Return Format 템플릿
    6. references/commit-protocol.md: Task Commit Protocol + SUMMARY.md 템플릿 + Memory 저장

    AVOID: 원본 내용 손실 — references 파일에 빠짐없이 이동
    AVOID: Rule 번호, Checkpoint 타입명 변경 — 다른 PLAN.md가 참조할 수 있음
  </action>
  <verify>
    wc -l .hxsk/skills/executor/SKILL.md
    ls .hxsk/skills/executor/references/
    grep "references/" .hxsk/skills/executor/SKILL.md | wc -l
  </verify>
  <done>
    - executor/SKILL.md ≤200줄
    - references/ 디렉토리에 4개 파일 존재
    - SKILL.md에서 references 링크 4개 이상 포함
    - 원본 내용 총량이 references 합계에 보존됨
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] wc -l .hxsk/skills/executor/SKILL.md → ≤200
- [ ] ls .hxsk/skills/executor/references/ → 4개 파일
- [ ] grep "Rule 1\|Rule 2\|Rule 3\|Rule 4" .hxsk/skills/executor/SKILL.md → 모두 존재 (참조 유지)
- [ ] cat .hxsk/skills/executor/references/deviation-rules.md | wc -l → >0 (내용 이동됨)
</verification>

<success_criteria>
- [ ] executor/SKILL.md ≤200줄 (분할 전 681줄 → ~70% 절감)
- [ ] references/ 4개 파일 모두 존재 + 비어있지 않음
- [ ] Deviation Rule 번호/이름 변경 없음
</success_criteria>
