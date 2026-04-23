---
phase: 10
plan: "1B"
wave: 1
depends_on: []
files_modified:
  - .hxsk/tools/skill-doc-optimizer/signatures.py
autonomous: true
user_setup: []

must_haves:
  truths:
    - "DescriptionOptimizer가 answerability_score, specificity_score를 OutputField로 선언한다"
    - "Signature docstring에 Watson et al. 근거가 명시되어 있어 모델이 평가 기준을 이해한다"
    - "기존 OutputField(optimized_description, change_reason)는 유지된다"
  artifacts:
    - "DescriptionOptimizer에 answerability_score: float, specificity_score: float OutputField 존재"
    - "python3 -c 'from signatures import DescriptionOptimizer' 오류 없음"
  key_links:
    - "DescriptionOptimizer의 OutputField가 metrics.py의 answerability_score() 평가 기준과 일치"

cross_phase_invariants:
  inherit:
    - "metrics.py 변경 시 기존 함수 시그니처(example, prediction, trace) 보존"
    - "새 함수는 순수 텍스트 분석만 수행 — LLM 호출 없음, 외부 의존성 없음"
  new:
    - "signatures.py의 OutputField float 값은 0~1 범위 기대값임을 desc에 명시"
---

# Plan 10.1B: signatures.py DescriptionOptimizer 언어 품질 OutputField 추가

<objective>
DSPy DescriptionOptimizer가 description을 생성할 때 answerability와 specificity를 자가 평가하게 한다.
BootstrapFewShot이 높은 품질 점수를 가진 예시를 few-shot으로 선택하도록 signal을 추가한다.

Purpose: 현재 DescriptionOptimizer는 최적화된 description만 반환하고 품질 자가 평가가 없음.
Output: answerability_score, specificity_score OutputField가 추가된 DescriptionOptimizer.
</objective>

<context>
Load for context:
- .hxsk/tools/skill-doc-optimizer/signatures.py (수정 대상)
- .hxsk/research/2026-04-23-hallucination-linguistic-features.md (OR 수치 참조)
</context>

<tasks>

<task type="auto">
  <name>DescriptionOptimizer에 언어 품질 OutputField 2개 추가</name>
  <files>.hxsk/tools/skill-doc-optimizer/signatures.py</files>
  <action>
    DescriptionOptimizer 클래스에 다음을 적용한다:

    1. docstring 업데이트 — Watson et al. 평가 기준 명시:
    기존 CSO 원칙 목록 하단에 추가:
    """
    Watson et al. 2026 (arXiv:2602.20300) 언어 품질 기준:
    - Answerability (OR=0.331): 스킬을 언제 쓸지 명확히 판단 가능해야 함
    - Specificity (OR=2.382 역방향): "generally", "typically" 같은 모호한 표현 금지
    - Intention Grounding (OR=0.846): what/when/why 세 축이 명시되어야 함
    """

    2. OutputField 2개 추가 (기존 change_reason 다음에):
    answerability_score: float = dspy.OutputField(
        desc="생성된 description의 답변 가능성 점수 (0.0~1.0). "
             "Watson et al. OR=0.331 기준. 1.0에 가까울수록 트리거 조건이 명확."
    )
    specificity_score: float = dspy.OutputField(
        desc="생성된 description의 구체성 점수 (0.0~1.0). "
             "Watson et al. OR=2.382 역방향. 1.0에 가까울수록 모호한 표현이 없음."
    )

    AVOID: IronLawsSynthesizer, TriggerExpander, QuickReferenceRefiner에는 추가하지 않음
           — DescriptionOptimizer만 수정 대상
    AVOID: OutputField 타입을 str로 선언하면 DSPy ChainOfThought가 float 파싱 실패 가능
           — float으로 선언하되 desc에 "0.0~1.0" 범위 명시
  </action>
  <verify>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate
    python3 -c "
    from signatures import DescriptionOptimizer
    import dspy
    fields = DescriptionOptimizer.output_fields()
    print('OutputFields:', list(fields.keys()))
    assert 'answerability_score' in fields, 'answerability_score 없음'
    assert 'specificity_score' in fields, 'specificity_score 없음'
    assert 'optimized_description' in fields, 'optimized_description 제거됨 (오류)'
    assert 'change_reason' in fields, 'change_reason 제거됨 (오류)'
    print('OK: 모든 OutputField 확인')
    "
  </verify>
  <done>
    DescriptionOptimizer.output_fields()에 answerability_score, specificity_score, optimized_description, change_reason 4개 모두 존재.
    기존 OutputField는 제거되지 않음.
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] `from signatures import DescriptionOptimizer` 오류 없음
- [ ] output_fields에 4개 모두 존재
- [ ] docstring에 Watson et al. 언급 포함
</verification>

<success_criteria>
- [ ] DescriptionOptimizer에 언어 품질 OutputField 2개 추가
- [ ] 기존 3개 Signature 미변경
</success_criteria>
