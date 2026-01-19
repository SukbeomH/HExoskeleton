# OmniGraph Framework - Unified Specification

> **Status**: FINALIZED
> **Version**: 1.0.0
> **Last Updated**: 2026-01-19
> **Stack**: LangChain v1.2+ / LangGraph / MCP Protocol
> **Methodology**: Get Shit Done (GSD)

---

## 📋 Executive Summary

OmniGraph는 **로컬(CodeGraph)** 과 **글로벌(Neo4j)** 지식 그래프를 연결하는 **계층형 하이브리드 RAG 프레임워크**입니다.
개발자에게 명확한 워크플로우를 제공하며, AI 에이전트가 **프로젝트 맥락을 완벽히 이해**하고 작동하도록 설계되었습니다.

### 핵심 가치
- 🎯 **Fast/Slow Thinking**: 로컬(즉시) + 글로벌(심층) 하이브리드 추론
- 🔗 **URN 기반 식별**: 로컬/글로벌 엔티티의 체계적 관리
- 📝 **GSD 문서 주도**: SPEC → PLAN → Execution의 명확한 흐름
- 🛡️ **Human-in-the-Loop**: 민감한 작업 전 승인 게이트

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       OmniGraph Platform                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐       ┌────────────────────────────┐  │
│  │   Local Spoke       │◀─────▶│       Global Hub           │  │
│  │   (Developer IDE)   │  MCP  │   (Central Platform)       │  │
│  ├─────────────────────┤       ├────────────────────────────┤  │
│  │ • CodeGraph (AST)   │       │ • Neo4j (Knowledge Graph)  │  │
│  │ • .agent/ Context   │       │ • Vector Index (Semantic)  │  │
│  │ • .specs/ GSD Docs  │       │ • LangGraph Orchestration  │  │
│  │ • Local MCP Server  │       │ • NeoDash Visualization    │  │
│  └─────────────────────┘       └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Directory Structure

### A. Local Spoke (project-template/)
개발자가 사용할 보일러플레이트 템플릿입니다.

```
project-template/
├── .codegraph/                # CodeGraph 인덱스 데이터 [git ignored]
│
├── .agent/                    # [Context Layer] LLM 행동 지침
│   ├── agent.md               # 에이전트 페르소나, Boundaries 정의
│   ├── memory.jsonl           # 로컬 단기 기억 (MCP-Knowledge-Graph)
│   ├── workflows/             # 표준 작업 절차 (SOP)
│   │   ├── feature-dev.md     # 기능 개발: Spec → Plan → Code
│   │   └── bug-fix.md         # 버그 수정: Reproduce → Fix → Test
│   └── skills/                # 도구 활용 전략
│       ├── architecture.md    # 아키텍처 위반 검사 (Global DB)
│       └── impact-check.md    # 변경 영향도 분석 (Local CodeGraph)
│
├── .specs/                    # [GSD] 문서 주도 개발
│   ├── SPEC.md                # 현재 작업의 요구사항 정의서
│   ├── PLAN.md                # 실행 계획 및 상태 (TODO/DONE)
│   └── DECISIONS.md           # 아키텍처 의사결정 기록 (ADR)
│
├── mcp/                       # 로컬 MCP 서버 구성
│   ├── server.py              # FastMCP 기반 도구 노출
│   └── config.json            # CodeGraph 및 로컬 툴 설정
│
├── scripts/
│   ├── sync_to_hub.sh         # CI/CD: 메타데이터 추출 및 Hub 업로드
│   └── validate_spec.py       # SPEC.md 검증 스크립트
│
└── codegraph.toml             # CodeGraph 인덱싱 설정 (Tier: balanced)
```

### B. Global Hub (platform-core/)
중앙 통합 및 추론 엔진입니다.

```
platform-core/
├── graph-db/                  # Neo4j 관리
│   ├── schema.cypher          # 전역 스키마 (Nodes, Edges, Vector Index)
│   └── constraints.cypher     # URN 유일성 제약 조건
│
├── orchestration/             # LangGraph 에이전트 서버
│   ├── graph.py               # StateGraph 정의 (워크플로우 진입점)
│   ├── state.py               # AgentState 정의 (TypedDict)
│   ├── nodes/                 # 그래프 노드
│   │   ├── intent_classifier.py   # Local/Global 의도 판단
│   │   ├── local_retriever.py     # CodeGraph MCP 호출
│   │   ├── global_retriever.py    # Neo4j MCP 호출
│   │   └── synthesizer.py         # 답변 합성
│   └── tools/                 # Global MCP 클라이언트 래퍼
│
├── ingestion/                 # 데이터 수집 파이프라인
│   └── urn_normalizer.py      # 로컬 경로 → 전역 URN 변환
│
├── dashboard/                 # 시각화 계층
│   ├── neodash/
│   │   └── config.json        # 전사 프로젝트 현황 대시보드
│   └── web-admin/             # 커스텀 통합 관리자 페이지
│       ├── App.tsx
│       └── mcp-client.ts
│
└── docker-compose.yml         # Neo4j + NeoDash 실행 정의
```

### C. Shared Libraries (shared-libs/)
공통 유틸리티입니다.

```
shared-libs/
└── urn_manager.py             # URN 생성 및 파싱 (urn:local / urn:global)
```

---

## 🔧 Implementation Phases

### Phase 1: 로컬 컨텍스트 엔지니어링 (The Spoke)

#### 1.1 agent.md 구성 (에이전트 헌법)

**목적**: AI(Claude, Cursor 등)에게 역할, 도구, 금지 사항을 즉시 인지시킵니다.

**필수 섹션**:

| Section | 내용 |
|---------|------|
| **Role** | "당신은 OmniGraph 기반의 수석 엔지니어입니다." |
| **Context** | 프로젝트 스택 및 사용 도구 명시 |
| **Commands** | 실행 가능한 명령어 (`npm test`, `poetry run lint` 등) |
| **Boundaries** | 3티어 행동 제약 |

**Boundaries 3-Tier**:
- ✅ **Always**: 코드 수정 전 `agentic_impact` 도구 실행, `SPEC.md` 확인
- ⚠️ **Ask First**: 전역 라이브러리 의존성 추가, DB 스키마 변경
- 🚫 **Never**: `.env` 파일 읽기/출력, 하드코딩된 비밀번호 커밋

#### 1.2 GSD 문서 시스템

| 문서 | 역할 |
|------|------|
| **SPEC.md** | 모호한 요청을 방지하고 요구사항을 강제 정의 |
| **PLAN.md** | XML 태그로 작업 세분화, 한 번에 하나씩 수행/검증 |
| **DECISIONS.md** | 아키텍처 의사결정 기록 (ADR) |

---

### Phase 2: 로컬 분석 엔진 (CodeGraph Integration)

#### 2.1 CodeGraph 설정

**codegraph.toml**:
```toml
[index]
tier = "balanced"  # 속도와 정확도 균형

[mcp]
transport = "stdio"
```

**MCP 연결**: `mcp/server.py`에서 `codegraph` 바이너리를 서브프로세스로 실행

#### 2.2 로컬 스킬 정의 (Updated standard)
Claude Agent Skills 표준 디렉토리 구조를 준수합니다.
*   **경로**: `.agent/skills/{skill_name}/SKILL.md`
*   **구성**: YAML Frontmatter(메타데이터) + Markdown(실행 지침)
*   **필수 스킬**:
    *   `impact-analysis`: 코드 변경 전 `agentic_impact` 호출 강제.
    *   `arch-review`: `agentic_architecture`를 호출하여 설계 위반 점검.

---

### Phase 3: 글로벌 지식 허브 (Neo4j Integration)

#### 3.1 URN 전략

| 범위 | 형식 | 예시 |
|------|------|------|
| **Local** | `urn:local:{project_id}:{file_path}:{symbol}` | `urn:local:proj1:src/utils.py:calculate` |
| **Global** | `urn:global:lib:{package_name}@{version}` | `urn:global:lib:lodash@4.17.21` |

#### 3.2 Hybrid RAG 스키마

**노드 타입**:
- `Project`, `Function`, `Library`, `Issue`

**관계 타입**:
- `(:Function)-[:CALLS]->(:Function)`
- `(:Project)-[:DEPENDS_ON]->(:Library)`

**Neo4j 구성**:
- 벡터 인덱스 (시맨틱 검색용)
- 지식 그래프 (구조적 추론용)

#### 3.3 Ingestion 파이프라인

```bash
# CI/CD (GitHub Actions)에서 실행
./scripts/sync_to_hub.sh
```

#### 3.4 MCP 서버 구성 (Updated)
공식 Neo4j MCP 제품군을 활용하여 구현 복잡도를 낮춥니다.
*   **Tool 1**: `mcp-neo4j-cypher` (스키마 기반 질의)
*   **Tool 2**: `mcp-neo4j-memory` (에이전트 장기 기억 저장소)
    *   *활용*: "이전에 A 프로젝트에서 발생한 `OutOfMemory` 해결책을 기억해줘"와 같은 요청 처리.

---

### Phase 4: LangGraph 에이전트 오케스트레이션

#### 4.1 AgentState 정의

```python
from typing import Annotated, TypedDict, List
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    # 대화 기록 (자동으로 기존 메시지에 추가)
    messages: Annotated[List, add_messages]
    # 현재 분석 중인 파일 경로 (Local Context)
    current_file: str
    # 검색된 관련 문서들 (RAG Context)
    retrieved_docs: List[str]
    # 사용자의 의도 (Local 수정 vs Global 질문)
    intent: str
    # 컨텍스트 필요 종류
    context_needs: list[str]  # ["local_impact", "global_pattern"]
```

#### 4.2 그래프 노드 (Hybrid Thinking)

```
┌──────────────────┐
│  IntentClassifier │ ─── "이 함수 고쳐줘" → Local
│                  │ ─── "이런 기능 구현한 적 있어?" → Global
└────────┬─────────┘
         │
    ┌────▼────┐          ┌─────────────┐
    │  LOCAL  │          │   GLOBAL    │
    │ Retriever│         │  Retriever  │
    │ (Fast)  │          │   (Slow)    │
    └────┬────┘          └──────┬──────┘
         │                      │
         │              ┌───────▼───────┐
         │              │    Pruner     │ (Context Pruning)
         │              └───────┬───────┘
         │                      │
         └──────────┬───────────┘
                    │
            ┌───────▼───────┐
            │  Synthesizer  │
            └───────────────┘
```

#### 4.3 그래프 조립 및 컴파일

(코드 생략 - graph.py 참조)

#### 4.4 컨텍스트 안전장치 (Context Safeguards)
*   **Overflow Protection**: CodeGraph 조회 시 `CODEGRAPH_CONTEXT_WINDOW` 제한을 적용하여 토큰 과다 사용 방지.
*   **Pruning**: `Synthesizer` 전달 전, 관련성 낮은 검색 결과(Documents)를 필터링하는 중간 단계 추가.

### Phase 5: MCP 인터페이스 표준화

#### 5.1 MCP 도구 통합

```python
from langchain_mcp_adapters.client import MultiServerMCPClient

async def load_tools():
    client = MultiServerMCPClient({
        "local-codegraph": {
            "transport": "stdio",
            "command": "codegraph",
            "args": ["start", "stdio"]
        },
        "global-neo4j": {
            "transport": "sse",
            "url": "http://localhost:8000/mcp"
        }
    })
    return await client.get_tools()
```

#### 5.2 서버 구성

| 계층 | 서버 | 역할 |
|------|------|------|
| **Local** | `codegraph` | AST 분석, 심볼 검색 |
| **Global** | `mcp-neo4j-cypher` | Cypher 쿼리, 패턴 검색 |

---

## 📊 Visualization Layer

### 도구 선택 가이드

| 계층 | DB | 추천 도구 | 용도 |
|------|-----|----------|------|
| **Global** | Neo4j | **NeoDash** | 전사 프로젝트 현황 대시보드 |
| **Local** | SurrealDB | **Surrealist** | CodeGraph 데이터 조회 |
| **Unified** | - | **Streamlit** | MCP 기반 통합 관리자 |

### 사용 시나리오

#### 개발자 (Local)
```bash
# 의존성 확인이 필요할 때
npm run gui  # 또는 ./scripts/start_gui.sh

# http://localhost:8080 (Surrealist)
# → Function 테이블 조회
# → 내 함수의 CALLS 관계 그래프 확인
```

#### 아키텍트 (Global)
```
# http://hub.omnigraph.internal:5005 (NeoDash)
# → 순환 참조 경고 확인
# → 프로젝트별 아키텍처 위반 현황 모니터링
```

---

## 🚀 Quick Start

### 1. 로컬 환경 설정

```bash
# 프로젝트 클론
git clone <omnigraph-template>
cd project-template

# 의존성 설치
uv sync  # 또는 npm install

# CodeGraph 인덱싱
codegraph index --tier balanced
```

### 2. MCP 서버 실행

```bash
# Docker Compose로 실행
cd mcp && docker-compose -f docker-compose.mcp.yml up -d
```

### 3. GSD 문서 작성

```bash
# SPEC.md 작성 후 검증
python scripts/validate_spec.py
```

---

## 🧠 LLM Implementation Prompt

다음 프롬프트를 사용하여 LLM에게 구현을 지시하세요:

> "당신은 OmniGraph 프레임워크의 수석 아키텍트입니다. **LangChain v1.0**과 **LangGraph**를 사용하여 '계층형 하이브리드 RAG 에이전트'를 구현해야 합니다.
>
> 1. **데이터 구조**: 로컬 데이터는 `CodeGraph`, 글로벌 데이터는 `Neo4j`를 사용하며, 모든 엔티티는 `urn:{scope}:...` 형식의 URN으로 식별됩니다.
> 2. **워크플로우**: 사용자의 질문이 들어오면 `IntentClassifier` 노드에서 로컬/글로벌 필요 여부를 판단하고, `StateGraph`를 통해 적절한 MCP 도구를 호출한 뒤 답변을 합성하십시오.
> 3. **컨텍스트**: `project-template/.agent/agent.md`에 정의된 **Boundaries(Always/Ask/Never)**를 엄격히 준수하는 로직을 `nodes/safeguards.py`에 구현하십시오.
>
> 우선 `platform-core/orchestration/graph.py`의 `StateGraph` 정의 코드와 `project-template/.agent/agent.md`의 템플릿 내용을 작성해 주세요."

---

## 📋 Verification Checklist

### Phase 1 완료 조건
- [ ] `.agent/agent.md` 작성 완료
- [ ] `.specs/SPEC.md` 템플릿 준비
- [ ] Boundaries 3-Tier 정의

### Phase 2 완료 조건
- [ ] `codegraph.toml` 설정
- [ ] `mcp/server.py` CodeGraph 연결
- [ ] `impact-analysis.md` 스킬 정의

### Phase 3 완료 조건
- [ ] Neo4j Docker 실행
- [ ] `schema.cypher` 적용
- [ ] `urn_normalizer.py` 구현

### Phase 4 완료 조건
- [ ] `AgentState` 정의
- [ ] 4개 노드 구현 (Intent/Local/Global/Synth)
- [ ] Human-in-the-Loop 설정

### Phase 5 완료 조건
- [ ] MCP 클라이언트 통합
- [ ] NeoDash 대시보드 구성
- [ ] E2E 테스트 통과

---

## 📚 References

- [LangChain MCP Adapters](https://github.com/langchain-ai/langchain-mcp-adapters)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Neo4j Graph Database](https://neo4j.com/)
- [CodeGraph](https://github.com/codegraph/codegraph)
- [GSD Methodology](https://gsd.dev/)

---

> **Note**: 이 문서는 OmniGraph 프레임워크의 완전한 명세서입니다.
> 실제 구현 시 각 Phase를 순차적으로 완료하고, Verification Checklist를 통해 진행 상황을 추적하세요.
