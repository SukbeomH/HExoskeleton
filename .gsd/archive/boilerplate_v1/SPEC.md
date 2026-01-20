# LLM Boilerplate Pack - Project Specification

> **Status**: ✅ FINALIZED
> **Last Updated**: 2026-01-19
> **Version**: 1.0

---

## Vision

A **modular AI coding agent framework** that provides three operational modes (Manual, Full Auto, Hybrid) for different development scenarios. The framework emphasizes **safe injection** into existing projects via isolated subdirectories, preventing conflicts while providing powerful AI-assisted development capabilities.

---

## Problem Statement

Developers need flexible AI assistance that can adapt to different project complexities and control preferences:

1. **Experienced developers** want configuration files only (full control)
2. **Rapid prototypers** want autonomous execution (minimal oversight)
3. **Most developers** want balanced automation with oversight (hybrid approach)

Existing solutions force a single workflow. This boilerplate provides **choice**.

---

## Core Requirements

### Must-Haves

#### 1. Safe Injection Pattern
- ✅ All boilerplate files injected into `.agent-booster/` subdirectory
- ✅ Zero modification of existing project files without consent
- ✅ Automatic `.gitignore` entry for injected directory
- ✅ Complete isolation from host project structure

#### 2. Three Operational Modes

##### Option A: Manual Mode
- MCP server Docker Compose files
- Environment variable templates
- Git workflow documentation
- User controls all tool execution

##### Option B: Full Auto Mode
- LangGraph ReAct agent
- Autonomous task execution
- Background process management
- Parallel tool execution
- Requires API keys (Anthropic/OpenAI)

##### Option C: Hybrid Mode (Recommended)
- FastAPI Dashboard (port 8001)
- WebSocket real-time logging
- Pause/Resume execution controls
- Git workflow automation
- SQLite logging backend
- CLI worker integration

#### 3. MCP Server Integration
- **Project-scoped** (not global installation)
- Docker-based execution for stability
- Support for: Serena, Codanna, Shrimp Task Manager, Context7
- Graceful degradation when servers unavailable

#### 4. Launcher GUI
- FastAPI web interface (port 8000)
- Project scanning and analysis
- Mode recommendation engine
- One-click injection

---

## Nice-to-Haves

- [ ] VS Code extension for direct integration
- [ ] Additional MCP servers (Playwright, ProxyMock)
- [ ] Cloud deployment templates
- [ ] Multi-project dashboard
- [ ] Plugin system for custom modes

---

## Technical Stack

### Core
- **Language**: Python 3.11+
- **Agent Framework**: LangGraph (Option B)
- **Web Framework**: FastAPI (Launcher + Dashboard)
- **Database**: SQLite (logging)
- **Containers**: Docker Compose (MCP servers)

### MCP Servers
- **Serena**: Python (uv)
- **Codanna**: Rust
- **Shrimp**: Node.js
- **Context7**: Node.js

### Frontend
- **Dashboard**: HTML + JavaScript + WebSocket
- **Styling**: Vanilla CSS (modern aesthetics)

---

## User Flows

### Flow 1: First-Time Setup
1. User clones boilerplate repository
2. Runs `python -m launcher.app`
3. Browser opens to http://localhost:8000
4. Enters target project path
5. Clicks "Scan Project"
6. Reviews mode recommendation
7. Clicks "Inject Selected Kit"
8. Files copied to `<project>/.agent-booster/`

### Flow 2: Using Option C (Hybrid)
1. Navigate to injected directory
2. Run Dashboard: `python -m uvicorn runtime.app:app --port 8001`
3. Open http://localhost:8001
4. Click "Start Demo" (mock agent) or "Start" (real CLI)
5. View real-time logs in browser
6. Use Pause/Resume as needed
7. Review Git commits automatically created

### Flow 3: MCP Server Management
1. Navigate to `mcp/` directory
2. Run `docker-compose -f docker-compose.mcp.yml up -d`
3. Verify servers: `docker-compose ps`
4. Check logs: `docker-compose logs -f`
5. Stop when done: `docker-compose down`

---

## Success Metrics

### Technical
- ✅ Injection completes in < 5 seconds
- ✅ Dashboard loads in < 2 seconds
- ✅ MCP servers respond in < 500ms
- ✅ Zero file conflicts with host projects
- ✅ WebSocket latency < 100ms

### User Experience
- ✅ New user can inject in < 5 minutes
- ✅ Clear error messages with actionable steps
- ✅ Visual confirmation of each operation
- ✅ No manual file editing required for basic usage

---

## Non-Goals

### Out of Scope
- ❌ Cloud-hosted AI execution (local only)
- ❌ Multi-user collaboration features
- ❌ Production deployment automation
- ❌ IDE plugins (focus on web interfaces)
- ❌ Global MCP server installation

---

## Architecture Constraints

### 1. Directory Isolation
- **Rule**: Never write outside `.agent-booster/` during injection
- **Exception**: Only update `.gitignore` (append mode)

### 2. Port Allocation
- **Launcher**: 8000 (fixed)
- **Dashboard**: 8001 (configurable via env)
- **Context7 MCP**: 8080 (configurable via env)
- **Codanna MCP**: 8081 (configurable via env)

### 3. Environment Variables
- **Required**: PROJECT_NAME, PROJECT_MODE, LOG_DB_PATH
- **Optional (B)**: ANTHROPIC_API_KEY, OPENAI_API_KEY
- **Optional (C)**: CLI_COMMAND_PATH, CLI_TIMEOUT
- **MCP**: CONTEXT7_API_KEY

### 4. Git Integration
- **Auto-branch**: `feature/ai-task-<uuid>`
- **Auto-commit**: Enabled (with descriptive messages)
- **Auto-push**: Disabled (requires manual confirmation)

---

## Security Considerations

1. **API Key Management**
   - Store in `.env` files only
   - Never commit to Git
   - Provide `.env.example` templates

2. **Command Execution**
   - Validate CLI paths before execution
   - Timeout protection (default 600s)
   - Sanitize shell inputs

3. **File System**
   - Path traversal prevention
   - Validate target directories
   - Respect `.gitignore` patterns

---

## Testing Strategy

### Unit Tests
- Injection logic (`tests/test_injection.py`)
- Logging functionality (`tests/test_logging.py`)
- Git operations (`tests/test_git.py`)

### Integration Tests
- Full Option C workflow
- MCP server connectivity
- WebSocket communication

### Manual Testing
- Mock agent execution (no API keys)
- Dashboard UI/UX
- Cross-browser compatibility

---

## Documentation

### User-Facing
- ✅ README.md (overview)
- ✅ QUICKSTART.md (5-minute guide)
- ✅ TROUBLESHOOTING.md (common issues)
- ✅ .agent/ANTIGRAVITY_QUICKSTART.md (Antigravity-specific)

### Developer-Facing
- ✅ .agent/context.md (architecture)
- ✅ .agent/rules.md (coding standards)
- ✅ CONTRIBUTING.md (contribution guide)

---

## Roadmap

### Phase 1: Core Framework ✅ COMPLETE
- Injection system
- Three operational modes
- Launcher GUI
- Basic MCP integration

### Phase 2: Stability & Polish 🚧 IN PROGRESS
- Comprehensive error handling
- Cross-platform testing (Windows/Mac/Linux)
- Performance optimization
- Extended documentation

### Phase 3: Enhancements 📋 PLANNED
- Additional MCP servers
- Custom workflow templates
- Enhanced Dashboard UI
- VS Code extension

---

## Questions & Decisions

### Q1: Why three modes instead of one flexible mode?
**A**: Different projects have different needs. Simple scripts don't need autonomous agents. Complex refactors benefit from full automation. Most projects want oversight. Three modes serve distinct use cases.

### Q2: Why `.agent-booster/` instead of `.ai/` or `.agent/`?
**A**: Descriptive and unique. Unlikely to conflict with existing tooling. Clear intent.

### Q3: Why project-scoped MCP servers instead of global?
**A**: Isolation prevents conflicts. Different projects may need different versions, configurations, or API keys. Docker provides consistent environments per project.

### Q4: Why SQLite for logging instead of files?
**A**: Queryable, structured, atomic writes, familiar SQL interface, single-file portability.

---

## Change Log

### 2026-01-19 - v1.0
- Initial specification
- All core requirements defined
- Architecture constraints established
- Finalized for implementation

---

**This specification is FINALIZED. No code should be written that contradicts these requirements.**
