# RESEARCH: LLM 에이전트를 위한 온톨로지 구성 — 연구·프로젝트·구현 사례

> **Date**: 2026-02-04
> **Scope**: 지식 그래프(KG)·시맨틱 임베딩을 넘어, **온톨로지(Ontology)** 구성을 LLM 에이전트 메모리·추론에 명시적으로 활용한 연구와 프로젝트

---

## 1. 배경: 왜 온톨로지인가

| 접근법 | 제공하는 것 | 부족한 것 |
|--------|-----------|----------|
| **벡터 임베딩** | 의미적 유사도 검색 | 구조적 관계, 추론 규칙 없음 |
| **지식 그래프** | 엔티티 간 관계 (who-what-how) | 형식적 의미론, 추론 규칙 없음 |
| **온톨로지** | 클래스 계층, 속성 정의, 추론 규칙(OWL/RDF) | 구축 비용 높음, 동적 확장 어려움 |

온톨로지는 KG에 **"규칙서(rule book)"**를 제공한다. 명시되지 않은 것도 **논리적으로 추론** 가능하게 하며, 도메인 간 **상호운용성(interoperability)**을 보장한다. LLM 에이전트 메모리에 온톨로지를 결합하면, 단순 검색을 넘어 **구조적 추론**이 가능해진다.

---

## 2. 학술 연구

### 2.1 KNOW — 일상 지식을 위한 실세계 온톨로지

> **논문**: [KNOW: A Real-World Ontology for Knowledge Capture with Large Language Models](https://arxiv.org/html/2405.19877) (arXiv:2405.19877, May 2024)
> **저자**: Haltia.AI 연구팀

- **목적**: LLM 기반 개인 비서가 사용자의 일상 지식을 구조적으로 캡처하기 위한 최초의 온톨로지
- **도메인**: 인간 생활 — 시공간(장소, 이벤트) + 사회적(사람, 그룹, 조직)
- **설계 원칙**: Schema.org와 Cyc의 교훈을 반영하되, LLM이 이미 내재적으로 보유한 상식 지식과 보완적으로 작동
- **핵심 기여**: 12개 프로그래밍 언어용 코드 생성 라이브러리 제공 → 온톨로지 개념을 직접 코드에서 사용 가능
- **시사점**: LLM 에이전트가 사용자 정보를 **온톨로지 스키마에 맞춰** 구조화하면, 더 정확하고 일관된 응답 가능

### 2.2 Prompt-Time Ontology-Driven Symbolic Knowledge Capture

> **논문**: [Prompt-Time Ontology-Driven Symbolic Knowledge Capture with Large Language Models](https://arxiv.org/abs/2405.14012) (arXiv:2405.14012, May 2024)
> **저자**: Tolga Çöplü et al. (Haltia.AI)
> **코드**: [github.com/HaltiaAI/paper-PTODSKC](https://github.com/HaltiaAI/paper-PTODSKC)

- **접근**: KNOW 온톨로지의 서브셋으로 LLM을 **파인튜닝**하여 사용자 프롬프트에서 개인정보를 자동 캡처
- **메커니즘**:
  1. LLM이 온톨로지의 클래스, 객체 속성, 데이터 속성을 학습
  2. 사용자 발화에서 해당 개념에 맞는 트리플을 추출 → KG 자동 생성(populate)
  3. 온톨로지 범위 밖 발화는 무시하도록 out-of-context 샘플로 훈련
- **핵심 인사이트**: 온톨로지가 **캡처 범위를 제한(restrict)**하고, **의미론을 정의(define)**하며, LLM 응답 품질을 향상

### 2.3 SciAgents — 온톨로지 KG 기반 다중 에이전트 과학 발견

> **논문**: [SciAgents: Automating Scientific Discovery Through Multi-Agent Intelligent Graph Reasoning](https://arxiv.org/abs/2409.05556) (arXiv:2409.05556, Sep 2024)
> **게재**: *Advanced Materials* (Wiley, 2025)
> **코드**: [github.com/lamm-mit/SciAgentsDiscovery](https://github.com/lamm-mit/SciAgentsDiscovery)

- **3대 핵심 요소**: (1) 대규모 온톨로지 KG, (2) LLM 도구 모음, (3) in-situ 학습 가능한 다중 에이전트 시스템
- **온톨로지 역할**: ~1,000편 논문에서 구축한 생체재료 온톨로지 KG가 가설 생성의 중심
- **성과**: 이전에 무관하다고 여겨진 분야 간 숨겨진 관계를 발견, 인간 주도 연구를 초월하는 탐색력
- **구현**: AG2(구 AutoGen) 기반 모듈식 멀티에이전트

### 2.4 KARMA — 멀티에이전트 LLM 온톨로지 기반 KG 보강

> **논문**: [KARMA: Leveraging Multi-Agent LLMs for Automated Knowledge Graph Enrichment](https://arxiv.org/abs/2502.06472) (NeurIPS 2025 Spotlight)
> **저자**: Yuxing Lu, Jinzhuo Wang (Peking Univ.)

- **9개 협업 에이전트**: Entity Extraction → Relation Extraction → **Schema Alignment** → Conflict Resolution → Evaluator
- **Schema Alignment Agent (SAA)**: 새로운 엔티티/관계를 **기존 KG 온톨로지 스키마에 매핑**하거나, 온톨로지 확장 플래그 생성
- **성과**: PubMed 1,200편에서 38,230개 신규 엔티티 식별, 83.1% LLM 검증 정확도
- **핵심**: **고정된 온톨로지 경계 내에서** 스키마 가이드 추출 수행 → 정확한 엔티티 정규화와 관계 분류 보장

### 2.5 EverMemOS — 자기 조직화 메모리 OS

> **논문**: [EverMemOS: A Self-Organizing Memory Operating System for Structured Long-Horizon Reasoning](https://arxiv.org/abs/2601.02163) (Jan 2026)
> **코드**: [github.com/EverMind-AI/EverMemOS](https://github.com/EverMind-AI/EverMemOS)

- **3단계 라이프사이클** (engram 영감):
  1. **Episodic Trace Formation**: 대화 → MemCell (에피소드 흔적, 원자적 사실, Foresight 신호)
  2. **Semantic Consolidation**: MemCell → MemScene (주제별 조직화, 사용자 프로필 갱신)
  3. **Reconstructive Recollection**: MemScene 기반 에이전틱 검색으로 필요충분 컨텍스트 구성
- **온톨로지적 측면**: MemCell/MemScene 구조가 사실상 **암묵적 온톨로지** 역할 — 원자적 사실·시간 경계·주제 계층을 형식화
- **성과**: LoCoMo, LongMemEval에서 SOTA

### 2.6 Agent-OM — 온톨로지 매칭을 위한 LLM 에이전트

> **논문**: [Agent-OM: Leveraging LLM Agents for Ontology Matching](https://arxiv.org/html/2312.00326) (arXiv:2312.00326, Dec 2023)

- **목적**: LLM 에이전트가 서로 다른 온톨로지 간 매칭(alignment) 수행
- **공유 메모리 모듈**: 대화와 하이브리드 데이터 저장소로 엔티티 매핑 검색/저장
- **성과**: 단순 OM 태스크에서 기존 최고 성능에 근접, 복잡/few-shot OM에서 유의미 향상
- **시사점**: 에이전트가 온톨로지를 **소비(consume)**할 뿐 아니라 **정렬(align)**하는 역할 수행 가능

---

## 3. 프로덕션 프로젝트/프레임워크

### 3.1 Cognee — 온톨로지 통합 AI 에이전트 메모리

> **GitHub**: [topoteretes/cognee](https://github.com/topoteretes/cognee) (7,000+ stars, Apache-2.0)
> **블로그**: [Ontology AI Memory](https://www.cognee.ai/blog/deep-dives/ontology-ai-memory)
> **논문**: [Optimizing the Interface Between KG and LLMs](https://arxiv.org/abs/2505.24478) (2025)

- **핵심 API**: `.add()` → `.cognify()` → `.search()` — 3단계로 메모리 구축
- **온톨로지 통합**: OWL 온톨로지를 로드하여 KG와 융합 가능 (~20줄 코드)
- **백엔드**: Neo4j, FalkorDB, KuzuDB (그래프) + Qdrant, Weaviate (벡터) + SQLite/Postgres (관계형)
- **에이전트 연동**: Claude Agent SDK (MCP), LangChain 등 6+ 프레임워크 통합
- **적용 사례**: RAG를 넘어 그래프+벡터+추론을 통합한 에이전트 메모리 레이어

```python
# Cognee 온톨로지 통합 예시 (간략)
import cognee
await cognee.add("data source text")
await cognee.cognify(ontology="domain.owl")  # OWL 온톨로지와 융합
results = await cognee.search("query", search_type="GRAPH_COMPLETION")
```

### 3.2 Ontology Memorization System (Neo4j + LangGraph)

> **출처**: [Why LLMs Keep Forgetting Ontologies (And How to Fix It)](https://medium.com/@aiwithakashgoyal/building-an-ontology-memorization-system-c66bb21196cc) (Dec 2025, Akash Goyal)

- **문제 인식**: 검색 기반 접근은 stateless, 프롬프트는 fragile, 온톨로지가 수동적 참조에 그침
- **해결책**: Neo4j 그래프 DB + LangGraph 에이전트로 온톨로지를 **활성 메모리(active memory)**로 유지
- **메커니즘**: AI 시스템이 구조화된 지식을 retain → validate → reuse하는 전용 메모리 레이어

### 3.3 Zep/Graphiti — 시간적 KG 에이전트 메모리

> **출처**: [Zep: A Temporal Knowledge Graph Architecture for Agent Memory](https://blog.getzep.com/content/files/2025/01/ZEP__USING_KNOWLEDGE_GRAPHS_TO_POWER_LLM_AGENT_MEMORY_2025011700.pdf)

- **Graphiti 엔진**: 비구조적 대화 + 구조적 비즈니스 데이터를 시간적 KG로 동적 합성
- **온톨로지 관련**: 도메인 특화 온톨로지와 그래프 온톨로지의 통합을 향후 과제로 명시
- **현재 위치**: 온톨로지를 완전히 구현하지는 않았으나, 시간적 관계 유지를 통해 부분적 온톨로지적 구조 제공

### 3.4 ontology-llm — LangChain 기반 온톨로지 매칭

> **GitHub**: [qzc438-research/ontology-llm](https://github.com/qzc438-research/ontology-llm)

- LangChain 에이전트를 활용한 온톨로지 매칭 태스크
- Zero-shot (온톨로지 정보 없이) vs Few-shot (온톨로지 정보 포함) 비교 실험
- 경량 연구 프로젝트 수준

---

## 4. 관련 서베이 및 리소스

| 리소스 | 링크 | 핵심 내용 |
|--------|------|----------|
| Memory in the Age of AI Agents (Paper List) | [GitHub](https://github.com/Shichun-Liu/Agent-Memory-Paper-List) | 에이전트 메모리 논문 종합 목록 (2024-2026) |
| LLM-empowered KG Construction Survey | [arXiv:2510.20345](https://arxiv.org/pdf/2510.20345) | LLM 기반 KG 구축 전체 서베이, 온톨로지 구성 포함 |
| KG-LLM-Papers | [GitHub](https://github.com/zjukg/KG-LLM-Papers) | KG+LLM 통합 논문 목록 (OntoTune, KNOW 등 포함) |
| Ontology Learning vs KG Construction for RAG | [arXiv:2511.05991](https://arxiv.org/html/2511.05991v1) | 온톨로지 학습과 KG 구축이 RAG 성능에 미치는 영향 비교 |
| LLMs in Bio-Ontology Research | [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12649945/) | 바이오 도메인 온톨로지+LLM 종합 리뷰 |

---

## 5. 분류 및 성숙도 맵

```
                    온톨로지 활용 깊이
                    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→
                    암묵적                명시적 (OWL/RDF)

  에이전트         EverMemOS            SciAgents
  메모리용         A-Mem                Cognee (OWL 통합)
  ↑               Nemori               KNOW + PTODSKC
  |                                    Ontology Memorization
  |
  KG 구축/        KARMA (Schema        Agent-OM
  보강용          Alignment Agent)      ontology-llm
```

### 성숙도 평가

| 프로젝트 | 유형 | 성숙도 | 온톨로지 통합 수준 |
|---------|------|--------|------------------|
| Cognee | 프로덕션 프레임워크 | ★★★★☆ | OWL 직접 로드, 그래프 융합 |
| KNOW + PTODSKC | 학술 연구 + 코드 | ★★★☆☆ | 전용 온톨로지 설계, 파인튜닝 |
| SciAgents | 학술 연구 + 코드 | ★★★☆☆ | 도메인 온톨로지 KG 기반 발견 |
| KARMA | 학술 연구 (NeurIPS) | ★★★☆☆ | 스키마 정렬 에이전트 |
| EverMemOS | 학술 연구 + 코드 | ★★★☆☆ | 암묵적 온톨로지 (MemCell/MemScene) |
| Ontology Memorization | 블로그/PoC | ★★☆☆☆ | Neo4j + LangGraph PoC |
| Agent-OM | 학술 연구 | ★★☆☆☆ | 온톨로지 매칭 특화 |

---

## 6. 본 프로젝트 적용 시사점

### 현재 시스템 대비 격차

현재 `.gsd/memories/` 시스템은 **14개 타입 디렉토리**로 메모리를 분류하는데, 이는 사실상 **평면적 분류 체계(taxonomy)**이다. 온톨로지가 제공하는 **계층 구조, 속성 정의, 추론 규칙**은 없음.

### 단계적 도입 로드맵

| 단계 | 내용 | 복잡도 |
|------|------|--------|
| **1단계: 타입 간 관계 정의** | 14개 메모리 타입 간 관계를 YAML로 명시 (예: `root-cause` → `debug-eliminated` is-resolved-by) | 낮음 |
| **2단계: 메모리 간 명시적 링크** | frontmatter에 `related:` 필드 추가 (A-Mem 스타일) | 낮음 |
| **3단계: 경량 온톨로지 스키마** | 메모리 타입별 필수/선택 속성을 JSON Schema로 정의 → 저장 시 검증 | 중간 |
| **4단계: Cognee 통합 검토** | OWL 온톨로지 + 벡터·그래프 검색 통합 (MCP 서버로 연결) | 높음 |

### 즉시 적용 가능한 아이디어

1. **KNOW 온톨로지 참조**: 사용자 관련 메모리(`session-summary` 등)의 속성을 KNOW의 시공간+사회적 분류 체계에 맞춰 구조화
2. **Schema Alignment 패턴**: KARMA의 SAA처럼, 새 메모리 저장 시 기존 타입 스키마에 매핑 → 맞지 않으면 타입 확장 제안
3. **Predict-then-Store**: Nemori의 Predict-Calibrate + 온톨로지 스키마 결합 → "온톨로지에 정의된 속성 중 아직 채워지지 않은 것"을 예측 질문으로 생성

---

## 7. 핵심 인사이트 요약

1. **온톨로지 for LLM Agent는 초기 단계지만 가속 중**: 2024년 KNOW/PTODSKC에서 시작, 2025년 KARMA/SciAgents/Cognee로 확산
2. **"명시적 온톨로지" 사용 사례는 아직 소수**: 대부분 KG 수준에 머물러 있으며, OWL/RDF를 직접 활용하는 에이전트 메모리는 Cognee가 유일한 프로덕션급
3. **온톨로지의 핵심 가치는 "제한과 추론"**: 무엇을 캡처할지 제한(restrict)하고, 명시되지 않은 것을 추론(infer)하는 능력
4. **파인튜닝 vs 프롬프트**: PTODSKC는 파인튜닝으로 온톨로지를 내재화, Cognee는 런타임에 OWL 로드 — 두 접근 모두 유효
5. **멀티에이전트 + 온톨로지가 유망**: KARMA(9 에이전트), SciAgents(멀티에이전트) 모두 온톨로지를 에이전트 협업의 공유 스키마로 활용
6. **본 프로젝트의 14개 타입 체계는 taxonomy → ontology 확장의 좋은 출발점**: 타입 간 관계와 속성 스키마만 추가해도 상당한 구조적 이점 확보 가능
