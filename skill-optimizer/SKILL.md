---
name: skill-optimizer
description: "Use when a SKILL.md description, trigger, Quick Reference, or Iron Laws feels vague, too long, or fails to activate the skill correctly"
version: 1.0.0
trigger: "스킬 문서 개선, description 최적화, trigger 보완, Quick Reference 재작성, Iron Laws 추가, skill doc, CSO 최적화, 스킬 발동 안 됨"
allowed-tools:
  - Read
  - Bash
---

## Quick Reference
- **대상 필드**: `description` (≤50 토큰), `trigger` (한/영 키워드), `## Quick Reference` (≤5줄), Iron Laws
- **도구 위치**: `.hxsk/tools/skill-doc-optimizer/optimize.py`
- **dry-run 먼저**: `python optimize.py --skill {name} --dry-run` → 검토 → `--apply`
- **적용 후 필수**: `skill-testing` 스킬로 동작 변화 검증
- **NO APPLY WITHOUT REVIEW FIRST**: 자동 적용 전 diff를 반드시 확인한다

---

# HXSK Skill Document Optimizer

<role>
DSPy BootstrapFewShot 기반 개발 도구를 실행해 SKILL.md 텍스트 필드를 CSO 원칙에 맞게 개선한다.
런타임 컴포넌트가 아닌 오프라인 개발 도구임.
</role>

---

## 언제 사용하는가

다음 증상 중 하나가 있을 때:

- 에이전트가 스킬을 로딩해야 할 상황에서 로딩하지 않음 (description/trigger 문제)
- `## Quick Reference`가 5줄을 초과하거나 절차 단계를 나열함
- 스킬 본문에 암시된 규칙이 Iron Laws로 선언되지 않음
- description에 방법론 이름, 기능 목록, 워크플로우 요약이 포함됨
- 새 스킬 작성 후 첫 CSO 검토가 필요할 때

---

## 실행 절차

### Step 1 — 환경 확인

```bash
cd .hxsk/tools/skill-doc-optimizer
ls .venv/ 2>/dev/null || python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -q
```

### Step 2 — dry-run으로 변경안 검토

```bash
python optimize.py --skill {skill_name} --dry-run
```

출력 항목:
- `[description]` Before / After / 이유
- `[trigger]` 추가된 키워드
- `[Quick Reference]` 개선안
- `[Iron Laws]` 신규 발굴 제약

### Step 3 — 검토 기준

| 필드 | 수용 기준 |
|------|-----------|
| description | "Use when ..." 패턴 + ≤50 토큰 + 트리거 조건만 포함 |
| trigger | 한국어·영어 혼합 + 누락된 동의어 보완 |
| Quick Reference | ≤5줄 + **볼드 키워드**: 설명 형식 + 판단 기준 중심 |
| Iron Laws | `NO X WITHOUT Y FIRST` 형식 |

### Step 4 — 적용

```bash
python optimize.py --skill {skill_name} --apply
```

### Step 5 — 검증 (필수)

Claude Code에서:
```
/skill-testing -- {skill_name}
```

동작 변화가 의도한 방향인지 확인 후 커밋.

---

## 전체 스킬 일괄 최적화

```bash
# dry-run 전체
python optimize.py --all --dry-run 2>&1 | tee /tmp/skill-opt-review.txt

# 검토 후 일괄 적용
python optimize.py --all --apply
```

일괄 적용 후 `skill-testing`으로 각 스킬을 순서대로 검증.

---

## Iron Laws

- `NO APPLY WITHOUT REVIEW FIRST` — dry-run 결과를 확인하지 않고 --apply 실행 금지
- `NO COMMIT WITHOUT SKILL-TESTING` — skill-testing 검증 없이 변경된 SKILL.md 커밋 금지

---

## 참조

- 구현 계획: `docs/plans/2026-04-23-dspy-skill-doc-optimizer.md`
- CSO 원칙: `.hxsk/research/` (SkillReducer 논문)
- skill-testing: `.hxsk/skills/skill-testing/SKILL.md`
