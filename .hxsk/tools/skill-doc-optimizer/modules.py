import dspy
from signatures import (
    DescriptionOptimizer, TriggerExpander,
    QuickReferenceRefiner, IronLawsSynthesizer,
)


def _safe_float(val, fallback=0.5):
    """LLM이 '0.85 (높음)' 같은 형식으로 반환할 때 첫 토큰만 float으로 변환한다.

    DSPy OutputField(float) 선언에도 불구하고 LLM이 텍스트를 덧붙이는 경우
    ValueError 없이 fallback 값을 반환해 파이프라인을 계속 진행시킨다.
    """
    try:
        return float(str(val).split()[0])
    except (ValueError, TypeError):
        return fallback


CSO_BAD_EXAMPLES = """
Bad (방법론 요약): "Task planning and execution workflow management using goal-backward methodology"
Bad (기능 나열): "Creates PLAN.md with tasks, waves, dependencies, and verification steps"
Bad (이름 반복): "Planner skill for planning tasks and creating implementation plans"
Good (트리거 조건): "Use when SPEC.md exists and tasks need decomposing into 2-3 atomic steps with verification criteria"
Good (컨텍스트 명시): "Use when encountering bugs before proposing fixes, or when 3+ attempts have failed"
"""


class SkillDocOptimizer(dspy.Module):
    """SKILL.md 문서의 텍스트 필드 전체를 최적화하는 파이프라인."""

    def __init__(self):
        self.desc_opt = dspy.ChainOfThought(DescriptionOptimizer)
        self.trigger_exp = dspy.ChainOfThought(TriggerExpander)
        self.qr_ref = dspy.ChainOfThought(QuickReferenceRefiner)
        self.iron_syn = dspy.ChainOfThought(IronLawsSynthesizer)

    def forward(self, skill_name: str, skill_body: str, frontmatter: dict) -> dspy.Prediction:
        current_desc = frontmatter.get("description", "")
        current_trigger = frontmatter.get("trigger", "")
        current_qr = self._extract_quick_ref(skill_body)
        current_iron = self._extract_iron_laws(skill_body)

        desc_result = self.desc_opt(
            skill_name=skill_name,
            skill_body=skill_body,
            current_description=current_desc,
            cso_bad_examples=CSO_BAD_EXAMPLES,
        )
        trigger_result = self.trigger_exp(
            skill_name=skill_name,
            skill_body=skill_body,
            current_triggers=current_trigger,
        )
        qr_result = self.qr_ref(
            skill_name=skill_name,
            skill_body=skill_body,
            current_quick_ref=current_qr,
        )
        iron_result = self.iron_syn(
            skill_name=skill_name,
            skill_body=skill_body,
            existing_iron_laws=current_iron,
        )

        # LLM이 float 필드에 '0.85 (높음)' 같은 텍스트를 덧붙일 수 있으므로
        # _safe_float()으로 첫 토큰만 파싱한다. 파싱 실패 시 0.5 fallback.
        answerability = _safe_float(desc_result.answerability_score)
        specificity = _safe_float(desc_result.specificity_score)

        return dspy.Prediction(
            optimized_description=desc_result.optimized_description,
            expanded_triggers=trigger_result.expanded_triggers,
            refined_quick_ref=qr_result.refined_quick_ref,
            iron_laws=iron_result.iron_laws,
            answerability_score=answerability,
            specificity_score=specificity,
            changes={
                "description": desc_result.change_reason,
                "trigger": trigger_result.added_patterns,
                "quick_ref": qr_result.removed_items,
                "iron_laws": iron_result.newly_discovered,
            },
        )

    def _extract_quick_ref(self, body: str) -> str:
        lines = body.split("\n")
        in_qr = False
        result = []
        for line in lines:
            if line.strip() == "## Quick Reference":
                in_qr = True
                continue
            if in_qr and line.startswith("##"):
                break
            if in_qr:
                result.append(line)
        return "\n".join(result).strip()

    def _extract_iron_laws(self, body: str) -> str:
        lines = body.split("\n")
        laws = [line for line in lines if "NO " in line and " WITHOUT " in line]
        return "\n".join(laws)
