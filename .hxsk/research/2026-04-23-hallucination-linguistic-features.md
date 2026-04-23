---
title: "What Makes a Good Query? Measuring the Impact of Human-Confusing Linguistic Features on LLM Performance"
source: arXiv 2602.20300
date: 2026-04-23
tags: hallucination, LLM, linguistics, prompt-engineering
---

# "What Makes a Good Query?" 분석 보고서

## 1. 논문 개요

- **제목**: What Makes a Good Query? Measuring the Impact of Human-Confusing Linguistic Features on LLM Performance
- **저자**: William Watson†, Nicole Cho†, Sumitra Ganesh, Manuela Veloso (†Equal Contribution)
- **기관**: J.P. Morgan AI Research
- **발표일**: 2026년 2월 23일 (arXiv: 2602.20300v1)
- **라이선스**: CC BY 4.0

**핵심 기여 (3줄 요약)**:
17차원 언어 특성 벡터로 쿼리를 정량화하여 369,837개의 실제 쿼리를 분석, Answerability(OR=0.331)와 Lack of Specificity(OR=2.382)가 환각 위험도에 가장 강한 상관관계를 가짐을 경험적으로 증명했다. Proportional-Odds 회귀 모델과 의미론적 동치 섭동(paraphrase 기반 프록시 측정)을 결합해 관찰 연구 한계를 부분 극복했다. 이 결과는 "환각은 모델 결함"이라는 통념에서 벗어나 "쿼리 형태가 환각 위험도를 결정한다"는 방향으로 패러다임을 전환시킨다.

---

## 2. 문제 정의

LLM 환각(hallucination)은 일반적으로 모델의 내재적 결함으로 다뤄진다. 그러나 실제 운영 환경에서 동일 모델에 동일 의미의 질문을 다르게 표현하면 환각 발생률이 크게 달라지는 현상이 관찰된다. 기존 연구들은 모델 아키텍처나 파인튜닝 전략에 집중해왔으나, **쿼리 자체의 언어적 특성이 환각 위험을 어떻게 구조적으로 결정하는지**에 대한 체계적인 분석은 부재했다.

이 논문이 해결하는 문제:
- 어떤 쿼리 언어 특성이 환각 위험을 높이거나 낮추는가?
- 그 관계를 통계적으로 신뢰할 수 있게 측정할 수 있는가?
- 환각 감소를 위한 실용적이고 저비용의 쿼리 개선 전략이 존재하는가?

---

## 3. 연구 방법론

### 3.1 데이터셋

총 13개 QA 데이터셋, 3가지 시나리오, 16개 구성, **369,837개 쿼리** 분석:

| 시나리오 | 데이터셋 | 쿼리 수 |
|----------|----------|---------|
| 추출형 (Extractive) | SQuADv2 | 85,892 |
| 선택형 (Multiple Choice) | TruthfulQA, SciQ, MMLU, PIQA, BoolQ, OpenBookQA, MathQA, ARC-Easy, ARC-Challenge | 81,697 |
| 생성형 (Abstractive) | SQuADv2, TruthfulQA, SciQ, WikiQA, HotpotQA, TriviaQA | 202,248 |

### 3.2 17차원 쿼리 특성 벡터

| 범주 | 특성 |
|------|------|
| 구조적 | 토큰 길이, 조응 참조, 절 복잡성, 의존 트리 깊이, 파스 트리 높이, 절 수 |
| 시나리오 기반 | 쿼리 유형 불일치, 전제, 화용적 특성 |
| 어휘적 | 단어 희귀성, 부정 사용, 최상급, 다의어 |
| 의미/스타일 | 답변 가능성, 과도한 세부사항, 주관성, 특이성 부족, 의도 근거화, 맥락 제약, 명명 개체 존재, 도메인 특이성 |

### 3.3 환각 프록시 측정

각 쿼리 `q_orig`에 대해 의미 동치 파라프레이즈 6개를 생성하고 혼합 유사도 점수 계산:

```
s(q_orig, q_i) = 0.6 · cos(e_bi(q_orig), e_bi(q_i)) + 0.4 · ½[Pr_cross(q_orig, q_i) + Pr_cross(q_i, q_orig)]
```

임계값 ≥ 0.85인 경우만 의미 동치로 인정. 환각 프록시:

```
ĥ(q_i) = 0.6·s_llm + 0.3·s_fuzz + 0.1·s_bleu
```

위험도를 세 범주로 분류:
- **Safe**: 6개 중 0개 환각
- **Borderline**: 6개 중 1-3개 환각
- **Risky**: 6개 중 4-6개 환각

### 3.4 통계 모델

Proportional-Odds (누적 로짓) 모델:

```
log(Pr(Y_i ≤ k | x_i, c_i) / Pr(Y_i > k | x_i, c_i)) = τ_k - (x_i^T β + α_d(i) + γ_s(i))
```

- `S_β`: 특성만 포함 모델
- `S_β,γ,α`: 시나리오 및 데이터셋 고정 효과 포함 전체 모델

---

## 4. 주요 결과

### 4.1 환각 위험 증가 특성 (Top-4, p < 10⁻⁵)

| 특성 | 계수 | Odds Ratio | Spearman ρ |
|------|------|-----------|-----------|
| Lack of Specificity (특이성 부족) | +0.868 | **2.382** | +0.271 |
| Clause Complexity (절 복잡성) | +0.568 | 1.764 | +0.155 |
| Negation Usage (부정 사용) | +0.311 | 1.364 | +0.028 |
| Anaphora Usage (조응 사용) | +0.214 | 1.238 | +0.107 |

### 4.2 환각 위험 감소 특성 (Top-4, p < 10⁻⁵)

| 특성 | 계수 | Odds Ratio | Spearman ρ |
|------|------|-----------|-----------|
| Answerability (답변 가능성) | -1.106 | **0.331** | -0.228 |
| Number of Clauses (절 수) | -0.262 | 0.769 | -0.272 |
| Query Token Length (쿼리 길이) | -0.212 | 0.809 | -0.274 |
| Intention Grounding (의도 근거화) | -0.168 | 0.846 | -0.159 |

**주목할 발견**: Named Entities Present(명명 개체 존재)는 p=0.205로 비유의미, Domain Specificity는 OR≈1.003으로 사실상 효과 없음.

### 4.3 분포 효과 (KS 거리 분석)

| 특성 | KS 거리 | 중앙값 이동 | 방향 |
|------|---------|-----------|------|
| Answerability | 0.72 | -0.58 | 위험↓ |
| Intention Grounding | 0.66 | -0.59 | 위험↓ |
| Lack of Specificity | 0.56 | +0.42 | 위험↑ |
| Clause Complexity | 0.40 | +0.27 | 위험↑ |

### 4.4 성향 분석 (준인과적 증거)

좋은 공통 지지(overlap > 0.35) 확보:
- Lack of Specificity: **+21.2%** 환각 증가 (IPW) / +19.9% (층화)
- Clause Complexity: **+10.3%** 환각 증가 (IPW) / +8.3% (층화)

불충분한 공통 지지(연관적 관계만):
- Answerability, Intention Grounding (overlap < 0.35)

### 4.5 실용적 쿼리 개선 전략

1. **명확화 제약 추가**: "Tesla에 대해 알려줘" → "Tesla의 2024 Q4 실적을 5개 항목으로 요약해줘"
2. **의도 명시**: "Java?" → "Java 프로그래밍 언어를 설명해줘"
3. **다의어 선제 해소**: "What is Java?" → "Java 프로그래밍 언어 vs 인도네시아 자바 섬은 무엇인가?"

---

## 5. 관련 연구 비교

### 5.1 프롬프트 전략 귀인 연구 (Frontiers in AI, 2025)

**출처**: [Survey and analysis of hallucinations in large language models: attribution to prompting strategies or model behavior (PMC12518350)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12518350/)

프롬프트 민감도(PS)와 모델 가변성(MV) 두 지표로 환각 원인을 귀인한다. 프롬프트 유형별 환각률:

| 프롬프트 유형 | 환각률 |
|-------------|--------|
| 모호한 프롬프트 | 38.3% |
| 제로샷 | 34.5% |
| 퓨샷 | 27.2% |
| 지시 기반 | 24.6% |
| Chain-of-Thought | **18.1%** |

**본 논문과의 비교**: 이 연구는 프롬프트 "스타일"(CoT vs 제로샷)에 초점을 맞추는 반면, Watson et al.은 프롬프트의 **언어 구조적 특성**(절 복잡성, 특이성 등)을 정량화하여 더 세밀한 메커니즘 설명을 제공한다. 두 연구 모두 쿼리 형태가 환각에 미치는 영향을 입증한다는 점에서 상호 보완적이다.

### 5.2 Layer-wise 정보 결핍을 통한 환각 탐지 (EMNLP 2025)

**출처**: [Detecting LLM Hallucination Through Layer-wise Information Deficiency (arXiv:2412.10246v2)](https://arxiv.org/abs/2412.10246v2)

저자: Hazel Kim, Tom A. Lamb, Adel Bibi, Philip Torr, Yarin Gal

LLM 레이어 간 정보 흐름을 추적하여 "사용 가능한 정보의 레이어 간 전달 결핍"이 환각의 징후임을 발견했다. 모호하거나 답변 불가능한 쿼리 처리 시 특정 레이어에서 정보 손실이 발생함을 보였다. 추가 학습이나 아키텍처 수정 없이 기존 LLM에 바로 적용 가능하다.

**본 논문과의 비교**: Watson et al.은 입력(쿼리) 수준에서 사전 탐지를 목표로 하지만, Kim et al.은 추론 중(레이어 수준) 탐지를 시도한다. 두 접근을 결합하면 입력 전처리 → 생성 중 모니터링의 이중 방어 체계를 구성할 수 있다.

### 5.3 프롬프트 특이성이 인용 조작에 미치는 영향 (JMIR Mental Health, 2025)

**출처**: [Influence of Topic Familiarity and Prompt Specificity on Citation Fabrication (PMC12658395)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12658395/)

정신건강 연구 도메인에서 광범위한 주제로 프롬프트 시 생성된 인용 중 정확한 것이 하나도 없었으나, 특정 주제로 구체화된 프롬프트에서는 제목은 실제 논문과 일치하되 저자 귀인만 잘못된 수준으로 품질이 향상되었다. 프롬프트 특이성이 환각의 종류와 심도를 바꾼다는 직접적 증거다.

**본 논문과의 비교**: Watson et al.의 "Lack of Specificity (OR=2.382)" 발견과 직접적으로 일치한다. 다만 이 연구는 특정 도메인(의료)에 국한되며 인용 환각이라는 세부 유형에 집중한다는 차이가 있다.

### 5.4 MetaQA: 메타모픽 프롬프트 변형 기반 환각 탐지 (ACM, 2025)

동일 프롬프트의 미세한 재표현(morphic mutations)을 통해 비공개 모델에서도 환각 불일치를 드러내는 방법론. Watson et al.의 의미 동치 파라프레이즈 생성 방법론(6개 파라프레이즈)과 메커니즘적으로 유사하나, MetaQA는 탐지를 목표로 하고 Watson et al.은 특성 연구를 목표로 한다는 점에서 다르다.

---

## 6. HXSK skill-doc-optimizer 적용 방안

**배경**: DSPy BootstrapFewShot으로 SKILL.md의 description/trigger/Quick Reference/Iron Laws를 자동 최적화하는 도구. 이 논문의 결과를 `metrics.py`와 `signatures.py`에 반영하여 더 환각-저항성 높은 스킬 문서를 자동 생성할 수 있다.

### 6.1 즉시 적용 (코드 레벨)

#### `metrics.py` — 쿼리 품질 지표 추가

논문의 Top-2 위험 특성과 Top-2 보호 특성을 `metrics.py` 평가 지표로 직접 연산:

```python
# metrics.py
def answerability_score(skill_doc: str) -> float:
    """
    Answerability (OR=0.331) - 가장 강한 보호 특성.
    SKILL.md의 trigger/description이 명확히 답변 가능한 조건을 
    기술하는지 측정.
    프록시: 구체적 조건절 수 / 전체 절 수
    """
    ...

def specificity_score(skill_doc: str) -> float:
    """
    Lack of Specificity (OR=2.382) - 가장 강한 위험 특성.
    역방향: specificity 높을수록 점수 높음.
    프록시: 구체적 명사구 밀도, 추상 형용사 비율
    """
    ...

def intention_grounding_score(skill_doc: str) -> float:
    """
    Intention Grounding (OR=0.846) - 보호 특성.
    SKILL.md description이 "무엇을(what) / 언제(when) / 왜(why)"를
    명시적으로 기술하는지 측정.
    """
    ...

def composite_hallucination_risk(skill_doc: str) -> float:
    """
    논문 Table 1 계수 가중치 적용 종합 위험도:
    risk = 0.868 * lack_of_specificity 
         - 1.106 * answerability 
         - 0.168 * intention_grounding
         + 0.568 * clause_complexity
    반환값: 0(저위험) ~ 1(고위험)
    """
    ...
```

#### `signatures.py` — DSPy Signature 개선

```python
# signatures.py
class SkillDocQualitySignature(dspy.Signature):
    """
    SKILL.md 문서 품질 평가. 
    다음 기준으로 평가하라:
    1. Answerability: 이 스킬이 어떤 상황에서 적용 가능한지 명확히 판단 가능한가?
    2. Intention Grounding: 사용자 의도와 스킬 목적이 명시적으로 연결되는가?
    3. Lack of Specificity (역방향): 모호한 표현("때에 따라", "일반적으로")이 최소화되는가?
    """
    skill_doc: str = dspy.InputField(desc="SKILL.md 문서 전문")
    answerability: float = dspy.OutputField(desc="0-1, 높을수록 답변 가능성 높음")
    intention_grounding: float = dspy.OutputField(desc="0-1, 높을수록 의도 명확화")
    specificity: float = dspy.OutputField(desc="0-1, 높을수록 구체적")
    composite_risk: float = dspy.OutputField(desc="0-1, 낮을수록 환각 위험 낮음")
    rewrite_suggestion: str = dspy.OutputField(desc="환각 위험 낮추는 핵심 재작성 제안")
```

#### BootstrapFewShot 데모 필터링 조건 강화

```python
# optimizer.py
def skill_doc_metric(example, pred, trace=None) -> float:
    """
    기존 metrics에 논문 발견 통합.
    BootstrapFewShot은 metric 통과 데모만 few-shot으로 포함.
    """
    base_score = existing_quality_score(pred)
    
    # 논문 결과 기반 패널티/보너스
    lack_specificity_penalty = 0.868 * measure_lack_of_specificity(pred)
    answerability_bonus = 1.106 * measure_answerability(pred)
    intention_bonus = 0.168 * measure_intention_grounding(pred)
    
    adjusted_score = base_score - lack_specificity_penalty + answerability_bonus + intention_bonus
    return min(1.0, max(0.0, adjusted_score))
```

### 6.2 중기 적용 (설계 레벨)

**쿼리-특성 벡터 기반 SKILL.md 사전 분류기 구축**

논문의 17차원 벡터를 SKILL.md description/trigger 섹션에 적용하여, BootstrapFewShot 실행 전 "위험 프로파일"을 산출한다:

```
risk_profile(skill_doc) → {
  "risk_level": "Safe|Borderline|Risky",
  "top_risk_features": ["lack_of_specificity", "clause_complexity"],
  "recommended_interventions": [
    "add disambiguating constraints to trigger section",
    "explicitly state intent in description"
  ]
}
```

**추출형 vs 생성형 차별화 최적화**

논문 Figure 3의 발견(추출형은 쿼리 길이 증가에 환각 위험 안정, 생성형은 급격히 증가)을 반영하여:
- Iron Laws 같은 제약적 출력 → 추출형 형식으로 최적화 (환각 저위험)
- Quick Reference 같은 생성적 설명 → Answerability/Intention Grounding 강화 집중

**LODO-스타일 교차검증으로 최적화 안정성 검증**

논문의 Leave-One-Dataset-Out 방법론을 차용하여, 특정 스킬 카테고리를 제외한 상태로 최적화기를 검증. 최적화된 SKILL.md가 특정 스킬 유형에 과적합되지 않음을 보장.

### 6.3 장기 연구 방향

**1. 의미 동치 섭동 기반 스킬 강인성 테스트**

논문의 "6개 파라프레이즈 → 환각 위험도" 측정 방식을 차용:
- SKILL.md의 trigger 절에 대해 N개 의미 동치 변형 생성
- 각 변형으로 에이전트를 호출했을 때 동일한 스킬이 발동되는지 확인
- 불안정성 높은 trigger → 자동 재작성 제안

**2. Cluster-aware 특성 최적화**

논문 Figure 6의 클러스터 발견(구문 복잡성 클러스터 ↔ 의미 근거화 클러스터 ↔ 모호성 클러스터)을 반영한 클러스터별 차별화 전략:
- 구문 복잡성 클러스터(토큰 길이, 절 수): 역관계 — 길고 구조화된 SKILL.md가 오히려 환각 저위험
- 의미 근거화 클러스터(Answerability, Intention Grounding): 가장 강한 보호 효과 — 최우선 최적화 대상

**3. 다국어 확장**

논문의 한계(영어 전용)를 극복하여 한국어 SKILL.md의 언어 특성(조사 중의성, 주어 생략 관용 등)이 환각에 미치는 영향 연구. HXSK가 한국어/영어 혼용 환경이라는 점에서 직접적 실용 가치가 있다.

---

## 7. 결론

Watson et al. (2026)은 LLM 환각 연구에서 중요한 관점 전환을 제공한다. 환각을 모델의 고정된 결함이 아니라 **쿼리 언어 특성의 함수**로 재정의함으로써, 사전적(proactive) 완화 전략의 가능성을 열었다.

핵심 실천 원칙:
1. **Answerability 최우선**: OR=0.331로 단일 특성 중 가장 강한 보호 효과. SKILL.md의 모든 trigger 절은 "이 조건에서 발동 가능한가?"를 명확히 답할 수 있어야 한다.
2. **Specificity 확보**: OR=2.382로 가장 위험한 특성. "일반적으로", "때에 따라" 같은 표현을 제거하고 구체적 조건을 명시한다.
3. **Intention Grounding 명시**: 스킬의 목적(what/when/why)이 명시적으로 기술되어 있으면 환각 위험이 구조적으로 낮아진다.

HXSK skill-doc-optimizer 관점에서, 이 논문은 DSPy BootstrapFewShot의 **metric 함수**와 **Signature 설계**를 언어학적으로 검증된 지표로 강화할 수 있는 직접적 근거를 제공한다. 특히 `composite_hallucination_risk` 지표를 최적화 목표에 통합하면, 단순히 "출력이 있는가"를 넘어 "구조적으로 환각에 강한 스킬 문서인가"를 자동으로 판별하는 optimizer를 구현할 수 있다.

---

## 참고 문헌 및 출처

- Watson, W. et al. (2026). "What Makes a Good Query?" arXiv:2602.20300. https://huggingface.co/papers/2602.20300
- [Survey and analysis of hallucinations: attribution to prompting strategies (Frontiers in AI, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12518350/)
- [Detecting LLM Hallucination Through Layer-wise Information Deficiency (EMNLP 2025, arXiv:2412.10246v2)](https://arxiv.org/abs/2412.10246v2)
- [Influence of Prompt Specificity on Citation Fabrication in Mental Health Research (JMIR, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12658395/)
- [DSPy BootstrapFewShot Optimizer Documentation](https://dspy.ai/api/optimizers/BootstrapFewShot/)
- [Large Language Models Hallucination: A Comprehensive Survey (arXiv:2510.06265)](https://arxiv.org/abs/2510.06265)
