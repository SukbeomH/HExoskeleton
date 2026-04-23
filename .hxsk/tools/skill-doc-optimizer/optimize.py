"""
사용법:
  cd .hxsk/tools/skill-doc-optimizer
  pip install -r requirements.txt

  # 단일 스킬 최적화 (dry-run)
  python optimize.py --skill planner --dry-run

  # 전체 스킬 최적화 (diff만 출력)
  python optimize.py --all --dry-run

  # 실제 적용 (SKILL.md 업데이트)
  python optimize.py --skill debugger --apply

  # BootstrapFewShot으로 프롬프트 최적화
  python optimize.py --bootstrap
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(Path(__file__).parent))

import dspy
from dataset import load_examples, _parse_skill_md
from modules import SkillDocOptimizer
from metrics import combined_metric


def _load_env():
    import os
    from dotenv import load_dotenv
    from pathlib import Path

    for env_path in [
        Path(__file__).parent / ".env",
        ROOT / ".env",
        ROOT.parent / ".env",
        Path.home() / ".env",
    ]:
        if env_path.exists():
            load_dotenv(env_path, override=False)
    return os.environ


def setup_lm(model_name: str = None):
    import os

    env = _load_env()
    model_name = model_name or env.get("DEFAULT_LM", "qwen-27b")
    prefix = model_name.upper().replace("-", "_")

    # .env에서 동적으로 읽기: QWEN_27B_MODEL, QWEN_27B_API_KEY 등
    model_id = env.get(f"{prefix}_MODEL")
    api_key = env.get(f"{prefix}_API_KEY")
    max_tokens = int(env.get(f"{prefix}_MAX_TOKENS", 2048))
    api_base = env.get("INTERNAL_API_BASE") if model_name != "claude" else None

    if not model_id or not api_key:
        print(f"ERROR: {prefix}_MODEL 또는 {prefix}_API_KEY 가 .env에 없습니다.")
        print(f"  .hxsk/tools/skill-doc-optimizer/.env 를 확인하세요.")
        print(f"  사용 가능한 모델: DEFAULT_LM 값 또는 --model 인수")
        sys.exit(1)

    provider = "anthropic" if model_name == "claude" else "openai"
    dspy_model = f"{provider}/{model_id}"

    kwargs = dict(model=dspy_model, api_key=api_key, max_tokens=max_tokens)
    if api_base:
        kwargs["api_base"] = api_base

    print(f"모델: {dspy_model}  base_url: {api_base or '(default)'}")
    return dspy.LM(**kwargs)


def optimize_skill(skill_name: str, apply: bool = False):
    skill_md_path = ROOT / "skills" / skill_name / "SKILL.md"
    if not skill_md_path.exists():
        print(f"ERROR: {skill_md_path} 없음")
        return

    content = skill_md_path.read_text()
    frontmatter, body = _parse_skill_md(content)

    optimizer = SkillDocOptimizer()
    result = optimizer(skill_name=skill_name, skill_body=body, frontmatter=frontmatter)

    print(f"\n{'='*60}")
    print(f"  {skill_name} 최적화 결과")
    print(f"{'='*60}")

    print(f"\n[description]")
    print(f"  Before: {frontmatter.get('description', '(없음)')}")
    print(f"  After:  {result.optimized_description}")
    print(f"  이유:   {result.changes['description']}")

    print(f"\n[trigger]")
    print(f"  Before: {frontmatter.get('trigger', '(없음)')}")
    print(f"  After:  {result.expanded_triggers}")
    if result.changes['trigger']:
        print(f"  추가:   {result.changes['trigger']}")

    print(f"\n[Quick Reference]")
    print(result.refined_quick_ref)
    if result.changes['quick_ref']:
        print(f"\n  제거됨: {result.changes['quick_ref']}")

    print(f"\n[Iron Laws]")
    print(result.iron_laws)
    if result.changes['iron_laws']:
        print(f"\n  신규 발굴: {result.changes['iron_laws']}")

    if apply:
        _apply_changes(skill_md_path, content, frontmatter, result)
        print(f"\n✓ {skill_md_path} 업데이트 완료")
        print("→ skill-testing 스킬로 검증 후 커밋하세요")
    else:
        print(f"\n(dry-run 모드 — 파일 변경 없음. --apply 플래그로 적용)")


def _apply_changes(path, original_content, frontmatter, result):
    import yaml

    frontmatter["description"] = result.optimized_description
    frontmatter["trigger"] = result.expanded_triggers

    new_fm = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False)
    body = original_content.split("---", 2)[2].strip()

    qr_pattern = "## Quick Reference\n"
    if qr_pattern in body:
        before_qr, rest = body.split(qr_pattern, 1)
        after_qr_start = rest.find("\n##")
        after_qr = rest[after_qr_start:] if after_qr_start != -1 else ""
        body = before_qr + qr_pattern + result.refined_quick_ref + "\n" + after_qr

    new_content = f"---\n{new_fm}---\n\n{body}"
    path.write_text(new_content)


def bootstrap_optimize():
    """BootstrapFewShot으로 모듈 최적화."""
    examples = load_examples()
    trainset = [e for e in examples if e.quality == "high"][:8]
    valset = [e for e in examples if e.quality == "medium"][:5]

    print(f"훈련셋: {len(trainset)}개, 검증셋: {len(valset)}개")

    optimizer_module = SkillDocOptimizer()
    tp = dspy.BootstrapFewShot(metric=combined_metric, max_bootstrapped_demos=3)
    optimized = tp.compile(optimizer_module, trainset=trainset)

    save_path = Path(__file__).parent / "optimized_module.json"
    optimized.save(str(save_path))

    val_score = _eval(optimized, valset)
    print(f"Bootstrap 완료. Val score: {val_score:.3f}")
    print(f"저장: {save_path}")


def _eval(module, dataset):
    scores = []
    for ex in dataset:
        try:
            pred = module(**ex.inputs())
            scores.append(combined_metric(ex, pred))
        except Exception as e:
            print(f"  평가 실패 ({ex.skill_name}): {e}")
    return sum(scores) / len(scores) if scores else 0.0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="HXSK SKILL.md 텍스트 필드 최적화 도구")
    parser.add_argument("--skill", help="최적화할 스킬 이름")
    parser.add_argument("--all", action="store_true", help="전체 스킬 최적화")
    parser.add_argument("--dry-run", action="store_true", help="변경사항 출력만 (기본값)")
    parser.add_argument("--apply", action="store_true", help="실제 파일 업데이트")
    parser.add_argument("--bootstrap", action="store_true", help="BootstrapFewShot 실행")
    parser.add_argument("--model", default=None,
                        help=".env의 DEFAULT_LM 또는 직접 지정 (예: qwen-27b, qwen-122b, claude)")
    args = parser.parse_args()

    lm = setup_lm(args.model)
    dspy.configure(lm=lm)

    if args.bootstrap:
        bootstrap_optimize()
    elif args.skill:
        optimize_skill(args.skill, apply=args.apply)
    elif args.all:
        for ex in load_examples():
            optimize_skill(ex.skill_name, apply=args.apply)
    else:
        parser.print_help()
