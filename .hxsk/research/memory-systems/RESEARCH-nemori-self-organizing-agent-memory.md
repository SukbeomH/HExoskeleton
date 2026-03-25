# RESEARCH: Nemori — Self-Organizing Agent Memory Inspired by Cognitive Science

> **Date**: 2026-02-04
> **Sources**:
> - 논문: [arXiv 2508.03341v3](https://arxiv.org/html/2508.03341v3) — Jiayan Nan, Wenquan Ma, Wenlong Wu, Yize Chen (Tongji Univ., SUFE, Beihang Univ., Tanka AI)

---

## 1. 문제 정의

### LLM 메모리의 근본적 한계

| 기존 접근법 | 한계 |
|------------|------|
| **Full Context** | 토큰 비용 폭증, 긴 대화에서 핵심 정보 희석 |
| **RAG (Retrieval-Augmented Generation)** | 정적 지식 베이스용 설계, 동적 대화 메모리에 부적합 |
| **단순 요약/추출** | 수동적(passive) 저장 — 정보 손실 불가피, 시간적 추론 약함 |
| **임의 청킹 (메시지 단위, 턴 단위)** | 의미적 경계 무시, granularity 문제 |

**핵심 질문**: 대화 스트림을 인간의 일화적 기억(episodic memory)처럼 자기 조직화(self-organize)하여, 적은 토큰으로도 높은 품질의 맥락을 유지할 수 있는가?

---

## 2. Nemori 핵심 개념

메모리 구성을 "수동적 저장(passive storage)"에서 **"능동적 학습(active learning)"**으로 재정의한다. 인지과학의 두 가지 원리를 LLM 에이전트 메모리에 적용.

### 2가지 인지과학 기반 원칙

| 원칙 | 인지과학 기반 | 역할 |
|------|-------------|------|
| **Two-Step Alignment** | Event Segmentation Theory | 대화 스트림 → 의미적 에피소드 분할 + 서사적 표현 생성 |
| **Predict-Calibrate** | Free-energy Principle | 예측-교정 사이클로 지식을 능동적으로 진화 |

---

## 3. 아키텍처 상세

### 3.1 Topic Segmentation (주제 분할)

LLM 기반 경계 감지기가 대화를 의미적으로 일관된 에피소드로 자율 분할.

**분할 트리거 조건:**
- 의미적 전환(semantic shift)이 높은 신뢰도로 감지될 때
- 버퍼 용량이 사전 설정된 한계에 도달할 때

**평가 기준:** 맥락 일관성(contextual coherence), 시간 마커(temporal markers), 의도 전환(intent shifts)

### 3.2 Episodic Memory Generation (일화적 기억 생성)

분할된 대화 세그먼트를 구조화된 튜플로 변환:
- **간결한 제목**: 에피소드 식별용
- **3인칭 서사(narrative)**: 상호작용의 핵심 세부사항과 시간 순서를 보존

→ 인간이 과거 경험을 "이야기"로 기억하는 방식을 모방

### 3.3 Semantic Memory Generation (의미적 기억 생성)

**Predict-Calibrate 3단계 사이클:**

```
1. Prediction: 기존 메모리 기반으로 새 에피소드 내용 예측
2. Calibration: 예측과 실제 대화 비교 → 예측 격차(prediction gap) 식별
3. Integration: 새롭게 증류된 지식을 의미적 메모리 DB에 통합
```

핵심 인사이트: 전체 내용을 무차별 저장하지 않고, **예측 오류(prediction error)에서만 학습**한다. 이미 아는 것은 저장하지 않음.

### 3.4 Unified Memory Retrieval (통합 검색)

- Dense embedding 기반 벡터 검색
- Cosine similarity로 episodic + semantic 메모리 동시 접근
- 설정 가능한 임계값(threshold)으로 관련성 필터링

---

## 4. 실험 결과

### 4.1 LoCoMo 벤치마크

| 모델 | LLM Score | 사용 토큰 | 토큰 절감 |
|------|-----------|----------|----------|
| Full Context baseline | 0.723 | 23,653 | — |
| **Nemori (gpt-4o-mini)** | **0.744** | **2,745** | **88%** |
| Nemori (gpt-4.1-mini) | 0.794 | 2,745 | 88% |

**특히 시간적 추론(temporal reasoning)에서 강점:**
- 점수: 0.710–0.776
- 예시: "Jon이 멘토링을 받은 시기는?" → Nemori는 2023년 6월 15일 정확 식별, Full Context는 시간 참조 오해석

### 4.2 LongMemEvalS 벤치마크

| 모델 | 평균 정확도 | 컨텍스트 절감 |
|------|-----------|-------------|
| Nemori (gpt-4o-mini) | 64.2% | 95–96% |
| Nemori (gpt-4.1-mini) | 74.6% | 95–96% |

- 최대 105K 토큰 컨텍스트에서도 일관된 성능
- 사용자 선호도(preference) 태스크에서 특히 우수 — 증류된 고품질 메모리 덕분

### 4.3 Ablation Study 주요 발견

| 변형 | 점수 | 시사점 |
|------|------|--------|
| 전체 프레임워크 제거 | ~0 | 프레임워크 필수 |
| Predict-Calibrate | 0.615 | — |
| Naive extraction (대체) | 0.518 | 능동적 학습이 수동 추출보다 우수 |
| Episodic memory 제거 | 큰 성능 하락 | Episodic이 Semantic보다 영향 큼 |

### 4.4 하이퍼파라미터 분석

- 검색할 episodic memory 수(k): 2→10에서 급격히 성능 향상
- k=10 이후 성능 정체 → **소규모 검색으로도 효율적**

---

## 5. 기존 연구 대비 차별점

| 비교 축 | 기존 시스템 (HEMA, Mem0 등) | Nemori |
|---------|--------------------------|--------|
| **청킹 방식** | 임의 단위 (메시지, 턴) | 자율적 top-down 에피소드 감지 |
| **학습 방식** | 수동적 요약/추출 | 능동적 예측-교정 (prediction gap 학습) |
| **메모리 구조** | 단일 계층 | 이중 계층 (episodic + semantic) |
| **설계 근거** | 엔지니어링 휴리스틱 | 인지과학 원리 기반 (EST, FEP) |
| **토큰 효율** | Full context 대비 중간 절감 | 88–96% 절감 |

---

## 6. 본 프로젝트 적용 가능성

### 현재 메모리 시스템과의 비교

본 프로젝트의 `.gsd/memories/` 파일 기반 메모리 시스템과 Nemori의 개념적 대응:

| Nemori 개념 | 현재 시스템 대응 | 격차 |
|------------|----------------|------|
| Episodic Memory | `session-summary`, `session-snapshot` | 서사적 형태가 아닌 구조적 요약 |
| Semantic Memory | `architecture-decision`, `pattern-discovery` 등 | 유사하나 Predict-Calibrate 없음 |
| Topic Segmentation | 수동 메모리 저장 (트리거 기반) | 자동 분할 없음 |
| Unified Retrieval | Grep/Glob 기반 텍스트 검색 | 벡터 검색 없음 (의미적 검색 불가) |

### 도입 가능한 아이디어

1. **Predict-Calibrate 원칙 경량 적용**: 새 메모리 저장 시 기존 메모리와 비교하여 "이미 아는 것"은 저장하지 않는 중복 제거 로직
2. **에피소드 서사화**: `session-summary`를 3인칭 서사(narrative) 형태로 전환하여 검색 품질 향상
3. **자동 분할 트리거**: 대화 맥락 전환 감지 시 자동으로 에피소드 경계 생성

---

## 7. 핵심 인사이트 요약

1. **메모리는 저장이 아니라 학습이다**: 수동적 추출보다 능동적 예측-교정이 18.7% 더 효과적 (0.518 → 0.615)
2. **의미적 분할이 임의 분할을 압도한다**: 자율적 에피소드 경계 감지가 핵심
3. **이중 메모리 구조가 단일보다 낫다**: Episodic(경험) + Semantic(지식) 조합이 시너지 발생
4. **88–96% 토큰 절감으로도 Full Context를 능가**: 잘 조직된 소량 메모리 > 무차별 대량 컨텍스트
5. **인지과학 원리가 엔지니어링 직관보다 우수한 설계 기반 제공**: EST와 FEP가 체계적 프레임워크 역할
