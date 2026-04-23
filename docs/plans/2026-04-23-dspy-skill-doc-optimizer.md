# DSPy 스킬 문서 최적화 도구 구현 계획

**날짜**: 2026-04-23  
**목적**: DSPy BootstrapFewShot으로 `.hxsk/skills/*/SKILL.md`의 텍스트 필드를 자동 개선  
**적합성**: 높음 — 이미지 없음, 텍스트 최적화 문제, 22개 기존 스킬이 훈련 데이터

---

## 1. 왜 지금 이 문제인가

현재 22개 SKILL.md의 텍스트 필드는 수작업으로 관리됩니다.

| 필드 | 현재 상태 | 문제 |
|------|-----------|------|
| `description` | 일부 CSO 준수, 일부 방법론 요약 혼입 | 에이전트가 스킬 본문을 건너뛸지 판단 불가 |
| `trigger` | 한국어·영어 혼합, 누락된 변형 표현 다수 | 트리거 미발동으로 스킬 미로딩 |
| `## Quick Reference` | 5줄 제약 있으나 내용 일관성 없음 | 핵심 결정 지점이 빠지거나 부차 정보가 포함 |
| Iron Laws | 스킬별 선언 여부 불균일 | 에이전트 준수율 33%→72% 효과(Meincke et al.)를 완전히 활용 못함 |

---

## 2. 대상 범위

DSPy가 최적화하는 텍스트 필드 4가지:

```
SKILL.md frontmatter:
  description  ← CSO 원칙 적용 (트리거 조건만, ≤50 토큰)
  trigger      ← 한/영 키워드 확장 (누락 변형 추가)

SKILL.md body:
  ## Quick Reference  ← ≤5줄, 핵심 결정 지점 압축
  Iron Laws          ← NO X WITHOUT Y 형식 추출·강화
```

나머지 본문(절차·예시·참조 링크)은 DSPy가 수정하지 않습니다.

---

## 3. 신규 파일 구조

```
skill-optimizer/                  # 프로젝트 루트 — 배포 제외 개발 도구
  SKILL.md                        # 사용법 문서 (에이전트용 참조)

.hxsk/
  tools/
    skill-doc-optimizer/          # Python 개발 도구 (신규, 런타임 비포함)
      optimize.py                 # CLI 진입점
      signatures.py               # DSPy Signature 정의
      modules.py                  # DSPy Module 정의
      metrics.py                  # 평가 메트릭
      dataset.py                  # 훈련 데이터 로더
      requirements.txt            # 격리 의존성 (dspy-ai만)
```

> **배치 근거**: `.hxsk/skills/`에 두면 Hexoskeleton 배포 시 모든 하네스에 스킬로 노출된다.
> 이 도구는 스킬 문서를 *작성하는* 개발자 유틸리티이므로 배포 경로 밖 프로젝트 루트에 위치한다.

---

## 4. DSPy Signature 정의 — `signatures.py`

```python
import dspy


class DescriptionOptimizer(dspy.Signature):
    """HXSK 스킬의 description 필드를 CSO 원칙에 따라 최적화한다.

    CSO 원칙:
    - 에이전트가 "언제 이 스킬을 써야 하는가"만 포함
    - 워크플로우 요약, 방법론 이름, 기능 목록 제외
    - 50 토큰 이하
    - "Use when ..." 또는 동등한 트리거 패턴 사용
    """

    skill_name: str = dspy.InputField(desc="스킬 이름")
    skill_body: str = dspy.InputField(desc="Quick Reference 이후 SKILL.md 본문 전체")
    current_description: str = dspy.InputField(desc="현재 description 값")
    cso_bad_examples: str = dspy.InputField(
        desc="피해야 할 description 패턴 (방법론 요약, 기능 나열 등)"
    )

    optimized_description: str = dspy.OutputField(desc="CSO 최적화된 description. 50 토큰 이하.")
    change_reason: str = dspy.OutputField(desc="기존 대비 개선된 이유 (1줄)")


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
```

---

## 5. DSPy Module 정의 — `modules.py`

```python
import dspy
from .signatures import (
    DescriptionOptimizer, TriggerExpander,
    QuickReferenceRefiner, IronLawsSynthesizer
)

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

        return dspy.Prediction(
            optimized_description=desc_result.optimized_description,
            expanded_triggers=trigger_result.expanded_triggers,
            refined_quick_ref=qr_result.refined_quick_ref,
            iron_laws=iron_result.iron_laws,
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
        laws = [l for l in lines if "NO " in l and " WITHOUT " in l]
        return "\n".join(laws)
```

---

## 6. 평가 메트릭 — `metrics.py`

```python
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


def combined_metric(example, prediction, trace=None) -> float:
    """description + quick_ref 가중 평균."""
    return (
        description_metric(example, prediction, trace) * 0.5
        + quick_ref_metric(example, prediction, trace) * 0.5
    )
```

---

## 7. 훈련 데이터 로더 — `dataset.py`

```python
"""22개 기존 SKILL.md → DSPy Example 변환."""
import re
from pathlib import Path
import yaml
import dspy

SKILLS_ROOT = Path(__file__).parent.parent.parent / "skills"

# CSO 기준으로 품질이 높다고 판단된 스킬 (positive examples)
HIGH_QUALITY_SKILLS = {
    "debugger", "planner", "memory-protocol", "empirical-validation",
    "executor", "verifier", "impact-analysis",
}


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
                # 레이블: 현재 description이 gold (high) 또는 개선 대상 (medium)
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
```

---

## 8. CLI 진입점 — `optimize.py`

```python
"""
사용법:
  cd .hxsk/tools/skill-doc-optimizer
  pip install -r requirements.txt

  # 단일 스킬 최적화
  python optimize.py --skill planner --dry-run

  # 전체 스킬 최적화 (diff만 출력)
  python optimize.py --all --dry-run

  # 실제 적용 (SKILL.md 업데이트)
  python optimize.py --skill debugger --apply
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(ROOT.parent))

import dspy
from dataset import load_examples
from modules import SkillDocOptimizer
from metrics import combined_metric


def setup_lm():
    # 프로젝트 .env에서 API 키 로드
    import os
    from dotenv import load_dotenv
    load_dotenv(ROOT.parent / ".env")

    return dspy.LM(
        model="anthropic/claude-sonnet-4-6",
        api_key=os.getenv("ANTHROPIC_API_KEY"),
        max_tokens=2048,
    )


def optimize_skill(skill_name: str, apply: bool = False):
    skill_md_path = ROOT / "skills" / skill_name / "SKILL.md"
    if not skill_md_path.exists():
        print(f"ERROR: {skill_md_path} 없음")
        return

    from dataset import _parse_skill_md
    content = skill_md_path.read_text()
    frontmatter, body = _parse_skill_md(content)

    optimizer = SkillDocOptimizer()
    result = optimizer(skill_name=skill_name, skill_body=body, frontmatter=frontmatter)

    print(f"\n=== {skill_name} 최적화 결과 ===")
    print(f"\n[description]")
    print(f"  Before: {frontmatter.get('description', '')}")
    print(f"  After:  {result.optimized_description}")
    print(f"  이유:   {result.changes['description']}")

    print(f"\n[Quick Reference]")
    print(result.refined_quick_ref)

    print(f"\n[Iron Laws]")
    print(result.iron_laws)

    if apply:
        _apply_changes(skill_md_path, content, frontmatter, result)
        print(f"\n✓ {skill_md_path} 업데이트 완료")
        print("→ skill-testing 스킬로 검증 후 커밋하세요")


def _apply_changes(path, original_content, frontmatter, result):
    import yaml
    frontmatter["description"] = result.optimized_description
    frontmatter["trigger"] = result.expanded_triggers

    new_fm = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False)
    body = original_content.split("---", 2)[2].strip()

    # Quick Reference 교체
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
    lm = setup_lm()
    dspy.configure(lm=lm)

    examples = load_examples()
    trainset = [e for e in examples if e.quality == "high"][:8]
    valset = [e for e in examples if e.quality == "medium"][:5]

    optimizer_module = SkillDocOptimizer()

    tp = dspy.BootstrapFewShot(metric=combined_metric, max_bootstrapped_demos=3)
    optimized = tp.compile(optimizer_module, trainset=trainset)
    optimized.save(".hxsk/tools/skill-doc-optimizer/optimized_module.json")
    print(f"Bootstrap 완료. Val score: {_eval(optimized, valset):.3f}")


def _eval(module, dataset):
    scores = []
    for ex in dataset:
        pred = module(**ex.inputs())
        scores.append(combined_metric(ex, pred))
    return sum(scores) / len(scores) if scores else 0.0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill", help="최적화할 스킬 이름")
    parser.add_argument("--all", action="store_true", help="전체 스킬 최적화")
    parser.add_argument("--dry-run", action="store_true", help="변경사항 출력만")
    parser.add_argument("--apply", action="store_true", help="실제 파일 업데이트")
    parser.add_argument("--bootstrap", action="store_true", help="BootstrapFewShot 실행")
    args = parser.parse_args()

    lm = setup_lm()
    dspy.configure(lm=lm)

    if args.bootstrap:
        bootstrap_optimize()
    elif args.skill:
        optimize_skill(args.skill, apply=args.apply)
    elif args.all:
        from dataset import load_examples
        for ex in load_examples():
            optimize_skill(ex.skill_name, apply=args.apply)
```

---

## 9. `requirements.txt`

```
dspy-ai>=2.5.0
python-dotenv>=1.0.0
pyyaml>=6.0
```

---

## 10. 실행 순서

```bash
# 1. 격리 환경 설정 (HXSK 코어와 분리)
cd .hxsk/tools/skill-doc-optimizer
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 2. BootstrapFewShot 실행 (기존 22개 스킬로 학습)
python optimize.py --bootstrap

# 3. 단일 스킬 dry-run 검토
python optimize.py --skill executor --dry-run

# 4. 결과 확인 후 적용
python optimize.py --skill executor --apply

# 5. skill-testing 스킬로 동작 변경 확인
# (Claude Code에서)
# /skill-testing -- executor

# 6. 커밋
# /commit
```

---

## 11. 설계 결정 사항

| 결정 | 이유 |
|------|------|
| **BootstrapFewShot** 선택 | 22개 기존 스킬이 few-shot 예시 역할. MIPROv2 불필요 (훈련셋 소규모) |
| **ChainOfThought** 사용 | 각 Signature마다 reasoning 필드 → 개선 이유 추적 가능 |
| **격리 Python 환경** | HXSK 코어 제로 의존성 원칙 준수. 개발 도구는 별도 `.venv` |
| **dry-run 기본** | 자동 적용 전 반드시 사람 검토 (`skill-testing` 필수) |
| **4개 필드 독립 Signature** | 각 최적화가 독립적으로 평가 가능, 부분 적용 지원 |
| **Claude API 사용** | Qwen·GPT 대비 SKILL.md 형식 이해도 높음. 프로젝트 기존 API 재사용 |
