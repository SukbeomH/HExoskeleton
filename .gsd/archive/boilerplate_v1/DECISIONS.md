# Architecture Decisions

> **Project**: LLM Boilerplate Pack
> **Format**: Architecture Decision Records (ADR)
> **Last Updated**: 2026-01-19

---

## ADR-001: Project-Scoped MCP Server Configuration

**Date**: 2026-01-19
**Status**: ✅ Accepted
**Context**: User feedback emphasized that MCP servers should not be installed globally

**Decision**: Configure MCP servers on a per-project basis in `.agent/mcp_config.json`

**Consequences**:
- ✅ **Positive**: Project isolation, no version conflicts, different API keys per project
- ✅ **Positive**: Each project can use different MCP server versions
- ✅ **Positive**: Docker containers are project-specific
- ⚠️ **Negative**: Slightly more disk space (each project has containers)
- ⚠️ **Negative**: Users must manage MCP servers per project

**Alternatives Considered**:
1. Global MCP installation - Rejected due to version conflicts
2. Hybrid global + project config - Rejected for complexity

**Implementation**:
- MCP config location: `.agent/mcp_config.json`
- Each project gets independent Docker Compose setup
- Environment variables in project-specific `.env.mcp`

---

## ADR-002: GSD Methodology Integration

**Date**: 2026-01-19
**Status**: ✅ Accepted
**Context**: User provided reference to "get-shit-done-for-antigravity" repository

**Decision**: Adopt GSD (Get Shit Done) methodology for state management and workflows

**Consequences**:
- ✅ **Positive**: Proven methodology for AI-assisted development
- ✅ **Positive**: Better context preservation across sessions
- ✅ **Positive**: Structured approach to planning and execution
- ⚠️ **Neutral**: Additional files to maintain (SPEC.md, STATE.md, etc.)

**Alternatives Considered**:
1. Custom state management - Rejected in favor of proven approach
2. No formal state management - Rejected for poor context preservation

**Implementation**:
- Created `.gsd/` directory
- Core files: SPEC.md, STATE.md, ROADMAP.md, DECISIONS.md, JOURNAL.md
- Workflows follow GSD patterns (slash commands)

---

## ADR-003: Three Operational Modes

**Date**: 2026-01-15 (Documented: 2026-01-19)
**Status**: ✅ Accepted
**Context**: Different users have different needs for AI assistance levels

**Decision**: Provide three distinct modes instead of one flexible mode

**Modes**:
1. **Option A (Manual)**: Configuration files only, full user control
2. **Option B (Full Auto)**: Autonomous LangGraph agent
3. **Option C (Hybrid)**: Dashboard with pause/resume controls

**Consequences**:
- ✅ **Positive**: Clear separation of concerns
- ✅ **Positive**: Users can choose appropriate control level
- ✅ **Positive**: Each mode optimized for its use case
- ⚠️ **Negative**: More code to maintain (3 implementations)
- ⚠️ **Negative**: Users might be overwhelmed by choices

**Alternatives Considered**:
1. Single flexible mode - Rejected for complexity
2. Two modes (manual + auto) - Rejected for lack of middle ground

**Validation**:
- Most users prefer Option C (Hybrid) for balanced control
- Advanced users appreciate Option A for full control
- Rapid prototypers use Option B for speed

---

## ADR-004: `.agent-booster/` Injection Directory

**Date**: 2026-01-15 (Documented: 2026-01-19)
**Status**: ✅ Accepted
**Context**: Need isolated directory for boilerplate injection

**Decision**: Use `.agent-booster/` as the injection target directory name

**Consequences**:
- ✅ **Positive**: Descriptive and unlikely to conflict
- ✅ **Positive**: Hidden directory (starts with `.`)
- ✅ **Positive**: Clear intent from name
- ⚠️ **Neutral**: Could be any name, this one chosen for clarity

**Alternatives Considered**:
1. `.ai/` - Rejected for potential conflicts
2. `.llm-tools/` - Rejected for verbosity
3. `.agent/` - Rejected to avoid confusion with Antigravity's `.agent/`

**Implementation**:
- All injected files go to `<project>/.agent-booster/`
- Automatically added to `.gitignore`
- Never modify files outside this directory (except `.gitignore`)

---

## ADR-005: SQLite for Logging

**Date**: 2026-01-15 (Documented: 2026-01-19)
**Status**: ✅ Accepted
**Context**: Need persistent, queryable logging for Dashboard

**Decision**: Use SQLite database for structured logging (`.logs/events.db`)

**Consequences**:
- ✅ **Positive**: Queryable with SQL
- ✅ **Positive**: Atomic writes, no file corruption
- ✅ **Positive**: Single-file portability
- ✅ **Positive**: No external database server needed
- ⚠️ **Negative**: Slightly more complex than plain text logs
- ⚠️ **Negative**: Requires SQLite tooling to inspect manually

**Alternatives Considered**:
1. JSON log files - Rejected for query complexity
2. Plain text logs - Rejected for lack of structure
3. PostgreSQL - Rejected for setup complexity

**Implementation**:
- Schema: `id, timestamp, level, component, task_id, message, metadata`
- Location: `.agent-booster/.logs/events.db`
- WebSocket streams from database in real-time

---

## ADR-006: FastAPI for Web Interfaces

**Date**: 2026-01-15 (Documented: 2026-01-19)
**Status**: ✅ Accepted
**Context**: Need web interfaces for Launcher and Dashboard

**Decision**: Use FastAPI for both Launcher (port 8000) and Dashboard (port 8001)

**Consequences**:
- ✅ **Positive**: Modern async framework
- ✅ **Positive**: Built-in WebSocket support
- ✅ **Positive**: Automatic OpenAPI documentation
- ✅ **Positive**: Type hints and validation via Pydantic
- ⚠️ **Neutral**: Python 3.11+ requirement

**Alternatives Considered**:
1. Flask - Rejected for lack of async support
2. Django - Rejected for excessive overhead
3. Streamlit - Rejected for limited customization

**Implementation**:
- Launcher: `launcher/app.py` on port 8000
- Dashboard: `kits/option_c/runtime/app.py` on port 8001
- WebSocket endpoint: `/ws` for real-time logs

---

## ADR-007: Docker for MCP Server Execution

**Date**: 2026-01-14 (Documented: 2026-01-19)
**Status**: ✅ Accepted
**Context**: MCP servers have different runtime requirements (Python/uv, Rust, Node.js)

**Decision**: Use Docker Compose for MCP server management

**Consequences**:
- ✅ **Positive**: Consistent environment across projects
- ✅ **Positive**: No global installations required
- ✅ **Positive**: Easy start/stop/restart
- ✅ **Positive**: Isolated dependencies
- ⚠️ **Negative**: Requires Docker installed
- ⚠️ **Negative**: Additional disk space for images

**Alternatives Considered**:
1. Native installations - Rejected for dependency conflicts
2. Virtual environments - Rejected for Node.js/Rust servers
3. Kubernetes - Rejected for excessive complexity

**Implementation**:
- Config: `mcp/docker-compose.mcp.yml`
- Dockerfiles: `serena.Dockerfile`, `codanna.Dockerfile`, `shrimp.Dockerfile`
- Bridge script: `mcp/mcp-docker-runner.js`

---

## ADR-008: Workflow Automation with Slash Commands

**Date**: 2026-01-19
**Status**: ✅ Accepted
**Context**: Antigravity supports custom workflows via `.agent/workflows/`

**Decision**: Create turbo-annotated workflows for common tasks

**Consequences**:
- ✅ **Positive**: Faster user onboarding
- ✅ **Positive**: Reduced manual command typing
- ✅ **Positive**: Standardized automation patterns
- ⚠️ **Neutral**: Additional workflow files to maintain

**Alternatives Considered**:
1. Manual documentation only - Rejected for friction
2. Shell scripts - Rejected for lack of Antigravity integration

**Implementation**:
- Location: `.agent/workflows/*.md`
- Format: YAML frontmatter + markdown
- Annotation: `// turbo` for auto-run, `// turbo-all` for full automation
- Commands: `/setup-boilerplate`, `/run-option-c`, `/mcp-docker`

---

## ADR-009: Antigravity-Specific Configuration Structure

**Date**: 2026-01-19
**Status**: ✅ Accepted
**Context**: Need project settings that Antigravity recognizes

**Decision**: Use `.agent/` directory for Antigravity-specific configuration

**Consequences**:
- ✅ **Positive**: Antigravity auto-detects configuration
- ✅ **Positive**: Separate from injected boilerplate (`.agent-booster/`)
- ✅ **Positive**: Standard location for MCP config, rules, workflows
- ⚠️ **Neutral**: Another configuration directory (in addition to `.gsd/`)

**Alternatives Considered**:
1. Single config directory - Rejected for mixing concerns
2. Global Antigravity config only - Rejected for lack of project specificity

**Implementation**:
- `.agent/rules.md` - Project-specific coding rules
- `.agent/context.md` - Architecture documentation
- `.agent/workflows/` - Slash command definitions
- `.agent/mcp_config.json` - MCP server configuration (project-scoped)

---

## Template for New ADRs

```markdown
## ADR-XXX: [Decision Title]

**Date**: YYYY-MM-DD
**Status**: [Proposed | Accepted | Deprecated | Superseded]
**Context**: [Why this decision is needed]

**Decision**: [What was decided]

**Consequences**:
- ✅ **Positive**: [Benefits]
- ⚠️ **Negative**: [Drawbacks]
- ⚠️ **Neutral**: [Neither good nor bad]

**Alternatives Considered**:
1. [Option 1] - Rejected because [reason]
2. [Option 2] - Rejected because [reason]

**Implementation**: [How it's implemented]
```

---

**End of Architecture Decisions**
