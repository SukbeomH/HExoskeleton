---
phase: 10
plan: "2A"
wave: 2
depends_on: ["10.1A", "10.1B"]
files_modified: []
autonomous: true
user_setup: []

must_haves:
  truths:
    - "planner 스킬 dry-run이 risk score를 출력한다"
    - "qwen-27b와 qwen-122b 결과가 비교된다"
    - "MEDIUM 4개 스킬 dry-run이 실행되어 개선 폭이 확인된다"
  artifacts:
    - "/tmp/skill-opt-validation.txt에 전체 결과 기록"
    - "qwen-27b vs qwen-122b 비교 결과"
  key_links:
    - "composite_hallucination_risk가 dry-run 출력에 반영됨"

cross_phase_invariants:
  inherit:
    - "metrics.py 변경 시 기존 함수 시그니처(example, prediction, trace) 보존"
    - "새 함수는 순수 텍스트 분석만 수행 — LLM 호출 없음, 외부 의존성 없음"
    - "signatures.py의 OutputField float 값은 0~1 범위 기대값임을 desc에 명시"
  new:
    - "dry-run 결과는 반드시 /tmp/skill-opt-*.txt에 tee로 저장 후 검토"
---

# Plan 10.2A: 업데이트된 메트릭으로 검증 실행

<objective>
1A + 1B에서 강화된 metrics/signatures로 planner와 MEDIUM 4개 스킬을 dry-run한다.
qwen-27b vs qwen-122b 결과를 비교하여 기본 모델을 결정한다.

Purpose: 변경된 코드가 실제 Qwen API 호출에서 정상 동작하는지 확인하고, 122B 투자 가치를 실증적으로 판단한다.
Output: 검증 결과 텍스트 파일 + 모델 선택 결정.
</objective>

<context>
Load for context:
- .hxsk/tools/skill-doc-optimizer/optimize.py
- .hxsk/tools/skill-doc-optimizer/metrics.py (1A에서 수정됨)
- .hxsk/tools/skill-doc-optimizer/signatures.py (1B에서 수정됨)
</context>

<tasks>

<task type="auto">
  <name>planner dry-run (27B) + risk score 출력 확인</name>
  <files></files>
  <action>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate

    # 27B로 planner dry-run
    python3 optimize.py --skill planner --dry-run --model qwen-27b \
      2>&1 | tee /tmp/skill-opt-planner-27b.txt

    출력에서 확인할 것:
    - answerability_score, specificity_score 필드가 출력되는지
    - composite_hallucination_risk 수치 (간접: combined_metric 수치 비교)
    - 기존 결과 대비 description 품질 변화

    AVOID: --apply 플래그 사용 금지 (검증 단계에서 파일 변경 없음)
  </action>
  <verify>
    grep -c "After\|optimized_description\|answerability" /tmp/skill-opt-planner-27b.txt
    cat /tmp/skill-opt-planner-27b.txt | grep -A2 "\[description\]"
  </verify>
  <done>
    /tmp/skill-opt-planner-27b.txt 존재하고 비어있지 않음.
    [description] 섹션에 Before/After 출력됨.
    오류 없이 완료됨.
  </done>
</task>

<task type="auto">
  <name>MEDIUM 4개 스킬 dry-run + 27B vs 122B 비교</name>
  <files></files>
  <action>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate

    # MEDIUM 4개 스킬 27B dry-run
    for skill in bootstrap commit create-pr write-report; do
      echo "===== $skill (27B) =====" >> /tmp/skill-opt-medium-27b.txt
      python3 optimize.py --skill $skill --dry-run --model qwen-27b \
        2>&1 >> /tmp/skill-opt-medium-27b.txt
    done

    # 122B로 planner 비교 실행 (비용 비교용 단일 스킬)
    python3 optimize.py --skill bootstrap --dry-run --model qwen-122b \
      2>&1 | tee /tmp/skill-opt-bootstrap-122b.txt

    비교 기준:
    - description After 문장의 구체성·명확성
    - Iron Laws 발굴 수
    - 실행 시간 차이

    AVOID: 122B로 전체 실행 금지 (컨텍스트 65K이지만 비용이 더 높음)
           — bootstrap 단일 스킬로 비교 충분
  </action>
  <verify>
    wc -l /tmp/skill-opt-medium-27b.txt
    diff <(grep "After:" /tmp/skill-opt-medium-27b.txt) \
         <(grep "After:" /tmp/skill-opt-bootstrap-122b.txt) || true
    echo "27B 결과:"
    grep "After:" /tmp/skill-opt-medium-27b.txt | head -4
    echo "122B bootstrap 결과:"
    grep "After:" /tmp/skill-opt-bootstrap-122b.txt | head -2
  </verify>
  <done>
    MEDIUM 4개 스킬 모두 dry-run 완료.
    27B와 122B bootstrap 결과 모두 /tmp에 저장됨.

    checkpoint:decision — 비교 결과를 보고 사용자가 기본 모델을 결정:
    - 품질 차이 없으면 27B 유지 (DEFAULT_LM=qwen-27b)
    - 122B가 명확히 우세하면 .env의 DEFAULT_LM=qwen-122b로 변경
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] /tmp/skill-opt-planner-27b.txt 존재
- [ ] /tmp/skill-opt-medium-27b.txt에 4개 스킬 결과 모두 포함
- [ ] /tmp/skill-opt-bootstrap-122b.txt 존재
- [ ] 오류 메시지 없음 (ERROR: 패턴 없음)
</verification>

<success_criteria>
- [ ] 5개 dry-run 결과 파일 생성
- [ ] 모델 선택 결정 완료 (사용자 checkpoint)
</success_criteria>
