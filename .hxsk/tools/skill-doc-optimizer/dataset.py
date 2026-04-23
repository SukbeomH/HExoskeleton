"""22개 기존 SKILL.md → DSPy Example 변환."""
from pathlib import Path
import yaml
import dspy

SKILLS_ROOT = Path(__file__).parent.parent.parent / "skills"

# CSO 기준으로 품질이 높다고 판단된 스킬 (positive examples)
# 기준: description이 "Use when..." 트리거 조건 패턴을 따르는 스킬
# 확정일: 2026-04-23 세션 검토
HIGH_QUALITY_SKILLS = {
    "debugger", "planner", "memory-protocol", "empirical-validation",
    "executor", "verifier", "impact-analysis", "arch-review", "clean",
    "codebase-mapper", "context-health-monitor", "dispatcher", "doc-lint",
    "handoff", "plan-checker", "pr-review", "refactor", "skill-testing",
}

# 개선 대상 (기능 나열/방법론 요약 혼입): bootstrap, commit, create-pr, write-report


def load_examples() -> list[dspy.Example]:
    examples = []
    for skill_dir in sorted(SKILLS_ROOT.iterdir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            continue

        content = skill_md.read_text()
        frontmatter, body = _parse_skill_md(content)
        if not frontmatter:
            continue

        quality = "high" if skill_dir.name in HIGH_QUALITY_SKILLS else "medium"

        examples.append(
            dspy.Example(
                skill_name=skill_dir.name,
                skill_body=body,
                frontmatter=frontmatter,
                quality=quality,
                gold_description=frontmatter.get("description", ""),
                gold_quick_ref=_extract_quick_ref(body),
            ).with_inputs("skill_name", "skill_body", "frontmatter")
        )

    return examples


def _parse_skill_md(content: str) -> tuple[dict, str]:
    if not content.startswith("---"):
        return {}, content
    end = content.find("---", 3)
    if end == -1:
        return {}, content
    try:
        fm = yaml.safe_load(content[3:end])
        return fm or {}, content[end + 3:].strip()
    except Exception:
        return {}, content


def _extract_quick_ref(body: str) -> str:
    lines = body.split("\n")
    in_qr, result = False, []
    for line in lines:
        if line.strip() == "## Quick Reference":
            in_qr = True
            continue
        if in_qr and line.startswith("##"):
            break
        if in_qr:
            result.append(line)
    return "\n".join(result).strip()
