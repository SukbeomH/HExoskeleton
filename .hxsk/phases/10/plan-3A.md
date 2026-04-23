---
phase: 10
plan: "3A"
wave: 3
depends_on: ["10.2A"]
files_modified:
  - .hxsk/skills/bootstrap/SKILL.md
  - .hxsk/skills/commit/SKILL.md
  - .hxsk/skills/create-pr/SKILL.md
  - .hxsk/skills/write-report/SKILL.md
autonomous: false
user_setup: []

must_haves:
  truths:
    - "MEDIUM 4개 스킬의 description이 'Use when...' CSO 패턴을 따른다"
    - "각 스킬 적용 후 /skill-testing으로 행동 변화가 확인된다"
    - "Quick Reference가 5줄 이하이며 판단 기준 중심으로 재작성된다"
    - "Iron Laws가 NO X WITHOUT Y 형식으로 명시된다"
  artifacts:
    - ".hxsk/skills/bootstrap/SKILL.md 업데이트 (description 변경)"
    - ".hxsk/skills/commit/SKILL.md 업데이트"
    - ".hxsk/skills/create-pr/SKILL.md 업데이트"
    - ".hxsk/skills/write-report/SKILL.md 업데이트"
  key_links:
    - "각 스킬의 description이 trigger 키워드와 의미적으로 일치"
    - "Iron Laws가 본문의 핵심 제약과 연결"

cross_phase_invariants:
  inherit:
    - "metrics.py 변경 시 기존 함수 시그니처(example, prediction, trace) 보존"
    - "새 함수는 순수 텍스트 분석만 수행 — LLM 호출 없음, 외부 의존성 없음"
    - "signatures.py의 OutputField float 값은 0~1 범위 기대값임을 desc에 명시"
    - "dry-run 결과는 반드시 /tmp/skill-opt-*.txt에 tee로 저장 후 검토"
  new:
    - "--apply 실행 전 반드시 dry-run 결과를 사용자가 확인 (NO APPLY WITHOUT REVIEW)"
    - "각 스킬 적용 후 /skill-testing 검증 없이 다음 스킬 진행 금지"
---

# Plan 10.3A: MEDIUM 4개 스킬 순차 적용 및 검증

<objective>
bootstrap, commit, create-pr, write-report 4개 스킬을 optimize --apply로 업데이트한다.
각 적용 후 /skill-testing으로 행동 변화를 확인하고, 완료 후 단일 커밋한다.

Purpose: 가장 CSO 위반이 심각한 4개 스킬의 description을 자동 최적화하여 에이전트 발동률을 높인다.
Output: 4개 SKILL.md 업데이트 + /skill-testing 검증 통과 + 커밋.
</objective>

<context>
Load for context:
- .hxsk/tools/skill-doc-optimizer/optimize.py
- 2A의 dry-run 결과: /tmp/skill-opt-medium-27b.txt
</context>

<tasks>

<task type="auto">
  <name>bootstrap + commit 스킬 적용</name>
  <files>
    .hxsk/skills/bootstrap/SKILL.md
    .hxsk/skills/commit/SKILL.md
  </files>
  <action>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate

    # 2A dry-run 결과 확인 후 적용
    echo "=== bootstrap 적용 ===" && \
    python3 optimize.py --skill bootstrap --apply --model qwen-27b

    echo "=== commit 적용 ===" && \
    python3 optimize.py --skill commit --apply --model qwen-27b

    # 적용 결과 확인
    head -5 ../../.hxsk/skills/bootstrap/SKILL.md
    head -5 ../../.hxsk/skills/commit/SKILL.md

    AVOID: --all 플래그 사용 금지 — HIGH 스킬까지 일괄 변경되면 의도치 않은 행동 변화 발생
    AVOID: 두 스킬을 동시에 병렬 적용하면 optimize.py가 동일 파일을 동시에 쓸 위험 없지만
           결과 검증이 어려움 — 순차 실행
  </action>
  <verify>
    grep "^description:" /Users/sukbeom/Desktop/Hexoskeleton/.hxsk/skills/bootstrap/SKILL.md
    grep "^description:" /Users/sukbeom/Desktop/Hexoskeleton/.hxsk/skills/commit/SKILL.md
    # 두 description 모두 "Use when" 또는 동등한 트리거 패턴을 포함해야 함
  </verify>
  <done>
    bootstrap description: "Use when..." 또는 "When..." 패턴 포함.
    commit description: "Use when..." 또는 "When..." 패턴 포함.
    두 파일 모두 git diff에서 변경사항 확인됨.
  </done>
</task>

<task type="checkpoint:human-verify">
  <name>bootstrap + commit 행동 변화 검증 (사용자 확인)</name>
  <files></files>
  <action>
    Claude Code에서 다음 명령으로 각 스킬 동작 확인:
      /skill-testing -- bootstrap
      /skill-testing -- commit

    확인 기준:
    1. 스킬이 의도한 상황에서 발동되는가?
    2. Quick Reference가 5줄 이하인가?
    3. Iron Laws가 존재하는가?
    4. description이 행동 변화를 일으키는가?

    문제 발생 시: git checkout .hxsk/skills/bootstrap/SKILL.md 또는 commit/SKILL.md로 롤백
  </action>
  <verify>사용자 확인 완료</verify>
  <done>bootstrap + commit 스킬 검증 통과 또는 롤백 결정.</done>
</task>

<task type="auto">
  <name>create-pr + write-report 스킬 적용 및 최종 커밋</name>
  <files>
    .hxsk/skills/create-pr/SKILL.md
    .hxsk/skills/write-report/SKILL.md
  </files>
  <action>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate

    python3 optimize.py --skill create-pr --apply --model qwen-27b
    python3 optimize.py --skill write-report --apply --model qwen-27b

    # 4개 스킬 최종 확인
    for skill in bootstrap commit create-pr write-report; do
      echo "=== $skill ===" && \
      grep "^description:" \
        /Users/sukbeom/Desktop/Hexoskeleton/.hxsk/skills/$skill/SKILL.md
    done

    # /skill-testing 검증 후 커밋
    # (skill-testing은 사용자가 Claude Code에서 실행)
  </action>
  <verify>
    git -C /Users/sukbeom/Desktop/Hexoskeleton diff --name-only | \
      grep -E "bootstrap|commit|create-pr|write-report"
    # 4개 파일 모두 변경됨
  </verify>
  <done>
    create-pr, write-report description이 트리거 조건 패턴 포함.
    git diff에서 4개 파일 모두 확인.
    /skill-testing 검증 완료 후 /commit으로 단일 커밋.
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] 4개 SKILL.md 모두 description 변경됨
- [ ] 각 description이 "Use when..." 트리거 조건 포함
- [ ] /skill-testing으로 행동 변화 확인
- [ ] git diff로 변경 파일 4개 확인
- [ ] 커밋 완료
</verification>

<success_criteria>
- [ ] MEDIUM 4개 스킬 모두 CSO 패턴으로 업데이트
- [ ] /skill-testing 전수 통과
- [ ] atomic commit 1개
</success_criteria>
