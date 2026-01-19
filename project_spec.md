제공해주신 새로운 자료(Addy Osmani의 스펙 작성법, Agent README 논문, GSD 방법론 등)와 기존의 논의 사항을 종합하여, **CodeGraph(로컬)**와 **Neo4j(글로벌)**를 연결하는 **'OmniGraph' 프레임워크**의 최종 디렉토리 구조와 상세 구현 명세서를 작성했습니다.

이 명세서는 **LangChain v1.0+** 및 **LangGraph**를 기반으로 하며, 개발자에게는 **"Get Shit Done (GSD)"** 스타일의 명확한 워크플로우를 제공하는 것을 목표로 합니다.

---

### 1. 통합 프로젝트 디렉토리 트리 (OmniGraph Framework)

이 구조는 **(A) 로컬 개발 환경(Spoke)**과 **(B) 중앙 플랫폼(Hub)**, 그리고 **(C) 에이전트 행동 지침(Context Layer)**으로 구성됩니다.

```text
OmniGraph/
├── 📂 project-template/           # [Local Spoke] 개발자가 사용할 보일러플레이트
│   ├── .codegraph/                # CodeGraph 로컬 인덱스 데이터 (git ignore)
│   ├── .agent/                    # [Context Layer] LLM 행동 제어 및 기억 저장소
│   │   ├── agent.md               # [핵심] 에이전트 페르소나, 경계(Boundaries), 명령어 정의
│   │   ├── memory.jsonl           # 로컬 단기 기억 (MCP-Knowledge-Graph 활용)
│   │   ├── workflows/             # 표준 작업 절차 (SOP)
│   │   │   ├── feature-dev.md     # 기능 개발 프로세스 (Spec -> Plan -> Code)
│   │   │   └── bug-fix.md         # 버그 수정 프로세스 (Reproduce -> Fix -> Test)
│   │   └── skills/                # 도구 활용 전략 (MCP 도구 조합법)
│   │       ├── architecture.md    # 아키텍처 위반 검사 스킬 (Global DB 조회)
│   │       └── impact-check.md    # 변경 영향도 분석 스킬 (Local CodeGraph 조회)
│   ├── .specs/                    # [GSD] 문서 주도 개발 상태 관리
│   │   ├── SPEC.md                # 현재 작업의 요구사항 정의서 (Living Document)
│   │   ├── PLAN.md                # 실행 계획 및 상태 (TODO/DONE)
│   │   └── DECISIONS.md           # 아키텍처 의사결정 기록 (ADR)
│   ├── mcp/                       # 로컬 MCP 서버 구성
│   │   ├── server.py              # 로컬 도구 노출 (FastMCP 기반)
│   │   └── config.json            # CodeGraph 및 로컬 툴 설정
│   ├── scripts/
│   │   ├── sync_to_hub.sh         # CI/CD용: 로컬 그래프 메타데이터 추출 및 업로드
│   │   └── validate_spec.py       # SPEC.md 문법 및 필수 항목 검증 스크립트
│   └── codegraph.toml             # CodeGraph 인덱싱 설정 (Tier: balanced)
│
├── 📂 platform-core/              # [Global Hub] 중앙 통합 및 추론 엔진
│   ├── 📂 graph-db/               # Neo4j 관리 (Docker/K8s)
│   │   ├── schema.cypher          # 전역 스키마 (Nodes, Edges, Vector Index)
│   │   └── constraints.cypher     # URN 유일성 제약 조건 설정
│   ├── 📂 orchestration/          # LangGraph 에이전트 서버
│   │   ├── graph.py               # StateGraph 정의 (Workflow 진입점)
│   │   ├── state.py               # AgentState 정의 (TypedDict)
│   │   ├── nodes/                 # 그래프 노드 (Retrieve, Reason, Synthesize)
│   │   └── tools/                 # Global MCP 클라이언트 래퍼 (Neo4j, Search)
│   └── 📂 ingestion/              # 데이터 수집 파이프라인
│       └── urn_normalizer.py      # 로컬 경로 -> 전역 URN 변환 로직
│
└── 📂 shared-libs/                # 공통 유틸리티
    └── urn_manager.py             # URN 생성 및 파싱 (urn:local vs urn:global)
```

---

### 2. 상세 단계별 구현 명세서 (Step-by-Step Spec)

이 명세서는 **Addy Osmani의 가이드**와 **GSD 방법론**을 반영하여 LLM이 명확한 경계와 절차 내에서 작동하도록 설계되었습니다.

#### Phase 1: 로컬 컨텍스트 엔지니어링 (The Spoke)
개발자의 로컬 환경을 "AI가 이해하기 쉬운 상태"로 만드는 단계입니다.

**1.1 `agent.md` 구성 (에이전트 헌법)**
*   **목적:** 프로젝트에 접속하는 AI(Claude, Cursor 등)에게 역할, 도구, 금지 사항을 즉시 인지시킵니다.
*   **필수 섹션:**
    *   **Role:** "당신은 OmniGraph 기반의 수석 엔지니어입니다."
    *   **Context:** "이 프로젝트는 React/Python 스택이며, 로컬 분석은 CodeGraph를 사용합니다."
    *   **Commands:** `npm test`, `poetry run lint` 등 실행 가능한 명령어 명시.
    *   **Boundaries (3-Tier):**
        *   ✅ **Always:** 코드 수정 전 `agentic_impact` 도구 실행, `SPEC.md` 확인.
        *   ⚠️ **Ask First:** 전역 라이브러리(`urn:global`) 의존성 추가, DB 스키마 변경.
        *   🚫 **Never:** `.env` 파일 읽기/출력, 하드코딩된 비밀번호 커밋.

**1.2 GSD(Get Shit Done) 문서 시스템 구축**
*   **`SPEC.md`**: "기능을 구현해줘"라는 모호한 요청을 막고, 반드시 이 파일을 먼저 작성하게 강제합니다.
*   **`PLAN.md`**: 작업을 XML 태그(`<task>`)로 세분화하여, AI가 한 번에 하나씩 수행하고 검증(`verify`)하도록 합니다.

#### Phase 2: 로컬 분석 엔진 (CodeGraph Integration)
로컬 코드의 구조적 이해를 담당합니다.

**2.1 CodeGraph 설정 (`codegraph.toml`)**
*   인덱싱 티어를 `balanced`로 설정하여 속도와 정확도의 균형을 맞춥니다.
*   **MCP 연결:** `project-template/mcp/server.py`에서 `codegraph` 바이너리를 서브프로세스로 실행하고, 표준 입출력(stdio)을 통해 통신하도록 설정합니다.

**2.2 로컬 스킬 정의 (`.agent/skills/`)**
*   **`impact-analysis.md`**: 코드를 수정하기 전에 CodeGraph의 `agentic_impact` 툴을 호출하여 의존성 트리를 확인하는 절차를 자연어로 정의합니다. 이는 LLM이 도구를 언제 써야 할지 모르는 문제를 해결합니다.

#### Phase 3: 글로벌 지식 허브 (Neo4j Integration)
전사적 패턴과 기억을 저장합니다.

**3.1 데이터 스키마 및 URN 전략**
*   **식별자(URN):**
    *   로컬: `urn:local:{project_id}:{file_path}:{symbol}`
    *   글로벌: `urn:global:lib:{package_name}@{version}`
*   **Hybrid RAG 스키마:** Neo4j에 **벡터 인덱스**(시맨틱 검색용)와 **지식 그래프**(구조적 추론용)를 동시에 구축합니다.
    *   노드: `Project`, `Function`, `Library`, `Issue`
    *   관계: `(:Function)-[:CALLS]->(:Function)`, `(:Project)-[:DEPENDS_ON]->(:Library)`

**3.2 Ingestion 파이프라인**
*   CI/CD(GitHub Actions)에서 `sync_to_hub.sh`가 실행될 때, 변경된 코드의 AST 요약본(CodeGraph 추출)을 중앙 서버로 전송합니다. 중앙 서버는 이를 받아 `urn:global` 노드와 연결(Merge)합니다.

#### Phase 4: LangGraph 에이전트 오케스트레이션
로컬과 글로벌을 오가는 추론 루프를 구현합니다.

**4.1 상태 정의 (`AgentState`)**
*   **LangChain v1.0** 스타일의 `TypedDict`를 사용하여 상태를 정의합니다.
    ```python
    class AgentState(TypedDict):
        messages: Annotated[list[AnyMessage], add_messages]
        context_needs: list[str] # ["local_impact", "global_pattern"]
        retrieved_docs: list[Document]
    ```

**4.2 그래프 노드 및 흐름 (Hybrid Thinking)**
*   **Node 1: IntentClassifier** - 사용자가 "이 함수 고쳐줘"(Local)인지 "이런 기능 구현한 적 있어?"(Global)인지 판단합니다.
*   **Node 2: LocalRetriever (Fast Thinking)** - CodeGraph MCP를 호출하여 현재 파일의 AST와 정의를 즉시 가져옵니다.
*   **Node 3: GlobalRetriever (Slow Thinking)** - Neo4j MCP를 호출하여 유사한 과거 이슈나 아키텍처 패턴을 심층 검색합니다.
*   **Node 4: Synthesizer** - 로컬 맥락에 글로벌 지혜를 더해 답변을 생성합니다. (예: "이 코드는 A 프로젝트의 버그 패턴과 유사하니 수정하세요.")

#### Phase 5: MCP 인터페이스 표준화
모든 통신은 **MCP(Model Context Protocol)**를 따릅니다.

*   **Client:** LangChain의 `langchain-mcp-adapters`를 사용하여 로컬(CodeGraph) 및 글로벌(Neo4j) 서버를 도구(Tool)로 로드합니다.
*   **Server:** `mcp-neo4j-cypher` (Global) 및 `codegraph` (Local) 공식 이미지를 사용합니다.

---

### 3. LLM을 위한 구현 프롬프트 (Implementation Prompt)

이 명세서를 바탕으로 LLM에게 코딩을 지시할 때는 다음 프롬프트를 사용하십시오:

> "당신은 OmniGraph 프레임워크의 수석 아키텍트입니다. **LangChain v1.0**과 **LangGraph**를 사용하여 '계층형 하이브리드 RAG 에이전트'를 구현해야 합니다.
>
> 1.  **데이터 구조**: 로컬 데이터는 `CodeGraph`, 글로벌 데이터는 `Neo4j`를 사용하며, 모든 엔티티는 `urn:{scope}:...` 형식의 URN으로 식별됩니다.
> 2.  **워크플로우**: 사용자의 질문이 들어오면 `IntentClassifier` 노드에서 로컬/글로벌 필요 여부를 판단하고, `StateGraph`를 통해 적절한 MCP 도구를 호출한 뒤 답변을 합성하십시오.
> 3.  **컨텍스트**: `project-template/.agent/agent.md`에 정의된 **Boundaries(Always/Ask/Never)**를 엄격히 준수하는 로직을 `nodes/safeguards.py`에 구현하십시오.
>
> 우선 `platform-core/agent/graph.py`의 `StateGraph` 정의 코드와 `project-template/.agent/agent.md`의 템플릿 내용을 작성해 주세요."

---

LangGraph는 단순한 LLM 체인이 아니라, **상태(State)**를 기반으로 순환(Loop)과 분기(Branching)가 가능한 **시스템**을 구축하는 도구입니다. 앞서 논의한 **CodeGraph(로컬)**와 **Neo4j(글로벌)**를 연결하는 **OmniGraph 프레임워크**를 실제 프로젝트에 적용하기 위한 구체적인 구현 단계를 정리해 드립니다.

이 가이드는 **LangChain v1.0+** 및 **LangGraph**의 최신 API를 기준으로 작성되었습니다.

---

### 1. 상태(State) 정의: 에이전트의 "단기 기억" 설계

LangGraph의 핵심은 모든 노드(Node)가 공유하는 **상태(State)**입니다. 실제 프로젝트에서는 단순한 메시지 목록 외에도, 현재 작업의 문맥을 저장할 필드가 필요합니다,.

```python
from typing import Annotated, TypedDict, List
from langgraph.graph.message import add_messages

# 프로젝트 전용 상태 정의
class AgentState(TypedDict):
    # 대화 기록 (자동으로 기존 메시지에 추가됨)
    messages: Annotated[List, add_messages]
    # 현재 분석 중인 파일 경로 (Local Context)
    current_file: str
    # 검색된 관련 문서들 (RAG Context)
    retrieved_docs: List[str]
    # 사용자의 의도 (Local 수정 vs Global 질문)
    intent: str
```

### 2. MCP 도구 통합: CodeGraph와 Neo4j 연결

`langchain-mcp-adapters`를 사용하여 로컬 분석 도구(CodeGraph)와 글로벌 지식 도구(Neo4j)를 LangChain 도구(Tool)로 변환합니다,.

```python
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_openai import ChatOpenAI

async def load_tools():
    # MCP 클라이언트 설정 (Local: Stdio, Global: SSE/HTTP)
    client = MultiServerMCPClient({
        "local-codegraph": {
            "transport": "stdio",
            "command": "codegraph", # 로컬 CodeGraph 바이너리
            "args": ["start", "stdio"]
        },
        "global-neo4j": {
            "transport": "sse",
            "url": "http://localhost:8000/mcp" # 중앙 Neo4j MCP 서버
        }
    })

    # 모든 도구를 LangChain Tool 객체로 변환
    return await client.get_tools()

# LLM에 도구 바인딩
tools = await load_tools()
llm = ChatOpenAI(model="gpt-4o").bind_tools(tools)
```

### 3. 노드(Node) 및 엣지(Edge) 구현: 워크플로우 로직

실제 프로젝트에서는 단순히 도구를 호출하는 것을 넘어, **의도 파악(Router)** -> **도구 실행(Execute)** -> **검증(Verify)**의 흐름을 만듭니다,.

#### A. 노드 정의 (Nodes)
```python
from langgraph.prebuilt import ToolNode

# 1. 의도 파악 및 답변 생성 노드
def agent_node(state: AgentState):
    # 현재 상태(메시지 등)를 기반으로 LLM 호출
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

# 2. 도구 실행 노드 (LangGraph 내장 기능 활용)
tool_node = ToolNode(tools)
```

#### B. 조건부 엣지 (Routing Logic)
사용자가 "이 함수 고쳐줘"라고 하면 로컬 도구를, "다른 팀은 어떻게 했어?"라고 하면 글로벌 도구를 호출하도록 판단합니다.

```python
from typing import Literal

def router(state: AgentState) -> Literal["tools", "__end__"]:
    last_message = state["messages"][-1]

    # LLM이 도구 호출을 요청했는지 확인
    if last_message.tool_calls:
        return "tools"
    # 도구 호출이 없으면 종료
    return "__end__"
```

### 4. 그래프(Graph) 조립 및 컴파일

정의한 요소들을 연결하여 실행 가능한 애플리케이션으로 만듭니다.

```python
from langgraph.graph import StateGraph, START, END

# 그래프 초기화
workflow = StateGraph(AgentState)

# 노드 추가
workflow.add_node("agent", agent_node)
workflow.add_node("tools", tool_node)

# 엣지 연결 (Start -> Agent)
workflow.add_edge(START, "agent")

# 조건부 엣지 설정 (Agent -> (Tools or End))
workflow.add_conditional_edges(
    "agent",
    router,
    {"tools": "tools", "__end__": END}
)

# 도구 실행 후 다시 에이전트로 순환 (ReAct 패턴)
workflow.add_edge("tools", "agent")

# 체크포인터(메모리)와 함께 컴파일
from langgraph.checkpoint.memory import MemorySaver
app = workflow.compile(checkpointer=MemorySaver())
```

### 5. 실제 프로젝트 적용을 위한 고급 패턴 (GSD & Human-in-the-loop)

단순한 챗봇을 넘어 실제 엔지니어링 도구로 만들기 위해 다음 패턴들을 추가합니다.

#### A. GSD(Get Shit Done) 워크플로우 통합
앞서 설계한 `SPEC.md`나 `PLAN.md`를 **시스템 프롬프트**로 주입하여, 에이전트가 항상 프로젝트 문맥을 유지하게 합니다,.

```python
def agent_node(state: AgentState):
    # GSD 문서 로드 (예: SPEC.md)
    with open(".specs/SPEC.md", "r") as f:
        spec_content = f.read()

    system_message = f"당신은 다음 명세서를 따르는 엔지니어입니다:\n{spec_content}"

    # 메시지 리스트의 맨 앞에 시스템 메시지 추가하여 호출
    messages = [{"role": "system", "content": system_message}] + state["messages"]
    response = llm.invoke(messages)
    return {"messages": [response]}
```

#### B. 휴먼 인 더 루프 (Human-in-the-Loop) 적용
글로벌 DB에 데이터를 쓰거나 중요한 코드를 수정할 때는 사람의 승인을 받도록 설정합니다,. `interrupt_before`를 사용하면 도구 실행 직전에 멈춥니다.

```python
# 도구 실행 전에 일시 정지하여 사용자 승인 대기
app = workflow.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["tools"]
)
```

### 요약: 적용 로드맵

1.  **초기화 (`/init`)**: `StateGraph`를 사용하여 기본 `agent`와 `tools` 노드를 연결합니다. `langchain-mcp-adapters`로 로컬/글로벌 도구를 로드합니다.
2.  **컨텍스트 주입**: `project-template`에 있는 `.agent/agent.md`와 `.specs/SPEC.md`를 읽어 시스템 프롬프트에 동적으로 삽입하는 로직을 `agent` 노드에 구현합니다.
3.  **안전장치**: 데이터베이스 변경(`write-neo4j`)이나 파일 삭제 같은 민감한 도구는 `interrupt_before`를 설정하여, 에이전트가 실행하기 전 사용자가 `y/n`를 입력하게 합니다.
4.  **지속성**: `MemorySaver`를 사용하여 대화가 끊겨도 이전 상태(State)에서 작업을 재개할 수 있도록 합니다.

---

OmniGraph 프레임워크의 완성도를 높이기 위해, 개발자와 관리자가 데이터의 구조와 흐름을 시각적으로 파악할 수 있는 **GUI(Web Dashboard)** 계층을 추가하는 방안을 제안합니다.

제공해주신 자료(Neo4j 생태계, SurrealDB 특징 등)를 바탕으로 **Global Tier(Neo4j)**와 **Local Tier(SurrealDB)** 각각에 최적화된 시각화 도구를 통합하고, 이를 프로젝트 구조에 반영하는 방법을 정리해 드립니다.

---

### 1. 시각화 전략 (Visualization Strategy)

데이터베이스별로 성격이 다르므로, 두 가지 접근 방식을 혼용하는 것이 효율적입니다.

| 계층 (Tier) | DB | 추천 도구 | 선정 이유 및 특징 |
| :--- | :--- | :--- | :--- |
| **Global (Hub)** | **Neo4j** | **Neo4j Bloom** (탐색용) 또는 **NeoDash** (대시보드용) | Neo4j는 그래프 시각화 도구가 매우 성숙해 있습니다. **NeoDash**는 노드/엣지뿐만 아니라 프로젝트 현황(버그 수, 의존성 통계)을 차트로 보여주는 데 최적입니다. |
| **Local (Spoke)** | **SurrealDB** | **Surrealist** (오픈소스 GUI) | CodeGraph가 사용하는 SurrealDB 데이터를 쿼리하고 시각화하는 공식 도구입니다. 가볍고 로컬 실행이 쉽습니다. |
| **Unified (Admin)** | **Custom** | **Streamlit / React Admin** | MCP 서버와 통신하여 로컬/글로벌 상태를 한눈에 보는 간단한 웹앱을 프레임워크에 내장합니다. |

---

### 2. 변경된 프로젝트 디렉토리 구조

기존 구조에서 `platform-core`에 대시보드 관련 모듈을 추가하고, `project-template`에는 로컬 시각화 실행 스크립트를 추가합니다.

```text
OmniGraph/
├── 📂 project-template/           # [Local Spoke]
│   ├── ... (기존 파일들)
│   ├── scripts/
│   │   ├── start_gui.sh           # [NEW] 로컬 데이터 시각화(Surrealist) 실행 스크립트
│   │   └── ...
│   └── docker-compose.local.yml   # [NEW] 로컬 개발용 GUI(Surrealist) 컨테이너 정의
│
├── 📂 platform-core/              # [Global Hub]
│   ├── ... (기존 파일들)
│   ├── 📂 dashboard/              # [NEW] 중앙 통합 대시보드
│   │   ├── neodash/               # NeoDash 설정 및 스키마 파일
│   │   │   └── config.json        # 전사 프로젝트 현황 대시보드 레이아웃
│   │   └── web-admin/             # (선택사항) 커스텀 통합 관리자 페이지 (React/Streamlit)
│   │       ├── App.tsx
│   │       └── mcp-client.ts      # MCP를 통해 Global/Local 상태 조회
│   └── docker-compose.yml         # Neo4j + NeoDash + Web Admin 실행 정의
```

---

### 3. 상세 구현 가이드

#### A. Global Tier 시각화: NeoDash 통합
전사적인 코드 자산, 아키텍처 의존성, 팀 간 API 사용 관계를 시각화하기 위해 **NeoDash**를 `platform-core`에 내장합니다. NeoDash는 별도의 코딩 없이 JSON 설정만으로 그래프와 차트 대시보드를 구성할 수 있습니다.

*   **`platform-core/docker-compose.yml` 추가:**
    ```yaml
    services:
      neo4j:
        image: neo4j:5.15-enterprise
        ports:
          - "7474:7474" # Browser (기본 탐색)
          - "7687:7687" # Bolt Protocol
        # ... (기타 설정)

      neodash:
        image: neodash/neodash
        ports:
          - "5005:5005"
        environment:
          - ssoEnabled=false
          - standalone=true
    ```
*   **활용 시나리오:** "어떤 라이브러리가 가장 많이 쓰이는가?", "최근 일주일간 아키텍처 위반(Arch Guardrails)이 발생한 프로젝트는?" 등의 질문을 시각화된 차트로 제공합니다.

#### B. Local Tier 시각화: Surrealist (Local Inspector)
개발자가 현재 작업 중인 코드의 AST 구조와 CodeGraph가 분석한 의존성을 확인하기 위해 로컬 DB 뷰어를 제공합니다.

*   **`project-template/scripts/start_gui.sh`:**
    개발자가 터미널에서 `npm run gui` 또는 `./scripts/start_gui.sh`를 입력하면 Surrealist를 실행하여 로컬 `.codegraph/surreal.db`에 연결합니다.
    ```bash
    #!/bin/bash
    echo "Starting CodeGraph Inspector..."
    # Surrealist를 Docker로 띄우거나 로컬 바이너리 실행
    docker run --rm -p 8080:8080 -v $(pwd)/.codegraph:/data surrealdb/surrealist:latest
    echo "Inspector running at http://localhost:8080"
    ```
*   **효과:** 개발자는 자신의 코드가 어떻게 그래프(Nodes/Edges)로 변환되었는지 눈으로 직접 디버깅할 수 있습니다.

#### C. (고급) MCP 기반 통합 Admin Web
단순 DB 조회를 넘어, **MCP 프로토콜을 활용한 대화형 웹 인터페이스**를 원한다면 `platform-core/dashboard/web-admin`에 간단한 **Streamlit** 앱을 추가하는 것이 좋습니다.

*   **기능:** MCP 클라이언트 역할을 수행하며, LLM 없이도 미리 정의된 MCP 툴을 버튼 클릭으로 호출합니다.
    *   버튼: `Check Architecture Compliance` -> (Neo4j MCP 호출) -> 결과 출력
    *   버튼: `Show Recent Logic Changes` -> (CodeGraph MCP 호출) -> 결과 출력
*   **구현 기술:** LangChain의 `langchain-mcp-adapters`를 사용하여 Python 기반의 간단한 Admin UI를 구성합니다.

### 4. 사용자 경험 (UX) 시나리오

1.  **개발자 (Local):**
    *   코드를 수정하다가 의존성이 꼬인 것 같을 때 `npm run gui`를 실행합니다.
    *   `http://localhost:8080` (Surrealist)이 뜨고, `Function` 테이블을 조회하여 내 함수가 어떤 다른 함수들과 연결(`CALLS`)되어 있는지 그래프로 확인합니다.
2.  **아키텍트/관리자 (Global):**
    *   `http://hub.omnigraph.internal:5005` (NeoDash)에 접속합니다.
    *   전체 프로젝트의 '순환 참조(Circular Dependency)' 경고등이 켜진 것을 확인하고, 해당 프로젝트 담당자에게 알림을 보냅니다.

이 구성을 통해 OmniGraph는 단순한 백엔드 프레임워크가 아니라, **개발자와 관리자가 눈으로 보고 제어할 수 있는 시각적 플랫폼**으로 진화하게 됩니다.
