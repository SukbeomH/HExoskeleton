import dspy


class DescriptionOptimizer(dspy.Signature):
    """HXSK 스킬의 description 필드를 CSO 원칙에 따라 최적화한다.

    CSO 원칙:
    - 에이전트가 "언제 이 스킬을 써야 하는가"만 포함
    - 워크플로우 요약, 방법론 이름, 기능 목록 제외
    - 50 토큰 이하
    - "Use when ..." 또는 동등한 트리거 패턴 사용

    Watson et al. 2026 (arXiv:2602.20300) 언어 품질 기준:
    - Answerability (OR=0.331): 언제 쓸지 명확히 판단 가능해야 함
    - Specificity (OR=2.382 역방향): "generally", "typically" 같은 모호 표현 금지
    - Intention Grounding (OR=0.846): what/when/why 세 축이 명시되어야 함
    """

    skill_name: str = dspy.InputField(desc="스킬 이름")
    skill_body: str = dspy.InputField(desc="Quick Reference 이후 SKILL.md 본문 전체")
    current_description: str = dspy.InputField(desc="현재 description 값")
    cso_bad_examples: str = dspy.InputField(
        desc="피해야 할 description 패턴 (방법론 요약, 기능 나열 등)"
    )

    optimized_description: str = dspy.OutputField(desc="CSO 최적화된 description. 50 토큰 이하.")
    change_reason: str = dspy.OutputField(desc="기존 대비 개선된 이유 (1줄)")
    answerability_score: float = dspy.OutputField(
        desc="생성된 description의 답변 가능성 점수 (0.0~1.0). "
             "Watson et al. OR=0.331 기준. 1.0에 가까울수록 트리거 조건 명확."
    )
    specificity_score: float = dspy.OutputField(
        desc="생성된 description의 구체성 점수 (0.0~1.0). "
             "Watson et al. OR=2.382 역방향. 1.0에 가까울수록 모호 표현 없음."
    )


class TriggerExpander(dspy.Signature):
    """스킬 본문을 분석해 누락된 트리거 키워드를 추가한다.

    트리거는 에이전트가 스킬을 소환할 때 사용하는 자연어 표현이다.
    한국어 + 영어 혼합, 동의어·변형 표현 포함.
    """

    skill_name: str = dspy.InputField()
    skill_body: str = dspy.InputField()
    current_triggers: str = dspy.InputField(desc="현재 trigger 필드 값 (쉼표 구분)")

    expanded_triggers: str = dspy.OutputField(
        desc="확장된 trigger 목록. 쉼표 구분. 기존 포함, 신규 추가."
    )
    added_patterns: str = dspy.OutputField(desc="새로 추가된 패턴과 이유 (1줄씩)")


class QuickReferenceRefiner(dspy.Signature):
    """SKILL.md 본문에서 5줄 이하 Quick Reference를 생성·개선한다.

    Quick Reference 작성 기준:
    - 핵심 결정 지점(언제 멈출지, 무엇을 반드시 할지)만 포함
    - 절차 단계 요약이 아닌 판단 기준
    - 각 항목은 볼드 키워드: 설명 형식
    - 5줄 초과 금지
    """

    skill_name: str = dspy.InputField()
    skill_body: str = dspy.InputField(desc="SKILL.md 전체 본문")
    current_quick_ref: str = dspy.InputField(desc="현재 Quick Reference 내용")

    refined_quick_ref: str = dspy.OutputField(desc="개선된 Quick Reference. 마크다운 불릿. 5줄 이하.")
    removed_items: str = dspy.OutputField(desc="제거된 항목과 제거 이유")


class IronLawsSynthesizer(dspy.Signature):
    """스킬 본문에서 Iron Laws를 추출하고 명시적으로 선언한다.

    Iron Laws 형식: NO {action} WITHOUT {precondition} FIRST
    예시:
    - NO EDIT WITHOUT READ FIRST
    - NO COMPLETION WITHOUT VERIFICATION
    - NO PLAN WITHOUT SPEC.md

    본문에 암시되어 있으나 선언되지 않은 제약을 발굴한다.
    """

    skill_name: str = dspy.InputField()
    skill_body: str = dspy.InputField()
    existing_iron_laws: str = dspy.InputField(desc="이미 선언된 Iron Laws (없으면 빈 문자열)")

    iron_laws: str = dspy.OutputField(desc="NO X WITHOUT Y 형식 Iron Laws 목록 (줄바꿈 구분)")
    newly_discovered: str = dspy.OutputField(desc="본문에서 새로 발굴한 제약과 근거")
