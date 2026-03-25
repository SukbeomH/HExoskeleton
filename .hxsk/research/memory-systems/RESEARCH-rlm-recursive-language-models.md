# RESEARCH: Recursive Language Models (RLM)

> **Date**: 2026-02-04
> **Sources**:
> - 논문: [arXiv 2512.24601v2](https://arxiv.org/html/2512.24601v2) — Alex L. Zhang, Tim Kraska, Omar Khattab (MIT CSAIL)
> - 구현체: [brainqub3/claude_code_RLM](https://github.com/brainqub3/claude_code_RLM) — Claude Code 기반 RLM 구현
> - 커뮤니티 분석: [PyTorch KR 토론](https://discuss.pytorch.kr/t/recursive-language-models-rlm-llm/8617)

---

## 1. 문제 정의

### 기존 접근법의 한계

| 접근법 | 한계 |
|--------|------|
| **Long-Context 모델** | "Context Rot" — 정보 밀도 증가 시 핵심 정보의 어텐션 스코어가 희석됨 |
| **RAG 시스템** | 사전 정의된 청크 단위로만 검색 가능, 전체 맥락 파악이나 복잡한 다단계 추론에 약함 |
| **요약 기반** | 정보 손실 불가피, 세부 사항 누락 |

**핵심 질문**: 모델의 아키텍처를 변경하지 않고, 컨텍스트 윈도우를 100배 이상 초과하는 입력을 처리할 수 있는가?

---

## 2. RLM 핵심 개념

긴 텍스트를 모델의 "입력"이 아닌 **"외부 환경 변수"**로 취급한다. 모델이 코드를 작성하여 내용을 엿보고(peek), 분해(decompose)하고, **자기 자신을 재귀적으로 호출**하는 방식.

### 3가지 설계 원칙

```
┌─────────────────────────────────────────────────────┐
│                    RLM Architecture                  │
│                                                      │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │   LLM (Root) │───▶│  REPL Environment        │   │
│  │              │    │  ┌────────────────────┐   │   │
│  │  "코드 작성"  │    │  │ prompt = <10M tok> │   │   │
│  │  "재귀 호출"  │    │  │ chunk = prompt[:N] │   │   │
│  │              │◀───│  │ result = llm(chunk) │   │   │
│  └──────────────┘    │  └────────────────────┘   │   │
│                      └──────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

| 원칙 | 설명 | 기존 방식과의 차이 |
|------|------|--------------------|
| **Symbolic Handle** | 프롬프트 전체를 컨텍스트에 넣지 않고, 메타데이터(길이, 접두사, 접근 방법)만 제공. 전문은 변수로 저장 | 기존: 전체 텍스트를 컨텍스트 윈도우에 직접 삽입 |
| **Unbounded Output** | 코드 실행 + 변수 할당으로 응답 생성 → 단일 컨텍스트 윈도우를 초과하는 출력 가능 | 기존: 출력도 컨텍스트 윈도우 크기에 제한 |
| **Symbolic Recursion** | 모델이 자기 자신을 루프 내에서 재귀 호출하는 코드를 작성 → Ω(\|P\|) 또는 Ω(\|P\|²) 시맨틱 연산 | 기존: 단일 패스 처리 |

---

## 3. 실험 결과

### 평가 태스크

| 태스크 | 복잡도 | 설명 |
|--------|--------|------|
| S-NIAH | O(1) | Needle-in-a-haystack 검색 |
| BrowseComp-Plus | O(n) | 1,000개 문서 다중 홉 추론 |
| OOLONG | O(n) | 시맨틱 집계 |
| OOLONG-Pairs | O(n²) | 쌍별(pair-wise) 분석 |

### 성능 비교

| 태스크 | Base Model | RLM 적용 | 향상 |
|--------|-----------|----------|------|
| LongBench-v2 CodeQA | 24점 | 62점 | **2.5x** |
| BrowseComp-Plus | — | 91.33% | — |
| OOLONG-Pairs (F1) | 0.1% | 58% | **580x** |

- **확장성**: 1,000만+ 토큰 입력 처리 가능 (기본 모델은 실패)
- **비용**: 중앙값 기준 기본 모델 호출과 비슷한 수준 유지 (tail cost는 높은 분산)
- **학습 효율**: 8B 모델을 단 1,000개 샘플로 파인튜닝하여 평균 28.3% 성능 향상

### 창발적 행동 패턴

별도 학습 없이 모델이 자연스럽게 채택한 전략들:

1. **정규표현식 필터링** — 핵심 정보를 regex로 추출
2. **재귀적 분할** — 문제를 하위 문제로 분해 후 각각 처리
3. **자기 검증** — 답변을 확인하기 위한 하위 모델 재호출
4. **변수 기반 출력** — 초장문 출력을 변수 할당으로 관리

---

## 4. Claude Code 구현체 분석 (claude_code_RLM)

### 아키텍처 매핑

| RLM 논문 컴포넌트 | Claude Code 구현 | 사용 모델 |
|-------------------|-----------------|-----------|
| Root LLM | Main Claude Code 대화 | Claude Opus 4.5 |
| Sub-LLM (`llm_query`) | `rlm-subcall` subagent | Claude Haiku |
| External Environment | Persistent Python REPL (`rlm_repl.py`) | Python 3 |

Opus 4.5가 전체 태스크를 오케스트레이션하고, 청크 분석은 Haiku에 위임하여 비용 효율성을 확보.

### 디렉토리 구조

```
claude_code_RLM/
├── CLAUDE.md                     # 프로젝트 지시사항
├── .claude/
│   ├── agents/
│   │   └── rlm-subcall.md        # Sub-LLM 에이전트 (Haiku)
│   └── skills/
│       └── rlm/
│           ├── SKILL.md          # RLM 스킬 정의
│           └── scripts/
│               └── rlm_repl.py   # Persistent REPL
├── context/                      # 대용량 파일 저장 디렉토리
└── README.md
```

### 사용법

```bash
git clone https://github.com/Brainqub3/claude_code_RLM.git
cd claude_code_RLM
claude
/rlm
```

`/rlm` 커맨드 실행 시:
1. 대용량 컨텍스트 파일 경로 입력
2. 질문/쿼리 입력
3. REPL 초기화 → 청킹 → Sub-LLM 위임 → 결과 합성

### 핵심 구현 흐름

```
사용자 → /rlm → Opus 4.5 (Root LLM)
                    │
                    ├─ rlm_repl.py 초기화 (컨텍스트 로드)
                    │
                    ├─ 청킹 전략 결정
                    │
                    ├─ for chunk in chunks:
                    │     └─ rlm-subcall (Haiku) → 청크 분석 결과
                    │
                    └─ 결과 합성 → 최종 응답
```

---

## 5. 한계 및 고려사항

| 한계 | 설명 | 잠재적 해결 |
|------|------|------------|
| **순차 실행** | Sub-LLM 호출이 순차적 → 지연 누적 | 비동기/병렬 호출 |
| **재귀 깊이 제한** | 현재 1단계 재귀만 지원 | 다단계 재귀 탐색 |
| **짧은 입력 성능** | 일반 모델 대비 약간 하락 | 입력 길이 기반 자동 모드 전환 |
| **모델별 편차** | 과도한 분할 호출 발생 가능 | RLM 특화 파인튜닝 |
| **보안** | `--dangerously-skip-permissions` 사용 시 위험 | 격리된 워크스페이스에서만 실행 |

---

## 6. 우리 프로젝트 적용 가능성

### 현재 보일러플레이트와의 유사성

| RLM 구현체 | 우리 보일러플레이트 |
|-----------|-------------------|
| `.claude/agents/rlm-subcall.md` | `.claude/agents/*.md` (14개 에이전트) |
| `.claude/skills/rlm/SKILL.md` | `.claude/skills/*/SKILL.md` (16개 스킬) |
| `rlm_repl.py` (Persistent REPL) | `.claude/hooks/*.sh` (이벤트 훅) |
| `context/` (대용량 파일) | `.gsd/memories/` (파일 기반 메모리) |

### 적용 시나리오

1. **대규모 코드베이스 분석**: 수만 줄의 코드를 청킹하여 분석 → impact-analysis 스킬 강화
2. **대용량 문서 처리**: 긴 SPEC이나 리서치 문서를 RLM 방식으로 처리
3. **Multi-file 리뷰**: PR 리뷰 시 다수 파일을 Sub-LLM으로 병렬 분석

### 통합 방안 (제안)

```
.claude/
├── agents/
│   └── rlm-subcall.md          # 새 에이전트: 청크 분석용 Haiku
├── skills/
│   └── rlm/
│       ├── SKILL.md            # RLM 스킬 정의
│       └── scripts/
│           └── rlm_repl.py     # Persistent REPL
```

기존 Agent-Skill 래핑 구조에 자연스럽게 통합 가능. Root LLM(Opus)이 기존 GSD 워크플로우를 오케스트레이션하면서, 대용량 입력이 필요한 태스크에서만 RLM 패턴 활성화.

---

## 7. 결론

RLM은 **모델 아키텍처 변경 없이** 컨텍스트 용량을 극적으로 확장하는 실용적 프레임워크. Claude Code의 기존 Agent/Skill/Hook 구조와 높은 호환성을 가지며, 특히 대규모 코드베이스 분석이나 장문 문서 처리에 유의미한 개선을 제공할 수 있음.

**핵심 인사이트**: "컨텍스트 윈도우 크기" 문제를 아키텍처가 아닌 **추론 패러다임**으로 해결한 점이 가장 큰 기여. 이는 현재 Claude Code 에이전트 시스템에서도 subagent + REPL 조합으로 즉시 활용 가능한 패턴.
