---
phase: 9
plan: "1A"
wave: 1
depends_on: []
files_modified:
  - .hxsk/skills/refactor/SKILL.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "refactor 스킬이 HXSK Skill(How) 컨벤션을 따른다 (frontmatter, Quick Reference, role, workflow)"
    - "스킬이 commit + verifier + empirical-validation을 참조하여 기존 패턴과 통합된다"
    - "스킬 내용이 200줄 이하로 컨텍스트 효율적이다"
    - "clean 스킬과 중복되지 않는다 (shellcheck/shfmt는 clean 스킬 담당)"
  artifacts:
    - ".hxsk/skills/refactor/SKILL.md 존재"
    - "wc -l .hxsk/skills/refactor/SKILL.md 결과 ≤200"
  key_links:
    - "PREPARE 단계에서 commit 스킬 참조"
    - "VERIFY 단계에서 verifier + empirical-validation 스킬 참조"
---

# Plan 9.1A: refactor 스킬 신규 작성

<objective>
awesome-copilot refactor 스킬의 PREPARE→IDENTIFY→REFACTOR→VERIFY 워크플로우를
HXSK Skill(How) 패턴으로 재설계하여 `.hxsk/skills/refactor/SKILL.md`를 신규 작성한다.

Purpose: AI가 리팩토링 시 동작 보존·증분 변경·테스트 의존성을 자동으로 준수하도록 안내
Output: .hxsk/skills/refactor/SKILL.md (≤200줄)
</objective>

<context>
Load for context:
- .hxsk/skills/empirical-validation/SKILL.md  (검증 패턴 참조)
- .hxsk/skills/commit/SKILL.md               (커밋 패턴 참조)
- .hxsk/skills/clean/SKILL.md                (중복 범위 확인)
- .hxsk/skills/debugger/SKILL.md             (스킬 구조 참조)
</context>

<tasks>

<task type="auto">
  <name>리서치: 기존 스킬 패턴 분석 + 중복 범위 확인</name>
  <files>읽기 전용</files>
  <action>
    1. .hxsk/skills/empirical-validation/SKILL.md 읽기 — 186줄 단일파일 스킬의 모범 패턴 확인
    2. .hxsk/skills/clean/SKILL.md 읽기 — clean이 다루는 범위 (shellcheck/shfmt) 확인하여 refactor와 중복 제거
    3. .hxsk/skills/commit/SKILL.md 읽기 — PREPARE 단계에서 참조할 커밋 패턴 확인
    4. awesome-copilot refactor 스킬 핵심 요소 정리:
       - 10가지 코드 스멜 (long methods, god objects, magic values 등)
       - 5단계 안전 프로세스 (prepare/identify/refactor/verify/clean)
       - 핵심 원칙 (behavior preservation, incremental, test dependency)
    
    AVOID: empirical-validation과 내용 중복 (검증 절차는 참조로 처리)
    AVOID: clean 스킬 내용 복제 (코드 품질 도구는 clean에서 담당)
  </action>
  <verify>각 스킬 파일이 읽혔고 중복 범위가 명확히 식별됨</verify>
  <done>중복 없는 refactor 스킬의 고유 범위가 정의됨</done>
</task>

<task type="auto">
  <name>refactor/SKILL.md 작성 (≤200줄)</name>
  <files>.hxsk/skills/refactor/SKILL.md</files>
  <action>
    다음 구조로 신규 작성 (총 ≤200줄 엄수):

    ```
    ---
    name: refactor
    description: "Use when code is hard to maintain — extract functions, eliminate smells, apply patterns without behavior change"
    trigger: "리팩토링, 코드 정리, 함수 분리, 코드 스멜 제거, refactor, extract method, rename, simplify"
    allowed-tools: [Read, Edit, Grep, Glob, Bash]
    ---

    ## Quick Reference (≤5줄)
    - Workflow: PREPARE → IDENTIFY → REFACTOR → VERIFY
    - 필수 조건: 테스트 존재 또는 동작 명세 확인 후 시작
    - 단위: 1회 1개 코드 스멜만 처리 (multi-smell 금지)
    - 커밋: 각 안전 상태마다 commit 스킬 적용
    - 검증: 각 단계 후 verifier + empirical-validation 적용
    ```

    본문 섹션:
    - role: 동작 보존 리팩토링 전문가 정의
    - PREPARE: 테스트 확인, 브랜치 생성, commit 스킬 참조
    - IDENTIFY: 10가지 코드 스멜 카탈로그 (각 1-2줄)
    - REFACTOR: 3가지 핵심 기법 (Extract Method, Type Safety, Design Pattern 간략)
    - VERIFY: empirical-validation 스킬 참조
    - Anti-patterns: 동시 다중 스멜 처리, 테스트 없는 리팩토링
    - 관련 스킬: commit, clean, verifier, empirical-validation

    AVOID: awesome-copilot의 전체 예제 코드 복사 (너무 길어짐)
    AVOID: 200줄 초과 — 상세 예제가 필요하면 references/examples.md 분리 허용
  </action>
  <verify>
    wc -l .hxsk/skills/refactor/SKILL.md
    grep -E "^name:|^description:|^trigger:" .hxsk/skills/refactor/SKILL.md
    grep -E "PREPARE|IDENTIFY|REFACTOR|VERIFY" .hxsk/skills/refactor/SKILL.md
  </verify>
  <done>
    - 파일 존재, ≤200줄
    - Quick Reference 5줄 이하
    - PREPARE→IDENTIFY→REFACTOR→VERIFY 4단계 모두 포함
    - commit, verifier, empirical-validation 참조 포함
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] wc -l .hxsk/skills/refactor/SKILL.md → ≤200
- [ ] grep "commit\|verifier\|empirical-validation" .hxsk/skills/refactor/SKILL.md → 3개 모두 등장
- [ ] grep "PREPARE\|IDENTIFY\|REFACTOR\|VERIFY" .hxsk/skills/refactor/SKILL.md → 4단계 모두 등장
- [ ] clean 스킬과 중복 없음 (shellcheck/shfmt 미포함)
</verification>

<success_criteria>
- [ ] .hxsk/skills/refactor/SKILL.md 존재 + ≤200줄
- [ ] HXSK 스킬 컨벤션 (frontmatter + QR + role) 준수
- [ ] 기존 스킬과 중복 없는 고유 범위
</success_criteria>
