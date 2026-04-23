def description_metric(example, prediction, trace=None) -> float:
    """
    CSO 준수 여부를 0~1로 평가.

    기준:
    1. 토큰 수 ≤ 50          (0.3점)
    2. 트리거 조건 포함        (0.4점) — "Use when", "when", "before", "after" 패턴
    3. 방법론 이름 미포함      (0.3점) — 스킬 이름 반복, "workflow", "methodology" 등
    """
    desc = prediction.optimized_description
    tokens = len(desc.split())

    score = 0.0
    if tokens <= 50:
        score += 0.3
    elif tokens <= 70:
        score += 0.15

    trigger_patterns = ["use when", "when ", "before ", "after ", "triggers on"]
    if any(p in desc.lower() for p in trigger_patterns):
        score += 0.4

    bad_patterns = ["methodology", "workflow", "management", "system", "framework"]
    if not any(p in desc.lower() for p in bad_patterns):
        score += 0.3

    return score


def quick_ref_metric(example, prediction, trace=None) -> float:
    """
    Quick Reference 품질 0~1 평가.

    기준:
    1. 5줄 이하              (0.4점)
    2. 볼드 키워드 포함       (0.3점) — **keyword**: 패턴
    3. 절차 동사 미사용       (0.3점) — "Run", "Execute", "Step" 등
    """
    qr = prediction.refined_quick_ref
    lines = [l for l in qr.strip().split("\n") if l.strip()]

    score = 0.0
    if len(lines) <= 5:
        score += 0.4

    bold_count = sum(1 for l in lines if "**" in l and ":**" in l)
    if bold_count >= len(lines) * 0.6:
        score += 0.3

    procedure_verbs = ["run ", "execute ", "step ", "first,", "then,", "next,"]
    if not any(v in qr.lower() for v in procedure_verbs):
        score += 0.3

    return score


def answerability_score(text: str) -> float:
    """답변 가능성 점수 — Watson et al. OR=0.331 (β=-1.106) 보호 특성."""
    words = text.lower().split()
    if not words:
        return 0.0

    # 구체적 트리거 조건 신호
    trigger_phrases = [
        "use when", "when ", "before ", "after ", "if ",
        "spec.md", "plan.md", "tests fail", "bug", "error",
        "exists", "needed", "required", "encountered",
        "발생", "존재", "필요", "실패", "오류",
    ]
    text_lower = text.lower()
    trigger_count = sum(1 for p in trigger_phrases if p in text_lower)
    score = min(1.0, trigger_count / 3.0)
    return score


def specificity_score(text: str) -> float:
    """구체성 점수 — Watson et al. OR=2.382 (β=+0.868) 역방향 (높을수록 위험 낮음)."""
    words = text.lower().split()
    if not words:
        return 1.0

    vague_words = {
        "generally", "typically", "usually", "some", "various",
        "certain", "may", "might", "could", "often", "sometimes",
        "일반적으로", "보통", "때로는", "경우에 따라", "주로",
        "often", "frequently", "occasionally", "possibly", "perhaps",
    }
    vague_count = sum(1 for w in words if w.rstrip(".,") in vague_words)
    penalty = min(1.0, vague_count / max(len(words) * 0.1, 1))
    return max(0.0, 1.0 - penalty)


def intention_grounding_score(text: str) -> float:
    """의도 명시 점수 — Watson et al. OR=0.846 (β=-0.168) 보호 특성."""
    text_lower = text.lower()
    score = 0.0

    # when: 트리거 조건 명시
    when_signals = ["use when", "when ", "before ", "after ", "if "]
    if any(p in text_lower for p in when_signals):
        score += 0.4

    # what: 동사+목적어 구조 (출력/결과 명시)
    what_signals = ["creates", "generates", "produces", "returns", "outputs",
                    "생성", "반환", "출력", "작성", "분석"]
    if any(p in text_lower for p in what_signals):
        score += 0.3

    # why: 목적 명시
    why_signals = ["to ", "for ", "so that", "in order", "위해", "하여", "하도록"]
    if any(p in text_lower for p in why_signals):
        score += 0.3

    return min(1.0, score)


def composite_hallucination_risk(text: str) -> float:
    """Watson et al. 2026 β 계수 기반 환각 위험 지수 (0=저위험, 1=고위험).

    공식:
      raw = 0.868 × lack_specificity - 1.106 × answerability - 0.168 × intention
      정규화 범위: [-1.274, +0.868] → [0, 1]
    """
    ans = answerability_score(text)
    spec = specificity_score(text)
    intent = intention_grounding_score(text)
    lack_spec = 1.0 - spec

    raw = 0.868 * lack_spec - 1.106 * ans - 0.168 * intent
    # raw 범위: 최저 = -1.106 - 0.168 = -1.274, 최고 = +0.868
    normalized = (raw + 1.274) / (0.868 + 1.274)
    return min(1.0, max(0.0, normalized))


def combined_metric(example, prediction, trace=None) -> float:
    """description + quick_ref 품질 + 환각 위험 패널티 가중 평균.

    가중치: desc 0.4 + qr 0.4 + risk_bonus 0.2
    risk=0(저위험) → +0.2, risk=1(고위험) → 0
    """
    desc = prediction.optimized_description
    risk = composite_hallucination_risk(desc)
    return (
        description_metric(example, prediction, trace) * 0.4
        + quick_ref_metric(example, prediction, trace) * 0.4
        + (1.0 - risk) * 0.2
    )
