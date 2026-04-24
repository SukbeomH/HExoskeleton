---
phase: 5
plan: 1
wave: 1
depends_on: []
files_modified:
  - .hxsk/specs/robustness-ci.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "SPEC.md에 Goals / Scope / Done Criteria / Constraints 4섹션 존재"
    - "압박 시나리오 타입 3가지 이상 정의"
    - "CI 자동화 인터페이스(입력/출력) 명시"
  artifacts:
    - .hxsk/specs/robustness-ci.md

cross_phase_invariants:
  inherit: []
  new:
    - "SPEC은 What(목표·범위·완료 기준)만 기술, How(구현 방법)는 포함하지 않는다"
    - "압박 시나리오 정의는 skill-testing SKILL.md의 시나리오 타입과 일치"
---

# Plan 5.1: 강인성 테스트 인프라 SPEC.md

<objective>
압박 시나리오 기반 스킬 강인성 테스트를 CI에서 자동 실행하기 위한 SPEC.md를 작성한다.
이 SPEC은 향후 구현 단계(Phase 5 플랜 2+)의 기반이 된다.

Purpose: "스킬이 에이전트 행동을 바꾸는지"를 자동·반복 검증하는 인프라 목표 정의
Output: .hxsk/specs/robustness-ci.md (Goals/Scope/Done Criteria/Constraints)
</objective>

<context>
Load for context:
- .hxsk/skills/skill-testing/SKILL.md (TDD 방법론, 압박 시나리오 타입)
- .hxsk/ROADMAP.md (Phase 5 목표 확인)
- .hxsk/TODO.md (강인성 테스트 항목)
</context>

<tasks>

<task type="auto">
  <name>specs/ 디렉토리 생성 + SPEC.md 작성</name>
  <files>.hxsk/specs/robustness-ci.md</files>
  <action>
    `mkdir -p .hxsk/specs/` 후 아래 구조로 SPEC.md를 작성한다:

    **## Goals**
    - 스킬 강인성을 CI에서 자동으로 검증한다
    - RED(위반 관찰) → GREEN(준수 확인) 사이클을 매 스킬 변경 시 실행한다
    - 합리화(rationalization) 탐지율을 측정하고 추적한다

    **## Scope**
    포함:
    - 22개 HXSK 스킬에 대한 압박 시나리오 라이브러리
    - skill-testing SKILL.md의 시나리오 타입 4가지 구현:
      1. 시간 압박 (time pressure)
      2. 매몰 비용 (sunk cost)
      3. 모호한 완료 기준 (ambiguous completion)
      4. 복합 압박 (3+ 압박 결합)
    - 자동 RED/GREEN 판정 스크립트
    - 결과 리포트 생성

    제외:
    - 실제 LLM API 호출 (서브에이전트 실행은 수동 트리거)
    - 스킬 내용 자동 수정

    **## Done Criteria**
    - [ ] `bash .hxsk/scripts/run-skill-test.sh <skill-name>` 실행 시 RED/GREEN 결과 출력
    - [ ] 결과가 `.hxsk/reports/skill-test-{date}.md`에 저장
    - [ ] CI에서 GitHub Actions workflow로 실행 가능 (`.github/workflows/skill-test.yml`)
    - [ ] 22개 스킬 중 최소 5개 시나리오 라이브러리 완비

    **## Constraints**
    - 외부 LLM API 직접 호출 금지 (Claude Code 서브에이전트를 통해서만)
    - 테스트 실행 시간: 스킬당 30초 이내
    - 기존 `.hxsk/skills/` 파일 수정 금지 (테스트 전용 파일 분리)

    **## Open Questions** (구현 전 결정 필요)
    - CI 환경에서 서브에이전트 실행 방법 (Claude Code headless mode 가능 여부)
    - RED 판정 기준: 위반 키워드 패턴 매칭 vs LLM 판정

    AVOID: 구현 상세 포함 — SPEC은 What만 기술
  </action>
  <verify>grep -q "## Goals" .hxsk/specs/robustness-ci.md && grep -q "## Scope" .hxsk/specs/robustness-ci.md && grep -q "## Done Criteria" .hxsk/specs/robustness-ci.md && echo "SPEC OK"</verify>
  <done>
    - Goals/Scope/Done Criteria/Constraints 4섹션 완비
    - 압박 시나리오 타입 4가지 명시
    - Done Criteria에 실행 명령어 포함
    - Open Questions 섹션 존재
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] 4섹션 모두 존재 (grep 통과)
- [ ] 압박 시나리오 4가지 정의
- [ ] Done Criteria에 실행 가능한 커맨드 명시
</verification>

<success_criteria>
- [ ] 모든 태스크 검증 통과
- [ ] Phase 5 플랜 2+ 작성 시 이 SPEC을 기반으로 구현 가능한 수준
</success_criteria>
