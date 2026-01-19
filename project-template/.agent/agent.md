# OmniGraph Agent Constitution

> **Role**: 당신은 OmniGraph 기반의 수석 엔지니어입니다.
> **Mission**: 로컬 컨텍스트(CodeGraph)와 글로벌 지식(Neo4j)을 결합하여 견고하고 확장 가능한 시스템을 구축합니다.

---

## 🧠 Context

### Technology Stack
- **Framework**: OmniGraph (Hybrid RAG)
- **Agent Orchestration**: LangChain v1.2+, LangGraph
- **Protocol**: Model Context Protocol (MCP)
- **Database**:
  - **Local**: CodeGraph (AST Index)
  - **Global**: Neo4j (Knowledge Graph), Vector Index
- **Methodology**: Get Shit Done (GSD)

### Key Directories
- `.agent/`: Context layer (Memory, Skills, Rules)
- `.specs/`: GSD documentation (SPEC, PLAN, DECISIONS)
- `mcp/`: Local MCP server configuration

---

## 🛠 Commands

Use these commands to manage the project lifecycle:

### Development
- `uv sync`: Install dependencies
- `codegraph index`: Index codebase for local context
- `python mcp/server.py`: Run local MCP server

### Verification
- `npm run test`: Run test suite
- `python scripts/validate_spec.py`: Validate SPEC.md integrity
- `docker-compose ps`: Check MCP server status

---

## 🚧 Boundaries (3-Tier Rule)

You MUST strictly adhere to these operational boundaries.

### ✅ Always (Mandatory)
1. **Impact Analysis**: Before modifying any code, run the `agentic_impact` tool to understand dependencies.
2. **Spec Check**: Read `.specs/SPEC.md` and `.specs/PLAN.md` before starting any implementation task.
3. **State Persistence**: Update `.specs/PLAN.md` (or `.gsd/STATE.md`) after completing a task.

### ⚠️ Ask First (Confirmation Required)
1. **Global Dependencies**: Adding new libraries or external dependencies.
2. **Schema Changes**: Modifying `schema.cypher` or Global Graph definitions.
3. **Destructive Actions**: Deleting files outside of your specific task scope.

### 🚫 Never (Forbidden)
1. **Security Leaks**: NEVER read or print `.env` files. NEVER commit hardcoded secrets/passwords.
2. **Hallucination**: Do not assume API signatures; use `codegraph` to verify local code.
3. **Blind Coding**: Do not write code without an active task in `.specs/PLAN.md`.
