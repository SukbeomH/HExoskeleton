# RESEARCH: Agentic Reasoning — 컨텍스트 토큰 최적화 기법 조사

> **Date**: 2026-02-04
> **Sources**:
> - Survey: [Awesome-Agentic-Reasoning](https://github.com/weitianxin/Awesome-Agentic-Reasoning) (arXiv:2601.12538)
> - 개별 논문 분석: ReWOO, EASYTOOL, GEAR, System-1.x, RLM 등

---

## 1. 조사 배경

[Awesome-Agentic-Reasoning](https://github.com/weitianxin/Awesome-Agentic-Reasoning)은 "Agentic Reasoning for Large Language Models" 서베이 논문(arXiv:2601.12538)을 기반으로 200편 이상의 논문을 정리한 리포지토리다. 이 중에서 **컨텍스트 토큰 소모를 줄이는 데 직접적으로 기여하는 기법**을 식별하고 분석했다.

### 리포지토리 구조

```
Awesome-Agentic-Reasoning
├── Foundational Agentic Reasoning (단일 에이전트, 정적 환경)
│   ├── Planning Reasoning
│   │   ├── In-Context: Workflow Design, Tree Search, Process Formalization, Decomposition
│   │   └── Post-Training: RL/SFT 기반 계획 최적화
│   ├── Tool-Use Optimization
│   │   ├── In-Context: Reasoning+Tool Interleaving, Context Optimization
│   │   └── Post-Training: SFT/RL 기반 도구 숙달
│   └── Search & Verification
│
├── Self-Evolving Reasoning (피드백, 메모리, 학습)
│   ├── Feedback & Reflection
│   ├── Memory & Retrieval
│   └── Adaptation & Self-Improvement
│
└── Collective Reasoning (다중 에이전트)
    ├── Role Specialization
    ├── Debate & Verification
    └── Collaborative Intelligence
```

---

## 2. 토큰 최적화 관련 핵심 논문 분석

조사 결과, 크게 **5가지 패턴**으로 토큰 절감 기법을 분류할 수 있다.

---

### Pattern A: 추론-관찰 분리 (Decoupling)

#### ReWOO: Decoupling Reasoning from Observations
- **출처**: [arXiv:2305.18323](https://arxiv.org/abs/2305.18323) (NeurIPS 2023)
- **핵심 아이디어**: 기존 ReAct 패턴은 Reasoning → Tool Call → Observation → Reasoning을 반복하며, 매 단계마다 이전 관찰 결과를 컨텍스트에 누적한다. ReWOO는 **추론 계획을 한 번에 생성**한 뒤, 도구 실행을 별도로 수행하고, 최종적으로 결과만 취합한다.
- **토큰 절감**: HotpotQA에서 **5배 토큰 효율** + 4% 정확도 향상
- **추가 효과**: 175B GPT-3.5의 추론 능력을 7B LLaMA로 증류 가능

```
ReAct (기존):     Think → Act → Observe → Think → Act → Observe → ... (누적)
ReWOO (개선):     Plan(전체) → Execute(일괄) → Synthesize(최종)
```

**적용 가능성**: 우리 executor 스킬의 다단계 실행에서, 계획을 먼저 전체 생성하고 실행은 배치로 처리하는 패턴으로 전환 가능. 현재 GSD의 PLAN → EXECUTE 분리 구조가 이미 ReWOO와 유사.

---

### Pattern B: 도구 문서 압축 (Tool Documentation Compression)

#### EASYTOOL: Concise Tool Instruction
- **출처**: [arXiv:2401.06201](https://arxiv.org/abs/2401.06201) (NAACL 2025)
- **핵심 아이디어**: 다양하고 장황한 도구 문서를 **통일된 간결한 형식**으로 변환. 도구마다 다른 문서 포맷, 중복 정보, 불완전한 설명을 정제하여 핵심 정보만 추출.
- **토큰 절감**: 도구 설명에 소비되는 토큰을 대폭 감소시키면서 성능 유지 또는 향상

**적용 가능성**: 우리 스킬 시스템에서 SKILL.md 파일들의 크기를 최적화할 때 참고. 각 스킬의 핵심 인터페이스만 노출하고, 상세 절차는 필요 시에만 로드하는 패턴.

#### GEAR: Efficient Tool Resolution
- **출처**: [arXiv:2307.08775](https://arxiv.org/abs/2307.08775) (EACL 2024)
- **핵심 아이디어**: 도구 선택(grounding)을 **소형 모델(SLM)에 위임**하고, 실행만 대형 모델(LLM)이 담당. 태스크별 시연(demonstration) 의존도를 제거.
- **토큰 절감**: SLM이 도구 선택을 처리하므로 LLM 컨텍스트에 도구 목록/설명을 넣을 필요 없음
- **성능**: 14개 데이터셋, 6개 태스크에서 검증. GPT-J, GPT-3 기반에서 기존 도구 증강 대비 더 높은 정밀도

**적용 가능성**: 우리 Agent-Skill 구조에서, 스킬 라우팅을 경량 모델(Haiku)이 담당하고 실행은 Opus/Sonnet이 하는 2단계 구조로 확장 가능.

---

### Pattern C: 적응적 탐색 깊이 (Adaptive Search Depth)

#### System-1.x: Balancing Fast and Slow Planning
- **출처**: [arXiv:2407.14414](https://arxiv.org/abs/2407.14414) (2024)
- **핵심 아이디어**: System-1(직관적, 빠름)과 System-2(분석적, 느림) 계획을 **문제 난이도에 따라 동적으로 전환**. 쉬운 부분은 한 번에 생성하고, 어려운 부분에서만 탐색 수행.
- **토큰 절감**: 불필요한 탐색을 건너뛰어 계산 비용 절감
- **핵심 속성**:
  1. **Controllability** — hybridization factor로 탐색 비율 조절 (1.5 vs 1.75)
  2. **Flexibility** — 뉴로-심볼릭 하이브리드 지원
  3. **Generalizability** — 다양한 탐색 알고리즘에 적용 가능

**적용 가능성**: 우리 planner 스킬의 Discovery Level(0-3) 시스템과 직접 대응. 간단한 태스크는 Level 0(Skip)으로 즉시 실행, 복잡한 태스크만 Level 2-3으로 심층 탐색.

---

### Pattern D: 재귀적 분할 처리 (Recursive Decomposition)

#### RLM: Recursive Language Models
- **출처**: [arXiv:2512.24601](https://arxiv.org/abs/2512.24601) (2025)
- **핵심 아이디어**: 긴 프롬프트를 외부 변수로 저장하고, 모델이 재귀적으로 자기 자신을 호출하여 청크 단위로 처리.
- **토큰 절감**: 컨텍스트 윈도우의 100배 입력을 처리하면서, 중앙값 비용은 기본 모델과 유사
- **상세**: [RESEARCH-rlm-recursive-language-models.md](./RESEARCH-rlm-recursive-language-models.md) 참조

#### HyperTree Planning: Hierarchical Thinking
- **출처**: 2025
- **핵심 아이디어**: 계층적 트리 구조로 사고를 조직화. 상위 노드에서 전략을 결정하고, 하위 노드에서 세부 실행.
- **토큰 절감**: 전체 탐색 공간을 계층적으로 가지치기하여 불필요한 경로 탐색 방지

#### Divide and Conquer: Hierarchical RL
- **출처**: 2025
- **핵심 아이디어**: 오프라인 계층적 강화학습으로 LLM을 효율적 의사결정 에이전트로 활용
- **토큰 절감**: 고수준 계획과 저수준 실행을 분리하여 각 레벨에서 필요한 컨텍스트만 사용

**적용 가능성**: 현재 GSD의 Phase → Plan → Task 3단계 분할이 이 패턴과 정확히 일치. 각 단계에서 필요한 컨텍스트만 로드하는 "Need-to-Know" 원칙을 더 강화할 수 있음.

---

### Pattern E: 탐색 효율화 (Search Efficiency)

#### SWE-Search: MCTS + Iterative Refinement
- **출처**: ICLR 2025
- **핵심 아이디어**: 소프트웨어 에이전트에 Monte Carlo Tree Search를 적용하여 코드 수정 탐색을 효율화
- **토큰 절감**: 무작위 시행착오 대신 구조화된 탐색으로 불필요한 시도 감소

#### Thought of Search: Planning Through Efficiency Lens
- **출처**: NeurIPS 2024
- **핵심 아이디어**: LLM 기반 계획을 효율성 관점에서 재정의. 탐색의 계산 복잡도를 명시적으로 고려.

#### Tree of Thoughts (ToT)
- **출처**: NeurIPS 2023
- **핵심 아이디어**: 사고를 트리 구조로 조직화하고 BFS/DFS로 탐색. 유망하지 않은 경로를 조기 중단.
- **토큰 절감**: 선형 Chain-of-Thought 대비, 실패 경로를 조기에 가지치기하여 전체 토큰 사용량 감소

**적용 가능성**: 우리 debugger 스킬의 가설 기반 조사 방식이 ToT와 유사. 가설을 조기에 제거(debug-eliminated)하여 불필요한 탐색 방지.

---

## 3. 종합 비교

| 패턴 | 대표 논문 | 토큰 절감 방식 | 절감 규모 | 구현 난이도 |
|------|----------|---------------|----------|------------|
| **A. 추론-관찰 분리** | ReWOO | 계획/실행 분리, 관찰 누적 제거 | **5x** | 낮음 |
| **B. 도구 문서 압축** | EASYTOOL, GEAR | 도구 설명 간소화, SLM 위임 | 2-3x (추정) | 중간 |
| **C. 적응적 탐색** | System-1.x | 난이도별 탐색 깊이 조절 | 가변적 | 높음 (학습 필요) |
| **D. 재귀적 분할** | RLM, HyperTree | 청킹 + 재귀 호출 | **100x 입력** | 중간 |
| **E. 탐색 효율화** | SWE-Search, ToT | 구조화된 탐색, 가지치기 | 2-5x (추정) | 중간 |

---

## 4. 우리 프로젝트에 즉시 적용 가능한 기법

### 4.1 이미 적용 중인 패턴

| 기법 | 우리 구현 | 대응 논문 |
|------|----------|----------|
| 계획-실행 분리 | GSD: PLAN.md → EXECUTE | ReWOO |
| 난이도별 탐색 | Discovery Level 0-3 | System-1.x |
| 가설 가지치기 | debug-eliminated 메모리 | ToT |
| Need-to-Know 컨텍스트 | executor 스킬의 최소 컨텍스트 로딩 | HyperTree |
| 계층적 분할 | Phase → Plan → Task | Divide and Conquer |

### 4.2 추가 적용 가능한 최적화

#### (1) 스킬 문서 2단계 로딩 (EASYTOOL 패턴)
```
현재: SKILL.md 전체 로드 (수백~수천 토큰)
개선: 1단계 — 요약(50토큰) → 2단계 — 상세(필요 시만 로드)
```
- 각 SKILL.md에 `## Quick Reference` 섹션(5줄 이내)을 최상단에 배치
- 에이전트가 초기에는 Quick Reference만 읽고, 실행 시에만 전체 로드

#### (2) 메모리 검색 결과 압축 (ReWOO 패턴)
```
현재: Grep 결과를 그대로 컨텍스트에 포함
개선: md-recall-memory.sh 출력을 title + 1줄 요약으로 제한
      상세 내용은 필요 시에만 Read로 로드
```

#### (3) 서브에이전트 활용 (GEAR/RLM 패턴)
```
현재: 모든 분석을 메인 에이전트(Opus)가 수행
개선: 탐색/검색은 Haiku 서브에이전트가 수행
      결과 요약만 메인 에이전트에 전달
```
- impact-analysis, arch-review 등 탐색 위주 태스크를 Haiku에 위임
- 메인 대화의 컨텍스트 소모 없이 분석 수행

#### (4) 컨텍스트 Health Monitor 개선 (System-1.x 패턴)
```
현재: 60% 임계값에서 /compact 실행
개선: 태스크 난이도에 따라 임계값 동적 조정
      - 간단한 태스크: 70%까지 허용
      - 복잡한 태스크: 50%에서 선제적 compact
```

---

## 5. 결론

Awesome-Agentic-Reasoning 리포지토리의 200편 이상 논문 중, **토큰 최적화에 직접 기여하는 기법은 5가지 패턴**으로 분류된다. 우리 보일러플레이트는 이미 ReWOO(계획-실행 분리), System-1.x(적응적 탐색), ToT(가설 가지치기) 패턴을 부분적으로 구현하고 있다.

**가장 높은 ROI의 추가 최적화**:
1. **스킬 문서 2단계 로딩** — 구현 쉬움, 즉시 토큰 절감
2. **서브에이전트 위임** — GEAR/RLM 패턴, 메인 컨텍스트 보호
3. **메모리 검색 압축** — 검색 결과의 점진적 상세화

이 세 가지를 적용하면 현재 대비 **세션당 컨텍스트 소모를 30-50% 감소**시킬 수 있을 것으로 추정된다.
