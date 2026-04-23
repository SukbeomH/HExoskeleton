---
phase: 9
plan: "2A"
wave: 2
depends_on: ["1A", "1B", "1C", "1D"]
files_modified:
  - CLAUDE.md
  - .hxsk/hooks/INDEX.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "Phase 9 Wave 1 결과물이 모두 올바른 줄수 제한을 만족한다"
    - "verify-self-configure.sh가 0 FAIL로 통과한다"
    - "CLAUDE.md가 SKILL.md 200줄 규칙을 문서화한다"
    - "모든 변경이 단일 커밋으로 기록된다"
  artifacts:
    - "CLAUDE.md에 'SKILL.md ≤200줄 (entry point)' 제약 존재"
    - "git log에 Phase 9 커밋 존재"
  key_links:
    - "CLAUDE.md Document Hierarchy 섹션 → SKILL.md 줄수 제약"
---

# Plan 9.2A: 전체 검증 + CLAUDE.md 업데이트 + 커밋

<objective>
Wave 1 실행 결과를 검증하고, CLAUDE.md에 SKILL.md 200줄 규칙을 문서화한다.

Purpose: Phase 9 완료 확인 + 프레임워크 제약 영구 기록
Output: verify-self-configure PASS + CLAUDE.md 업데이트 + Phase 9 커밋
</objective>

<context>
Load for context:
- CLAUDE.md
- .hxsk/skills/ (전체 디렉토리 구조)
</context>

<tasks>

<task type="auto">
  <name>리서치: Wave 1 결과물 검증</name>
  <files>읽기 전용</files>
  <action>
    다음 명령으로 Wave 1 모든 결과물 확인:

    1. 줄수 검증:
       wc -l .hxsk/skills/refactor/SKILL.md
       wc -l .hxsk/skills/executor/SKILL.md
       wc -l .hxsk/skills/planner/SKILL.md
       wc -l .hxsk/skills/verifier/SKILL.md
       wc -l .hxsk/skills/debugger/SKILL.md

    2. references/ 파일 존재 확인:
       ls .hxsk/skills/executor/references/
       ls .hxsk/skills/planner/references/
       ls .hxsk/skills/verifier/references/
       ls .hxsk/skills/debugger/references/

    3. refactor 스킬 컨벤션 확인:
       grep -E "^name:|^description:|^trigger:" .hxsk/skills/refactor/SKILL.md
       grep "PREPARE\|IDENTIFY\|REFACTOR\|VERIFY" .hxsk/skills/refactor/SKILL.md

    4. 전체 검증:
       bash .hxsk/scripts/verify-self-configure.sh

    FAIL이 있으면 즉시 수정 — Wave 1 플랜의 해당 파일로 이동하여 수정.
    verify-self-configure.sh의 "Hooks mismatch" 같은 기존 오류 무시 가능 (Phase 9 범위 아님).
  </action>
  <verify>wc -l 결과가 모두 제한 이하 + references/ 파일 존재</verify>
  <done>모든 Wave 1 결과물이 제약을 만족하거나 미충족 항목이 파악됨</done>
</task>

<task type="auto">
  <name>CLAUDE.md 업데이트 + Phase 9 커밋</name>
  <files>CLAUDE.md</files>
  <action>
    1. CLAUDE.md의 Document Hierarchy 또는 Compaction Rules 섹션에 SKILL.md 줄수 규칙 추가:

    기존:
    ```
    - L2=skills/SKILL.md (상세) → L3=.hxsk/research/ (출처)
    ```

    업데이트:
    ```
    - L2=skills/SKILL.md (상세, entry ≤200줄) + skills/{name}/references/ (상세, 선택 로드)
    → L3=.hxsk/research/ (출처)
    ```

    Prompt Maintenance Rules 섹션의 "Skill/Agent" 줄도 업데이트:
    ```
    Skill/Agent: Quick Reference ≤5줄, entry SKILL.md ≤200줄, 상세는 references/ 분리
    ```

    AVOID: CLAUDE.md 120줄 제한 초과 — 기존 내용 압축 없이 한 줄 이하 추가만
    AVOID: 다른 섹션 내용 변경

    2. 커밋 (commit 스킬 없이 직접):
    git add .hxsk/skills/ CLAUDE.md
    git commit -F /tmp/commit_phase9.txt
    (커밋 메시지를 파일로 먼저 Write한 후 사용)

    커밋 메시지 구조:
    "feat(phase-9): Progressive Disclosure + refactor 스킬 (Wave 1~2)

    - .hxsk/skills/refactor/SKILL.md 신규 (PREPARE→IDENTIFY→REFACTOR→VERIFY)
    - executor SKILL.md: 681줄 → ≤200줄 + references/ 4개
    - planner SKILL.md: 566줄 → ≤200줄 + references/ 5개
    - verifier SKILL.md: 452줄 → ≤160줄 + references/ 2개
    - debugger SKILL.md: 365줄 → ≤160줄 + references/ 2개
    - CLAUDE.md: SKILL.md ≤200줄 entry 규칙 추가"
  </action>
  <verify>
    grep "≤200\|200줄" CLAUDE.md
    git log --oneline -1
  </verify>
  <done>
    - CLAUDE.md에 SKILL.md entry ≤200줄 규칙이 문서화됨
    - git log에 Phase 9 커밋 존재
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] wc -l .hxsk/skills/refactor/SKILL.md → ≤200
- [ ] wc -l .hxsk/skills/executor/SKILL.md → ≤200
- [ ] wc -l .hxsk/skills/planner/SKILL.md → ≤200
- [ ] wc -l .hxsk/skills/verifier/SKILL.md → ≤160
- [ ] wc -l .hxsk/skills/debugger/SKILL.md → ≤160
- [ ] bash .hxsk/scripts/verify-self-configure.sh → FAIL 없음 (Phase 9 대상 기준)
- [ ] grep "≤200" CLAUDE.md → 존재
- [ ] git log --oneline -1 → Phase 9 커밋
</verification>

<success_criteria>
- [ ] 모든 스킬 줄수 제한 만족
- [ ] CLAUDE.md ≤200줄 entry 규칙 문서화
- [ ] Phase 9 단일 커밋 완료
</success_criteria>
