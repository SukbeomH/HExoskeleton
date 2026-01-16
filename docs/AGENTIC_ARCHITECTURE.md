# 🧠 Agentic MoE Architecture & Specification

> **통합 아키텍처 명세서**: Agentic MoE(Mixture of Experts), 토큰 효율화 전략, 그리고 특화 에이전트 정의를 통합한 최종 청사진입니다.

---

## 🏗️ 1. Architecture Overview: Agentic MoE (LangGraph 1.0)

LangChain 1.0 및 LangGraph 1.0의 최신 기능을 활용하여, **Stateless Subagents**와 **Dynamic Routing**을 특징으로 하는 Agentic MoE 구조를 구현합니다.

```mermaid
graph TD
    UserInput --> Supervisor[🤖 Supervisor (Orchestrator)]
## 🛡️ 6. Quality & Safety Framework (LangChain Best Practices)

LangChain의 Testing, Context Engineering, Guardrails 모범 사례를 통합한 품질 보증 체계입니다.

### A. Testing Strategy (Test-Driven Agent)
단위 테스트부터 E2E 평가까지 계층적 테스트를 수행합니다.

1.  **Unit Logic Test**: `pytest`를 사용하여 각 Node(Architect, Artisan 등)의 로직을 Mocking된 State로 테스트.
2.  **Integration Test**: 실제 MCP 도구(Docker)와 연동하여 Tool 호출 성공 여부 검증.
3.  **LLM-as-a-Judge Evaluation**: `Guardian` 에이전트가 "평가자"가 되어 실행 결과를 채점.
    -   `benchmark/cases.yaml`에 정의된 골든 케이스 실행.
    -   성공 기준: Intent 합치 여부, 코드 문법 정확성, 보안 규정 준수.

### B. Context Engineering (Optimized Context Window)
"Write, Select, Compress, Isolate" 원칙을 적용하여 토큰 효율성을 극대화합니다.

1.  **Context Budgeting**: 각 에이전트 단계별 최대 토큰 예산 설정.
2.  **Stateless Isolation**: 서브 에이전트는 독립된 그래프로 격리하여 불필요한 컨텍스트 오염 방지.
3.  **Active Compression**: `Supervisor`로 복귀 시, 이전 단계의 긴 로그를 요약(Summary)하여 `messages`를 압축.

### C. Guardrails (Input/Output Validation)
Agent의 입출력을 제어하여 안전성과 정확성을 보장합니다.

1.  **Input Guardrails (Supervisor)**:
    -   **Prompt Injection Detection**: 악의적인 프롬프트 감지 및 거부.
    -   **PII Stripping**: 개인정보 마스킹 (Middleware).
2.  **Output Guardrails (Experts)**:
    -   **Strict JSON Enforcement**: `PLAN.md` 등의 산출물 구조 강제.
    -   **Intent Verification**: `INTENT.md` 기준의 최종 적합성 검사 (Guardian).

    subgraph "Expert Pool (Stateless MoE)"
        Supervisor -- "Command(goto='architect')" --> Architect[🏛️ Lead Architect]
        Supervisor -- "Command(goto='artisan')" --> Artisan[🔨 Code Artisan]
        Supervisor -- "Command(goto='guardian')" --> Guardian[🛡️ Quality Guardian]
        Supervisor -- "Command(goto='librarian')" --> Librarian[📚 Knowledge Librarian]
    end

    Architect <--> SharedMem[(🧠 Shared State)]
    Artisan <--> SharedMem
    Guardian <--> SharedMem
    Librarian <--> SharedMem

    SharedMem --> Output[Final Response]
```

### 핵심 기술 스택 (LangChain 1.0+)
- **LangGraph 1.0**: `Command` 패턴을 사용한 명시적 제어 흐름 및 **Multi-Agent Handoffs** 구현.
- **Handoffs**: 에이전트 간 제어권 이양 시 `Command(goto="next_agent", update={"state": ...})`를 사용하여 명시적으로 전환합니다.
- **Middleware**: LangChain 1.0의 미들웨어 아키텍처를 통해 PII 필터링 및 모델 폴백 적용.
- **Stateless Design**: 모든 서브 에이전트는 대화 내역(Chat History)을 유지하지 않는 **Pure Function**으로 동작합니다.

---

## 📉 2. Efficiency Strategy: Stateless & Externalized Context

2025년 Agentic AI의 핵심 트렌드인 **Stateless Subagents** 패턴을 적용하여 토큰 비용을 최적화합니다.

### A. Stateless Subagents (상태 비공유)
에이전트 간 핸드오프 시 **대화 내역(Chat History)을 전달하지 않습니다**. 각 에이전트는 새로운 세션에서 시작하며, 필요한 정보만 `Shared State`에서 조회합니다.

| 방식 | 설명 | LangGraph 구현 |
|------|-----|---------------|
| **Pass-by-Value** (Legacy) | 이전 에이전트의 대화 내역을 모두 prompt에 포함 | `messages=[...history]` |
| **Stateless** (Proposed) | 대화 내역 초기화, Artifact 참조만 전달 | `messages=[], plan_ref="PLAN.md"` |

### B. Shared State (외부 메모리)
LangGraph의 `State`는 최소한의 메타데이터만 유지하고, 실제 데이터는 외부에 저장합니다.

1.  **Shrimp Task Manager**: 작업의 '진행 상태(Progress)'를 관리하는 Control Plane.
2.  **Artifact Store (Files)**: `PLAN.md`, `PRD.md`, 소스 코드 등 실제 '컨텐츠' 저장소.
3.  **Vector Store (Codanna)**: 코드베이스에 대한 '지식' 검색 엔진 (Just-in-Time Context).

---

## 👥 3. Agent Definitions (The 4 Pillars)

**RIPER-5** 워크플로우를 수행하는 4개의 핵심 전문가 에이전트입니다.

### 🏛️ Lead Architect (The Brain)
- **Role**: `[RESEARCH]`, `[PLAN]`
- **Responsibility**: 불확실성 제거, 구조 분석, 기술 명세(`PLAN.md`) 작성 및 승인 획득.
- **Tools**: `Codanna` (Search/Index), `Shrimp` (Plan Task)
- **Artifact**: `implementation_plan.md`

### 🔨 Code Artisan (The Hands)
- **Role**: `[EXECUTE]`
- **Responsibility**: 승인된 계획을 100% 충실하게 코드로 변환. 정밀 편집 수행.
- **Tools**: `Serena` (Symbol Edit)
- **Artifact**: 소스 코드 변경, `tests/`

### 🛡️ Quality Guardian (The Shield)
- **Role**: `[VERIFY]`
- **Responsibility**: 구현 결과와 계획의 일치 여부 검증. 보안/품질/시각적 결함 탐지.
- **Tools**: `AutoVerify`, `VisualVerifier` (Chrome), `Shrimp` (Reflect)
- **Artifact**: 검증 리포트 (Pass/Fail)
- **Intent Verification**: 초기 `INTENT.md`와 최종 결과물을 비교하여 의도 합치 여부 판단.

---

## 💎 Intent Alignment (New)

사용자의 초기 의도를 보존하고 최종 결과와 대조하기 위한 메커니즘입니다.

1.  **Intent Capture (Start)**:
    -   Supervisor는 대화 시작 시 사용자의 의도를 분석하여 불변의 **Intent Crystal (`INTENT.md`)** artifacts를 생성합니다.
    -   포함 내용: 해결하려는 문제, 핵심 요구사항, 성공 기준(Success Criteria).
2.  **Intent Check (End)**:
    -   Process 종료 시 **Guardian Agent**는 `INTENT.md`를 로드합니다.
    -   최종 구현물(Code/App)이 초기 의도를 충족하는지 별도의 평가 프롬프트로 검증합니다.
    -   `Pass`: 사용자에게 완료 보고.
    -   `Fail`: "구현은 되었으나 원래 의도와 다름" 경고 및 재시도 제안.

### 📚 Knowledge Librarian (The Memory)
- **Role**: `[RECORD]`
- **Responsibility**: 실패 경험을 자산화하고 규칙(`Rules`)으로 승화.
- **Tools**: `ClaudeKnowledgeUpdater`, `sync-knowledge`
- **Artifact**: `CLAUDE.md` (Lessons Learned)

---

## 🧩 4. Sub-agent Composition (Advanced)

복잡도가 높은 대규모 프로젝트의 경우, 각 메인 에이전트를 **서브 에이전트 팀**으로 세분화할 수 있습니다. (LangGraph 계층형 패턴)

| Main Agent | Sub-agents (Functional Roles) |
|------------|------------------------------|
| **Architect Team** | **Analyst** (Req. Analysis) → **System Architect** (Design) → **Planner** (Task breakdown) |
| **Artisan Team** | **TDD Engineer** (Test First) → **Core Dev** (Implementation) → **Refactor Specialist** (Cleanup) |
| **Guardian Team** | **Static Analyst** (Lint/Sec) → **Dynamic Tester** (Runtime) → **Visual Inspector** (UI/UX) |

---

## ⚖️ 5. Implementation Guide (Lean Strategy)

복잡도와 비용의 균형을 맞추기 위한 **Lean Implementation** 가이드입니다.

### Phase 1: Complexity-Based Routing
작업의 복잡도에 따라 실행 경로를 다르게 가져갑니다.

- **Fast Path (Low Complexity)**:
  - 단일 **Omni Agent**가 계획-구현-검증을 한 번에 수행.
  - 단순 버그 수정, 오타 수정, 문서 업데이트 등.
- **Full Path (High Complexity)**:
  - Supervisor -> Architect -> Artisan -> Guardian 전체 파이프라인 가동.
  - 신규 기능 개발, 대규모 리팩토링, 아키텍처 변경 등.

### Phase 2: Role Merging
초기에는 12개의 서브 에이전트 대신 **4개의 메인 에이전트**로 시작하는 것을 권장합니다. 최신 LLM(Claude 3.5 Sonnet 등)은 단일 세션에서 여러 역할을 수행할 수 있는 충분한 역량을 가지고 있습니다.

### Phase 3: State Compression
에이전트 간 전송되는 데이터는 철저히 압축합니다.
- **Input**: User Request + (File Refs)
- **Handoff**: Artifact Paths (Plan path, Code paths)
- **Output**: Summary + (Verified Artifacts)

---

## ⚙️ Configuration Example (agents.yaml)

```yaml
system:
  architecture: "moe" # or "monolith"
  context_strategy: "reference" # or "value"

agents:
  supervisor:
    model: "openai:gpt-4o"
    temperature: 0.1

  architect:
    model: "anthropic:claude-3-5-sonnet-20241022" # Thinking Capability
    tools: ["codanna", "shrimp"]

  artisan:
    model: "anthropic:claude-3-5-sonnet-20241022" # Coding Performance
    tools: ["serena"]

  guardian:
    model: "openai:gpt-4o" # Objective Verification
    tools: ["verify-tools", "chrome-devtools"]
```
