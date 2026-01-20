# Decisions Log

## 2026-01-20: OmniGraph v1.2 - "Don't Reinvent the Wheel"

### Decision
표준 라이브러리와 업계 검증 패턴을 적극 채택하여 커스텀 구현을 최소화합니다.

### Context
- 기존 v1.0은 Neo4j MCP 서버 직접 구현, 복잡한 conditional edges 등 커스텀 코드 비중이 높았음
- 유지보수성, 확장성, 커뮤니티 호환성을 위해 표준 채택 필요

### Adopted Standards

| 영역 | 채택 표준 | 근거 |
|------|-----------|------|
| MCP 연결 | `langchain-mcp-adapters` | 공식 LangChain 어댑터, 멀티서버 지원 |
| 워크플로우 | LangGraph `Command` 패턴 | v1.2+ 권장, 노드 내 라우팅 제어 |
| Agent 스펙 | 6-Core `agent.md` | GitHub 2,500+ 리포 분석 기반 |
| 스킬 정의 | SKILL.md (YAML Frontmatter) | Anthropic/Spring AI 표준 |
| 디렉토리 | `.github/agents/`, `.claude/skills/` | GitHub/Anthropic 권장 |

### Files Changed
- `OMNIGRAPH_SPEC.md` → v1.2.0
- `platform-core/orchestration/mcp_client.py` (NEW)
- `platform-core/orchestration/graph_v2.py` (NEW)
- `project-template/.github/agents/agent.md` (NEW)
- `project-template/.claude/skills/*` (NEW)

### Outcome
- 코드량 감소 (MCP 클라이언트 ~50% 감소)
- 라우팅 로직 단순화 (conditional_edges → Command)
- 업계 표준 호환으로 문서화 부담 감소

---

## 2026-01-19: Project Initialization
- **Decision**: Archive existing boilerplate GSD state and initialize new "OmniGraph" project in the same repo.
- **Context**: User requested /new-project with `OMNIGRAPH_SPEC.md` active.
- **Result**: `.gsd/archive/boilerplate_v1` created.
