---
phase: 10
plan: "3B"
wave: 3
depends_on: ["10.3A"]
files_modified:
  - .hxsk/skills/bootstrap/SKILL.md
  - .hxsk/skills/commit/SKILL.md
  - .hxsk/skills/create-pr/SKILL.md
  - .hxsk/skills/write-report/SKILL.md
autonomous: false
user_setup: []

must_haves:
  truths:
    - "4개 스킬 모두 /skill-testing에서 의도 트리거로 발동된다"
    - "Iron Laws가 각 SKILL.md에 존재한다 (3A --apply에서 누락된 갭)"
    - "Quick Reference가 5줄 이하 판단 기준 중심이다"
    - "description이 Use when... 패턴이며 행동 변화를 일으킨다"
  artifacts:
    - "4개 SKILL.md에 ## Iron Laws 섹션 존재"
    - "각 스킬의 /skill-testing 검증 기록 (통과 또는 롤백 결정)"
  key_links:
    - "Iron Laws가 Quick Reference의 판단 기준과 일관성 있음"
    - "검증 통과 후 단일 커밋"

cross_phase_invariants:
  inherit:
    - "--apply 실행 전 반드시 dry-run 결과를 사용자가 확인 (NO APPLY WITHOUT REVIEW)"
    - "각 스킬 적용 후 /skill-testing 검증 없이 다음 스킬 진행 금지"
    - "metrics.py 변경 시 기존 함수 시그니처(example, prediction, trace) 보존"
    - "새 함수는 순수 텍스트 분석만 수행 — LLM 호출 없음, 외부 의존성 없음"
    - "signatures.py의 OutputField float 값은 0~1 범위 기대값임을 desc에 명시"
    - "dry-run 결과는 반드시 /tmp/skill-opt-*.txt에 tee로 저장 후 검토"
  new:
    - "Iron Laws 갭 발견 시 즉시 수동 보완 — optimize.py --apply가 Iron Laws를 파일에 기록하지 않는 버그"
    - "검증 실패 = git checkout 롤백 + 원인 기록 후 사용자 결정"
---

# Plan 10.3B: MEDIUM 4개 스킬 검증 + Iron Laws 갭 보완

<objective>
3A에서 --apply로 업데이트한 4개 스킬을 /skill-testing으로 검증한다.
optimize.py --apply가 Iron Laws를 파일에 쓰지 않는 갭을 발견 → 수동으로 보완한다.
검증 통과 후 단일 커밋으로 마무리한다.

Purpose: 스킬 description 변경이 실제 에이전트 발동 행동 변화로 이어지는지 확인한다.
Output: 4개 SKILL.md 검증 완료 + Iron Laws 삽입 + 커밋.
</objective>

<context>
Load for context:
- .hxsk/skills/bootstrap/SKILL.md (현재 상태)
- .hxsk/skills/commit/SKILL.md
- .hxsk/skills/create-pr/SKILL.md
- .hxsk/skills/write-report/SKILL.md
- /tmp/skill-opt-medium-27b.txt (3A dry-run 결과 — Iron Laws 원문 포함)
</context>

<tasks>

<task type="auto">
  <name>Iron Laws 갭 보완 — 4개 SKILL.md에 수동 삽입</name>
  <files>
    .hxsk/skills/bootstrap/SKILL.md
    .hxsk/skills/commit/SKILL.md
    .hxsk/skills/create-pr/SKILL.md
    .hxsk/skills/write-report/SKILL.md
  </files>
  <action>
    optimize.py --apply는 description/trigger/Quick Reference만 업데이트하고
    Iron Laws 섹션을 파일에 기록하지 않는다 (확인된 버그).
    dry-run 출력(/tmp/skill-opt-medium-27b.txt)에서 Iron Laws를 추출하여
    각 SKILL.md의 ## Quick Reference 직후에 ## Iron Laws 섹션을 삽입한다.

    삽입 위치: ## Quick Reference 블록 바로 다음, ## Procedure (또는 ## Usage) 이전.

    **bootstrap Iron Laws** (dry-run 출력 기준):
    ```
    ## Iron Laws
    - NO BOOTSTRAP EXECUTION WITHOUT STATE DETECTION FIRST
    - NO ENVIRONMENT SETUP WITHOUT PREREQUISITE VERIFICATION FIRST
    - NO PROCESS TERMINATION WITHOUT ERROR REPORTING FIRST
    - NO PROJECT READY DECLARATION WITHOUT FINAL STATUS REPORT FIRST
    - NO MEMORY STORAGE FAILURE WITHOUT CONTINUATION TO REPORTING FIRST
    ```

    **commit Iron Laws**:
    ```
    ## Iron Laws
    - NO COMMIT WITHOUT PRE-COMMIT CHECKS FIRST
    - NO COMMIT WITHOUT DIFF ANALYSIS FIRST
    - NO COMMIT WITHOUT CONVENTIONAL FORMAT FIRST
    - NO MERGED CHANGES WITHOUT LOGICAL SPLIT FIRST
    ```

    **create-pr Iron Laws**:
    ```
    ## Iron Laws
    - NO PR CREATION WITHOUT BRANCH CREATION FROM MAIN FIRST
    - NO PR CREATION WITHOUT PASSING SELF-QUALITY CHECKS FIRST
    - NO PR CREATION WITHOUT SPLITTING LARGE CHANGES (>1000 LINES) FIRST
    - NO PUSH WITHOUT RUNNING PRE-COMMIT CHECKS FIRST
    - NO MERGE WITHOUT PLAN-IMPLEMENTATION CONSISTENCY FIRST
    ```

    **write-report Iron Laws**:
    ```
    ## Iron Laws
    - NO EXECUTIVE SUMMARY WITHOUT CONCLUSION AND RECOMMENDATION FIRST
    - NO RISK ASSESSMENT WITHOUT STATUS QUO OPTION FIRST
    - NO VISUALIZATION WITHOUT SYMBOLS OR PATTERNS FIRST
    - NO COST ANALYSIS WITHOUT 3-5 YEAR TCO CALCULATION FIRST
    - NO EVALUATION CRITERIA WITHOUT MUST-HAVE VS NICE-TO-HAVE DISTINCTION FIRST
    - NO TECHNICAL TERM USAGE WITHOUT PLAIN LANGUAGE TRANSLATION FIRST
    - NO NEW REPORT WITHOUT MEMORY PATTERN RECALL FIRST
    ```

    AVOID: Quick Reference 내용 수정 — Iron Laws만 추가
    AVOID: 기존 섹션 헤더(## Procedure 등) 변경
  </action>
  <verify>
    for skill in bootstrap commit create-pr write-report; do
      echo -n "$skill: "
      grep -c "NO.*WITHOUT" /Users/sukbeom/Desktop/Hexoskeleton/.hxsk/skills/$skill/SKILL.md
    done
    # 각 스킬마다 4~7개의 Iron Law가 있어야 함
  </verify>
  <done>
    4개 SKILL.md 모두 ## Iron Laws 섹션 존재.
    각 스킬에 4개 이상의 NO X WITHOUT Y 규칙 포함.
  </done>
</task>

<task type="checkpoint:human-verify">
  <name>/skill-testing 행동 변화 검증 (사용자 확인)</name>
  <files></files>
  <action>
    Claude Code에서 각 스킬 실행:

    **검증 시나리오 (각 스킬별)**:

    ── bootstrap ──
    트리거 문장: "프로젝트 초기화해줘" / "bootstrap 실행해줘"
    기대 동작: /bootstrap 스킬 발동 → Step 0 모드 감지부터 시작
    합격 기준: description의 "detecting .hxsk/.bootstrap-version status" 조건이
              에이전트 첫 행동(파일 존재 확인)으로 반영됨

    ── commit ──
    트리거 문장: "변경사항 커밋해줘" / "git commit 만들어줘"
    기대 동작: /commit 스킬 발동 → diff 분석 후 conventional commit 생성
    합격 기준: "split mixed logical changes" 조건을 에이전트가 인식하여
              단일 커밋 vs 분할 커밋 여부를 판단함

    ── create-pr ──
    트리거 문장: "PR 만들어줘" / "풀 리퀘스트 올려줘"
    기대 동작: /create-pr 스킬 발동 → gh pr create 흐름 실행
    합격 기준: "local changes are ready" 조건 확인 후 진행
              (미완성 변경이 있으면 중단 또는 경고)

    ── write-report ──
    트리거 문장: "솔루션 비교 보고서 써줘" / "기술 선정 보고서 작성해"
    기대 동작: /write-report 스킬 발동 → 결론 우선 구조로 보고서 생성
    합격 기준: "3-5 solutions for executive decisions" 조건이
              먼저 해결책 수를 묻거나 명시된 솔루션부터 정리하는 행동으로 반영됨

    **공통 확인 기준** (4개 스킬 전부):
    1. [ ] 스킬이 의도한 트리거 문장에서 발동되는가?
    2. [ ] Quick Reference가 5줄 이하인가? (grep으로 확인 가능)
    3. [ ] Iron Laws 섹션이 에이전트 행동 제약으로 작동하는가?
    4. [ ] description의 "Use when..." 조건이 발동 판단에 영향을 주는가?

    **문제 발생 시 롤백**:
    git checkout .hxsk/skills/<skill>/SKILL.md
    (Iron Laws는 신규 추가이므로 롤백 시 제거됨)

    **검증 통과 기준**: 4개 중 4개 통과 → 커밋 진행
    **부분 실패**: 실패 스킬만 롤백 → 원인 기록 → Wave 4 이전 재적용 결정
  </action>
  <verify>사용자 확인 완료</verify>
  <done>
    4개 스킬 검증 결과 기록 (통과/롤백 각각 명시).
    통과한 스킬만 포함하여 커밋 진행.
  </done>
</task>

<task type="auto">
  <name>검증 통과 스킬 단일 커밋</name>
  <files>
    .hxsk/skills/bootstrap/SKILL.md
    .hxsk/skills/commit/SKILL.md
    .hxsk/skills/create-pr/SKILL.md
    .hxsk/skills/write-report/SKILL.md
  </files>
  <action>
    검증 통과한 스킬만 git add 후 단일 커밋:

    git add .hxsk/skills/bootstrap/SKILL.md \
            .hxsk/skills/commit/SKILL.md \
            .hxsk/skills/create-pr/SKILL.md \
            .hxsk/skills/write-report/SKILL.md

    git commit -m "feat(phase-10.3): MEDIUM 4개 스킬 CSO 패턴 + Iron Laws 적용

    - description: 'Use when...' 트리거 조건형으로 변환 (Watson et al. answerability 개선)
    - trigger: 키워드 확장 (27B 모델 최적화)
    - Quick Reference: 판단 기준 중심 5줄로 재작성
    - Iron Laws: NO X WITHOUT Y 형식 4~7개 추가 (optimize.py 갭 수동 보완)

    Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

    AVOID: 롤백된 스킬 파일 포함 금지
    AVOID: .hxsk/issues/ 파일과 함께 커밋 — 별도 커밋 또는 제외
  </action>
  <verify>
    git log --oneline -1
    git show --name-only HEAD | grep "SKILL.md"
    # 커밋 존재 + 변경된 SKILL.md 파일 목록 확인
  </verify>
  <done>
    커밋 해시 존재.
    커밋에 4개(또는 통과한) SKILL.md 파일 포함.
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] 4개 SKILL.md 모두 ## Iron Laws 섹션 존재 (grep "NO.*WITHOUT")
- [ ] /skill-testing 검증 결과 사용자 확인 완료
- [ ] 통과 스킬 커밋 완료 (git log)
- [ ] 롤백된 스킬 있으면 Failure Log에 기록
</verification>

<success_criteria>
- [ ] Iron Laws 갭 보완 완료 (4개 스킬)
- [ ] /skill-testing 4개 전수 통과 (또는 실패 스킬 롤백 + 기록)
- [ ] atomic commit 1개 완료
- [ ] Wave 4 (BootstrapFewShot) 진입 준비 완료
</success_criteria>
