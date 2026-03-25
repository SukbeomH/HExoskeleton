# RESEARCH: A-Mem — Agentic Memory for LLM Agents

> **Date**: 2026-02-04
> **Sources**:
> - 논문: [arXiv 2502.12110v11](https://arxiv.org/html/2502.12110v11) — Wujiang Xu, Zujie Liang, Kai Mei, Hang Gao, Juntao Tan, Yongfeng Zhang (Rutgers Univ., AIOS Foundation)
> - 코드: [WujiangXu/AgenticMemory](https://github.com/WujiangXu/AgenticMemory) (벤치마크), [WujiangXu/A-mem-sys](https://github.com/WujiangXu/A-mem-sys) (프로덕션)

---

## 1. 문제 정의

### 기존 메모리 시스템의 한계

| 접근법 | 한계 |
|--------|------|
| **Full Context (LoCoMo)** | 토큰 비용 폭증 (16,900 토큰), 긴 대화에서 성능 저하 |
| **ReadAgent** | 3단계 처리(에피소드 분할→요약→검색) — 구조가 사전 결정됨 |
| **MemoryBank** | Ebbinghaus 망각 곡선 기반이나 메모리 간 연결 없음 |
| **MemGPT** | 이중 계층 가상 컨텍스트 — 메모리 진화(evolution) 부재 |

**핵심 문제**: 기존 시스템은 메모리를 **수동적으로 저장**하고 **검색 단계에서만 에이전시**를 발휘한다. 저장·조직·진화 단계에서의 자율성이 부재.

---

## 2. A-Mem 핵심 개념

**Zettelkasten(제텔카스텐)** 노트 방법론에서 영감. 사전 정의된 구조 없이 메모리가 **자율적으로 연결 네트워크를 형성**하고, 새로운 경험이 들어올 때 기존 메모리가 **능동적으로 진화**한다.

### 3가지 핵심 메커니즘

| 메커니즘 | 역할 | 기존 대비 차별점 |
|---------|------|----------------|
| **Note Construction** | 7개 속성의 구조화된 메모리 노트 생성 | 단순 텍스트 저장이 아닌 다면적 표현 |
| **Link Generation** | 메모리 간 의미적 연결 자동 수립 | 고립된 메모리 → 연결된 지식 네트워크 |
| **Memory Evolution** | 새 정보 유입 시 기존 메모리 업데이트 | 정적 저장 → 동적 진화 |

---

## 3. 아키텍처 상세

### 3.1 Note Construction (노트 구성)

각 메모리 노트는 **7개 구성요소**로 이루어짐:

```
c_i: 원본 콘텐츠 (original content)
t_i: 타임스탬프 (timestamp)
K_i: LLM 생성 키워드 (keywords)
G_i: 태그 (tags)
X_i: 맥락적 설명 (contextual description) — LLM이 자율 생성
e_i: 임베딩 벡터 (embedding vector)
L_i: 연결된 메모리 목록 (linked memories)
```

→ 메모리가 "스스로 자신을 설명"하는 능력 보유. 검색 시 다양한 경로로 접근 가능.

### 3.2 Link Generation (연결 생성)

1. 새 노트의 임베딩과 기존 메모리들의 cosine similarity 계산
2. 유사한 메모리 후보 검색
3. LLM이 공유 속성(키워드, 태그, 맥락) 분석하여 **의미적 연결 여부 판단**
4. 연결 수립 — 사전 정의 스키마 불필요

→ Zettelkasten의 핵심: 하나의 메모리가 **여러 "상자"(concept group)에 동시 소속** 가능

### 3.3 Memory Evolution (메모리 진화)

새 메모리 유입 시 기존 관련 메모리도 업데이트:
- 맥락적 설명(X_i) 갱신
- 키워드(K_i), 태그(G_i) 보강
- 연결 관계(L_i) 재구성

→ **지식 구조의 지속적 정제**. 고차 패턴(higher-order pattern) 발견 가능.

### 3.4 Memory Retrieval (검색)

- 쿼리 임베딩 계산 → cosine similarity로 top-k 검색
- 검색된 메모리의 **연결된 이웃(linked neighbors)도 함께 반환**
- 그래프 탐색 효과: 직접 매칭되지 않는 관련 메모리도 접근 가능

---

## 4. 실험 결과

### 4.1 LoCoMo 벤치마크 (GPT-4o-mini)

| 태스크 | A-Mem F1 | LoCoMo F1 | 향상 |
|--------|----------|-----------|------|
| Multi-Hop | 27.02 | 25.02 | +8.0% |
| Temporal | **45.85** | **18.41** | **+149%** |
| Open Domain | 12.14 | — | — |

**시간적 추론에서 2.5배 성능 향상**이 가장 주목할 만한 결과.

### 4.2 토큰 효율성

| 지표 | A-Mem | Baseline |
|------|-------|----------|
| 사용 토큰 | ~1,200 | ~16,900 |
| **토큰 절감** | **85–93%** | — |
| 처리 시간 (GPT-4o-mini) | 5.4초 | — |
| 처리 시간 (Llama 3.2 1B) | 1.1초 | — |
| 건당 비용 | <$0.0003 | — |

### 4.3 DialSim 벤치마크 (TV 드라마 장기 대화)

| 시스템 | F1 |
|--------|-----|
| MemGPT | 1.18 |
| LoCoMo | 2.55 |
| **A-Mem** | **3.45** (+35% vs LoCoMo, +192% vs MemGPT) |

ROUGE-L, ROUGE-2, METEOR, SBERT 전 지표에서 일관 우위.

### 4.4 Ablation Study

| 구성 | Multi-Hop F1 | Temporal F1 | Open Domain F1 |
|------|-------------|-------------|----------------|
| Link 제거 + Evolution 제거 | 9.65 | 24.55 | 7.77 |
| Evolution만 제거 (Link만) | 21.35 | 31.24 | 10.13 |
| **Full A-Mem** | **27.02** | **45.85** | **12.14** |

**시사점:**
- Link Generation이 기반 조직화 제공 (9.65 → 21.35)
- Memory Evolution이 핵심 정제 역할 (21.35 → 27.02)
- 두 메커니즘의 **시너지 효과**가 Temporal F1에서 극적 (24.55 → 45.85)

### 4.5 스케일링 분석

| 메모리 수 | 저장 용량 | 검색 시간 |
|----------|----------|----------|
| 1,000 | 1.46 MB | 0.31 μs |
| 10,000 | 14.65 MB | 0.38 μs |
| 100,000 | 146.48 MB | 1.40 μs |
| 1,000,000 | 1,464.84 MB | 3.70 μs |

공간 복잡도 O(N), 검색 시간은 백만 건에서도 3.70μs — 실용적 확장성 확인.

---

## 5. 다른 메모리 시스템과의 비교

### A-Mem vs Nemori (arXiv 2508.03341)

| 비교 축 | Nemori | A-Mem |
|---------|--------|-------|
| **이론 기반** | 인지과학 (EST, FEP) | Zettelkasten 방법론 |
| **메모리 구조** | Episodic + Semantic (이중 계층) | 연결된 노트 네트워크 (그래프) |
| **학습 방식** | Predict-Calibrate (예측 오류 학습) | Memory Evolution (기존 노트 갱신) |
| **청킹** | 자율적 에피소드 분할 | 대화 단위 노트 생성 |
| **검색** | 벡터 검색 (독립) | 벡터 검색 + 그래프 탐색 (이웃 포함) |
| **강점** | 에피소드 서사화, 토큰 효율 | 메모리 간 연결, 동적 진화 |

→ 두 시스템은 **상호보완적**. Nemori의 에피소드 분할 + A-Mem의 연결 그래프를 결합하면 강력한 메모리 시스템 가능.

---

## 6. 본 프로젝트 적용 가능성

### 현재 메모리 시스템과의 비교

| A-Mem 개념 | 현재 시스템 대응 | 격차 |
|-----------|----------------|------|
| 7-속성 노트 구조 | YAML frontmatter (title, tags, type, created) | 키워드, 맥락 설명, 임베딩, 연결 없음 |
| Link Generation | 없음 (메모리 간 독립적) | 관련 메모리 탐색이 수동 Grep에 의존 |
| Memory Evolution | 없음 (write-once) | 기존 메모리 갱신 메커니즘 부재 |
| 그래프 검색 | Grep/Glob 텍스트 검색 | 의미적 연결 기반 탐색 불가 |

### 도입 가능한 아이디어

1. **메모리 간 명시적 연결**: frontmatter에 `related: [파일명1, 파일명2]` 필드 추가 → 관련 메모리 그래프 구축
2. **메모리 갱신 프로토콜**: 새 메모리 저장 시 기존 관련 메모리의 tags/description 갱신 허용 (현재는 write-once)
3. **다면적 노트 구조**: keywords, contextual description 필드를 frontmatter에 추가하여 검색 품질 향상
4. **이웃 검색**: 관련 메모리를 찾으면 그 메모리에 연결된 메모리도 함께 반환하는 2-hop 검색

---

## 7. 핵심 인사이트 요약

1. **저장 단계의 에이전시가 핵심**: 검색뿐 아니라 저장·조직·진화에서도 LLM의 자율성 필요
2. **메모리 간 연결이 시간적 추론을 2.5배 향상**: 고립된 메모리로는 multi-hop, temporal 추론이 어려움
3. **Memory Evolution이 고차 패턴을 발견**: 정적 저장 대비 ablation에서 Temporal F1 31.24 → 45.85
4. **Zettelkasten 원칙의 유효성**: 사전 정의 스키마 없이도 의미적 네트워크 자율 형성 가능
5. **실용적 확장성**: 100만 건 메모리에서도 3.70μs 검색, 건당 $0.0003 미만 비용
6. **Nemori와 상호보완적**: 에피소드 분할(Nemori) + 연결 그래프(A-Mem) 결합이 이상적
