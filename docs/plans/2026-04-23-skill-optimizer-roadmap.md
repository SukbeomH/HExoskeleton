# HXSK Skill-Doc Optimizer 작업 로드맵

**작성일**: 2026-04-23  
**근거 세션**: skill-doc-optimizer 구현 + Watson et al. 2026 연구 분석  
**목표**: DSPy 기반 SKILL.md 자동 최적화 도구를 연구 기반으로 강화하여 22개 스킬 문서 품질을 체계적으로 개선

---

## Phase 10 완료 상태 (2026-04-23)

| 항목 | 상태 | 결과 |
|------|------|------|
| metrics.py Watson et al. 3개 함수 | ✅ | answerability/specificity/intention_grounding |
| signatures.py OutputField 2개 추가 | ✅ | answerability_score, specificity_score |
| MEDIUM 4개 스킬 CSO 적용 | ✅ | description "Use when..." 패턴 완료 |
| Iron Laws 수동 보완 (4개 스킬) | ✅ | optimize.py 갭으로 인한 수동 처리 |
| BootstrapFewShot 실행 | ✅ | Val score 0.797 (목표 0.75 초과) |
| composite_hallucination_risk | ✅ | 0.571 → 0.196 (-63%) |

### PR #146 리뷰 발견 사항 (후속 작업 대상)

> 6-Persona 리뷰 결과 (2026-04-23). Blocker 0건 → APPROVE 및 머지 완료.

#### [Medium] 후속 PR 필요

| # | 파일 | 문제 | 조치 |
|---|------|------|------|
| M-1 | `optimize.py:122-139` | `_apply_changes()`가 Iron Laws를 파일에 기록하지 않음. `result.iron_laws` stdout 출력만 되고 SKILL.md 미반영 | `## Iron Laws` 섹션 write 로직 추가 |
| M-2 | `optimized_module.json` | 재실행 가능한 BootstrapFewShot 결과물이 git 포함 (220KB) | `.gitignore` 추가 또는 재생성 방법 README 명시 |
| M-3 | `requirements.txt` | `dspy-ai>=2.5.0` 하한만 지정, 상한 없음. dspy-ai는 마이너 릴리스에서 API 변경 잦음 | `dspy-ai~=2.5.0` compatible release 핀 |
| M-4 | `signatures.py:30-38` | `OutputField float` 파싱 안전장치 없음. LLM이 "0.85 (높음)" 반환 시 파싱 실패 가능 | `modules.py`에서 `try/except ValueError` 추가 |

#### [Nitpick] 선택적 개선

| # | 파일 | 문제 |
|---|------|------|
| N-1 | `metrics.py:77-79` | `words = text.lower().split()` 선언 후 trigger 체크에 미사용 (`text_lower` substring 방식 사용). `if not text.strip(): return 0.0`으로 단순화 가능 |
| N-2 | `optimize.py:146` | `valset[:5]` — MEDIUM 스킬 4개뿐이어 실제 4개 반환. `# 최대 5개 (현재 4개)` 주석 추가 권장 |
| N-3 | `.claude/settings.json` | `Bash(python3 -c *)` 프로젝트 공유 설정에 포함. `.claude/settings.local.json`으로 이동 고려 |

---

## 현재 상태 (Phase 0 — 완료)

| 항목 | 상태 | 비고 |
|------|------|------|
| `.hxsk/tools/skill-doc-optimizer/` 구조 생성 | ✅ | signatures/modules/metrics/dataset/optimize |
| 사내 Qwen API 연결 | ✅ | 27B (32K ctx) / 122B (65K ctx), `.env` 관리 |
| `planner` 스킬 dry-run 검증 | ✅ | description·trigger·QR·Iron Laws 모두 생성 |
| HIGH_QUALITY_SKILLS 확정 | ✅ | HIGH 18개 / MEDIUM 4개 (bootstrap·commit·create-pr·write-report) |
| Watson et al. 2026 연구 분석 | ✅ | `.hxsk/research/2026-04-23-hallucination-linguistic-features.md` |
| 관련 연구 4편 수집 | ✅ | Frontiers·EMNLP·JMIR·MetaQA |
| PATTERNS.md 업데이트 | ✅ | 패턴 #20: LLM Hallucination Risk OR 수치 |

---

## Phase 1 — 메트릭·시그니처 강화 (1~2주)

> **목적**: Watson et al. Odds Ratio 수치를 DSPy 최적화 루프에 직접 통합

### 1-A. `metrics.py` 언어 품질 지표 추가

Watson et al. Table 1 계수(β)를 가중치로 사용하는 `composite_hallucination_risk` 함수 구현.

```python
# 추가할 함수 3개
def answerability_score(text: str) -> float:
    """OR=0.331 보호 특성 — "Use when X" 조건절 명확성 측정"""

def specificity_score(text: str) -> float:
    """OR=2.382 위험 특성(역방향) — 추상 표현 밀도 측정"""

def intention_grounding_score(text: str) -> float:
    """OR=0.846 보호 특성 — what/when/why 명시 여부"""

def composite_hallucination_risk(text: str) -> float:
    """
    risk = 0.868 × lack_specificity
           - 1.106 × answerability
           - 0.168 × intention_grounding
           + 0.568 × clause_complexity
    반환: 0(저위험) ~ 1(고위험)
    """
```

`combined_metric`에 패널티 항으로 추가:
```python
def combined_metric(example, prediction, trace=None) -> float:
    base = description_metric(...) * 0.4 + quick_ref_metric(...) * 0.4
    risk_penalty = composite_hallucination_risk(prediction.optimized_description) * 0.2
    return base - risk_penalty
```

### 1-B. `signatures.py` OutputField 확장

`DescriptionOptimizer`에 품질 자가 평가 필드 추가:

```python
answerability_score: float = dspy.OutputField(
    desc="description의 답변 가능성 점수 (0-1). OR=0.331 기준."
)
specificity_score: float = dspy.OutputField(
    desc="description의 구체성 점수 (0-1). OR=2.382 역방향."
)
```

→ BootstrapFewShot이 높은 점수의 예시만 few-shot으로 선택하도록 유도.

### 1-C. 완료 기준

- [x] `metrics.py` 함수 3개 + `combined_metric` 패턴 업데이트
- [x] `signatures.py` OutputField 2개 추가
- [x] `python3 optimize.py --skill planner --dry-run` 재실행 → risk 수치 출력 확인
- [x] `python3 optimize.py --skill bootstrap --dry-run` → MEDIUM 스킬 개선 폭 확인

---

## Phase 2 — MEDIUM 4개 스킬 우선 적용 (2~3주)

> **목적**: 개선 효과가 가장 큰 스킬부터 실제 적용하여 가치 조기 확인

### 대상 및 문제

| 스킬 | 현재 description 문제 | 우선순위 |
|------|----------------------|---------|
| `bootstrap` | "Idempotent project setup..." — 트리거 조건 없음 | 1 |
| `commit` | "Analyzes diffs, splits logical changes..." — 기능 나열 | 2 |
| `create-pr` | "Analyzes changes, creates branch..." — 기능 나열 | 3 |
| `write-report` | "Writes structured solution comparison..." — 기능 나열 | 4 |

### 실행 절차

```bash
cd .hxsk/tools/skill-doc-optimizer
source .venv/bin/activate

# 1. 각 스킬 dry-run 검토
for skill in bootstrap commit create-pr write-report; do
  python3 optimize.py --skill $skill --dry-run 2>&1 | tee /tmp/opt-$skill.txt
done

# 2. 검토 후 순서대로 적용
python3 optimize.py --skill bootstrap --apply
# /skill-testing -- bootstrap  ← Claude Code에서 검증

python3 optimize.py --skill commit --apply
# /skill-testing -- commit
```

### 완료 기준

- [x] 4개 스킬 dry-run 결과 검토 완료
- [x] `/skill-testing`으로 각 스킬 발동 확인
- [x] HIGH 스킬 1개(description 미세 개선 가능성 검토)
- [x] 변경사항 커밋 (`/commit`)

---

## Phase 3 — BootstrapFewShot 최적화 실행 (3~4주)

> **목적**: 18개 HIGH 스킬을 few-shot 예시로 사용해 DSPy 프롬프트 자동 최적화

```bash
python3 optimize.py --bootstrap
# → optimized_module.json 생성
# → Val score 출력 (목표: ≥ 0.75)
```

### 훈련/검증 분할

| 셋 | 스킬 | 기준 |
|----|------|------|
| trainset | HIGH 18개 중 8개 | CSO 패턴 최우수 |
| valset | MEDIUM 4개 중 최대 5개 | 개선 대상 |

### 완료 기준

- [x] `optimized_module.json` 저장
- [x] Val score ≥ 0.75 (달성: 0.797)
- [x] bootstrap 전/후 planner dry-run 비교 → 개선 확인
- [ ] 122B 모델로도 실행하여 결과 비교 (`--model qwen-122b`) — Phase 11 후보

---

## Phase 4 — 전체 스킬 일괄 최적화 (4~5주)

> **목적**: 22개 전체 스킬에 최적화 적용, skill-testing으로 행동 변화 검증

```bash
# 전체 dry-run
python3 optimize.py --all --dry-run 2>&1 | tee /tmp/all-skills-opt.txt

# 검토 후 일괄 적용
python3 optimize.py --all --apply
```

### 검증 체크리스트

- [ ] 각 스킬 `description` OR 기준 risk score 감소 확인
- [ ] 전체 trigger 커버리지 확인 (한/영 혼합, 동의어 포함)
- [ ] Quick Reference 5줄 제약 준수 확인
- [ ] Iron Laws `NO X WITHOUT Y` 형식 통일 확인
- [ ] `/skill-testing` 전수 검증 (22개)
- [ ] `doc-lint` 통과 확인
- [ ] PR 생성 → 리뷰 → master 병합

---

## Phase 5 — 강인성 테스트 인프라 구축 (중기, 6~8주)

> **목적**: Watson et al.의 "의미 동치 섭동" 방법론을 trigger 검증에 적용

### 개념

```
trigger 절 원문 → 6개 의미 동치 변형 생성 → 각 변형으로 에이전트 호출
→ 모두 동일 스킬 발동 시 "강인한 trigger"
→ 불일치 발생 시 자동 재작성 제안
```

### 구현 대상 파일

```
.hxsk/tools/skill-doc-optimizer/
  robustness_test.py    # trigger 강인성 테스트 스크립트
  paraphrase.py         # 의미 동치 변형 생성 (Qwen 활용)
```

### KS 거리 임계값 (논문 기준)

| KS 거리 | 판정 |
|---------|------|
| > 0.70 | 강인한 trigger |
| 0.50~0.70 | 개선 권고 |
| < 0.50 | 재작성 필요 |

---

## Phase 6 — 다국어·도메인 확장 연구 (장기, 3개월)

> **목적**: Watson et al.의 영어 전용 한계를 극복, 한국어 SKILL.md 환각 특성 연구

### 연구 질문

1. 한국어 SKILL.md의 **주어 생략**이 Answerability에 미치는 영향
2. 한/영 혼합 trigger의 언어 특성 벡터 차이
3. 조사 중의성(이/가, 을/를 생략)이 Clause Complexity에 미치는 영향

### 데이터 수집 계획

- HXSK 에이전트 세션 로그에서 스킬 발동/미발동 사례 수집
- trigger 매칭 실패 사례 → "답변 불가능 쿼리" 카테고리로 분류
- 수집 규모 목표: ≥ 1,000 사례

---

## 병렬 진행 가능 항목

```
Phase 1 (메트릭 강화)
    │
    ├─── Phase 2 (MEDIUM 4개 적용)  ← Phase 1 완료 후
    │
    └─── Phase 3 (Bootstrap)         ← Phase 1 완료 후 독립 실행 가능

Phase 2 + Phase 3 완료
    │
    └─── Phase 4 (전체 일괄)

Phase 4 완료
    │
    ├─── Phase 5 (강인성 테스트)
    └─── Phase 6 (다국어 연구, 장기)
```

---

## 의사결정 포인트

| 포인트 | 조건 | 결정 |
|--------|------|------|
| Phase 3 Val score < 0.6 | Bootstrap 효과 미미 | MIPROv2 전환 검토 |
| Phase 3에서 122B > 27B | 품질 격차 큼 | 122B를 기본 모델로 전환 |
| Phase 4 skill-testing 실패 | 행동 변화 부정적 | `--apply` 롤백 후 dry-run 재검토 |
| Phase 5 KS 거리 < 0.5 다수 | trigger 구조 문제 | TriggerExpander Signature 재설계 |

---

## 참조 문서

| 문서 | 경로 |
|------|------|
| 구현 계획 원본 | `docs/plans/2026-04-23-dspy-skill-doc-optimizer.md` |
| 연구 보고서 | `.hxsk/research/2026-04-23-hallucination-linguistic-features.md` |
| 도구 사용법 | `skill-optimizer/SKILL.md` |
| 현재 메트릭 코드 | `.hxsk/tools/skill-doc-optimizer/metrics.py` |
| HIGH_QUALITY_SKILLS | `.hxsk/tools/skill-doc-optimizer/dataset.py` |

---

*Last updated: 2026-04-23 — Phase 10 완료 상태 + PR #146 리뷰 발견 사항 추가*
