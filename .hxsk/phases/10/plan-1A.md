---
phase: 10
plan: "1A"
wave: 1
depends_on: []
files_modified:
  - .hxsk/tools/skill-doc-optimizer/metrics.py
autonomous: true
user_setup: []

must_haves:
  truths:
    - "answerability_score(), specificity_score(), intention_grounding_score() 세 함수가 metrics.py에 존재하고 0~1 float을 반환한다"
    - "composite_hallucination_risk()가 Watson et al. 2026 β 계수(OR 기반)를 가중치로 사용한다"
    - "combined_metric()이 risk_penalty(0.2 가중) 항을 포함하여 환각 위험이 높은 description을 불이익 처리한다"
    - "기존 description_metric(), quick_ref_metric() 함수는 시그니처 변경 없이 유지된다"
  artifacts:
    - ".hxsk/tools/skill-doc-optimizer/metrics.py에 4개 신규 함수 존재"
    - "python3 -c 'from metrics import composite_hallucination_risk; print(composite_hallucination_risk(\"Use when X\"))' 정상 실행"
  key_links:
    - "combined_metric이 description_metric*0.4 + quick_ref_metric*0.4 + (-risk_penalty)*0.2 구조"
    - "composite_hallucination_risk가 answerability_score, specificity_score, intention_grounding_score를 호출"

cross_phase_invariants:
  inherit: []
  new:
    - "metrics.py 변경 시 기존 함수 시그니처(example, prediction, trace) 보존"
    - "새 함수는 순수 텍스트 분석만 수행 — LLM 호출 없음, 외부 의존성 없음"
---

# Plan 10.1A: metrics.py Watson et al. 언어 품질 지표 추가

<objective>
Watson et al. 2026 (arXiv:2602.20300) 의 Odds Ratio 수치를 DSPy combined_metric에 직접 통합한다.
환각 위험이 높은 description(특이성 부족·의도 불명확)을 BootstrapFewShot이 few-shot으로 선택하지 않도록 패널티를 부여한다.

Purpose: 현재 combined_metric은 CSO 형식(토큰 수, 트리거 패턴, 금지어)만 평가하고 언어 품질은 측정하지 않음.
Output: Watson et al. 검증 수치 기반의 composite_hallucination_risk 함수 + 업데이트된 combined_metric.
</objective>

<context>
Load for context:
- .hxsk/tools/skill-doc-optimizer/metrics.py (수정 대상)
- .hxsk/research/2026-04-23-hallucination-linguistic-features.md (Watson et al. β 계수 참조)
</context>

<tasks>

<task type="auto">
  <name>answerability / specificity / intention_grounding 측정 함수 추가</name>
  <files>.hxsk/tools/skill-doc-optimizer/metrics.py</files>
  <action>
    파일 맨 아래에 다음 3개 함수를 추가한다.
    LLM 호출 없이 정규식·단어 목록 기반 휴리스틱으로 구현한다.

    1. answerability_score(text: str) -> float
       - Watson et al. OR=0.331 (β=-1.106) — 최강 보호 특성
       - 측정 방법: "use when", "when ", "before ", "after ", "if " + 구체적 조건명사
         (SPEC.md, PLAN.md, tests fail, bug, error 등)의 밀도
       - 구체적 조건절 수 / 전체 단어 수로 정규화, 0~1 클램핑

    2. specificity_score(text: str) -> float
       - Watson et al. OR=2.382 (β=+0.868) — 최강 위험 특성 (역방향: 높을수록 위험 낮음)
       - 위험 신호 단어: ["generally", "typically", "usually", "some", "various",
         "certain", "may", "might", "could", "often", "sometimes",
         "일반적으로", "보통", "때로는", "경우에 따라"]
       - score = 1.0 - (위험 단어 수 / 전체 단어 수)의 정규화 값

    3. intention_grounding_score(text: str) -> float
       - Watson et al. OR=0.846 (β=-0.168) — 보호 특성
       - what(출력/결과 명시) + when(조건 명시) + why(목적 명시) 세 축 평가
       - when: trigger 패턴 포함 여부 (0/0.4)
       - what: 동사 + 명사 목적어 구조 포함 여부 (0/0.3)
       - why: "to ", "for ", "so that", "위해" 포함 여부 (0/0.3)
       - 합산 0~1

    AVOID: re 모듈 대신 단순 str.lower().split() 활용 — 단어 경계 처리가 충분함
    AVOID: 점수를 0~1 범위로 clip하지 않으면 combined_metric이 1 초과 가능 — 반드시 min(1.0, max(0.0, ...)) 적용
  </action>
  <verify>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate
    python3 -c "
    from metrics import answerability_score, specificity_score, intention_grounding_score
    good = 'Use when SPEC.md exists and tasks need decomposing into 2-3 atomic steps'
    bad  = 'Generally useful for various task management scenarios'
    print('good answerability:', answerability_score(good))
    print('bad  answerability:', answerability_score(bad))
    print('good specificity:  ', specificity_score(good))
    print('bad  specificity:  ', specificity_score(bad))
    print('good intention:    ', intention_grounding_score(good))
    "
    기대값: good > bad (answerability, specificity 모두)
  </verify>
  <done>
    good description의 answerability_score > bad의 answerability_score.
    good description의 specificity_score > bad의 specificity_score.
    모든 점수가 0.0~1.0 범위 내.
  </done>
</task>

<task type="auto">
  <name>composite_hallucination_risk 추가 + combined_metric 업데이트</name>
  <files>.hxsk/tools/skill-doc-optimizer/metrics.py</files>
  <action>
    composite_hallucination_risk(text: str) -> float 함수 추가:

    Watson et al. Table 1 β 계수 가중치 적용:
      risk = (0.868 × lack_specificity)   # OR=2.382, 위험 증가
           - (1.106 × answerability)       # OR=0.331, 위험 감소
           - (0.168 × intention_grounding) # OR=0.846, 위험 감소
    여기서:
      lack_specificity = 1.0 - specificity_score(text)
      answerability    = answerability_score(text)
      intention_grounding = intention_grounding_score(text)

    raw_risk = 0.868*(1-spec) - 1.106*ans - 0.168*intent
    # raw_risk 범위: 약 -1.274(최저위험) ~ +0.868(최고위험)
    # 0~1 정규화: (raw_risk + 1.274) / (0.868 + 1.274)
    반환값: min(1.0, max(0.0, 정규화된 값))

    combined_metric 업데이트:
      기존: desc_metric*0.5 + qr_metric*0.5
      변경: desc_metric*0.4 + qr_metric*0.4 + (1 - risk)*0.2
      # risk=0(저위험) → +0.2 보너스, risk=1(고위험) → 0 보너스

    AVOID: composite_hallucination_risk를 prediction 객체가 아닌 text str로 호출해야 함
           combined_metric에서는 prediction.optimized_description 추출 후 전달
  </action>
  <verify>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate
    python3 -c "
    from metrics import composite_hallucination_risk, combined_metric
    import types
    good_text = 'Use when SPEC.md exists and tasks need decomposing into 2-3 atomic steps'
    bad_text  = 'Generally manages various task planning scenarios'
    print('good risk:', composite_hallucination_risk(good_text))
    print('bad  risk:', composite_hallucination_risk(bad_text))

    # combined_metric 더미 테스트
    class FakePred:
        optimized_description = good_text
        refined_quick_ref = '- **Stop**: context 50% 초과 시\n- **Check**: SPEC.md 존재 여부'
    ex = types.SimpleNamespace()
    print('combined(good):', combined_metric(ex, FakePred()))
    "
  </verify>
  <done>
    bad_text의 risk > good_text의 risk.
    combined_metric이 0.0~1.0 범위의 float을 반환.
    기존 description_metric(), quick_ref_metric() 단독 호출도 정상 동작.
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] `python3 -c 'from metrics import composite_hallucination_risk'` 오류 없음
- [ ] good description risk < bad description risk
- [ ] combined_metric 반환값 0~1 범위
- [ ] 기존 함수 시그니처 변경 없음 (description_metric, quick_ref_metric)
</verification>

<success_criteria>
- [ ] 4개 신규 함수 모두 정상 동작
- [ ] combined_metric이 risk penalty 포함
- [ ] LLM 호출 없이 순수 Python으로 동작
</success_criteria>
