# Project Rules for LLM Boilerplate Pack

## Core Principles

### 1. Safe Injection Pattern
- **ALWAYS** inject boilerplate files into `.agent-booster/` subdirectory
- **NEVER** modify existing project files without explicit user consent
- Automatically add `.agent-booster/` to `.gitignore`
- Maintain isolation from the host project's structure

### 2. Mode-Specific Guidelines

#### Option A: Manual Mode
- Provide configuration files only (Docker Compose, env templates)
- No automated execution - user controls all tools
- Focus on MCP server setup and environment variables

#### Option B: Full Auto Mode
- LangGraph-based autonomous agent execution
- Requires API keys (ANTHROPIC_API_KEY or OPENAI_API_KEY)
- Background task management with parallel execution
- Automatic tool selection and orchestration

#### Option C: Hybrid Mode (Recommended)
- Real-time WebSocket dashboard on port 8001
- Pause/Resume control for user oversight
- Git workflow integration (auto-branching)
- Structured logging to SQLite (`.logs/events.db`)
- CLI worker integration for external tools

## Code Quality Standards

### Logging
- Use `StructuredLogger` from `langchain_tools.core.logging`
- Always include context (task_id, mode, component)
- Log to both console and database
- Use appropriate log levels: DEBUG, INFO, WARNING, ERROR

### Error Handling
- Graceful degradation when MCP servers unavailable
- Clear error messages with actionable suggestions
- Timeout protection for CLI commands (default: 600s)
- Validate environment variables before execution

### Git Integration
- Auto-create feature branches with prefix `feature/ai-task-`
- Commit with descriptive messages
- Never push without user confirmation
- Respect existing `.gitignore` patterns

## MCP Server Usage

### Available Servers
1. **Serena** (Python/uv)
   - Code analysis and suggestions
   - Python project introspection

2. **Codanna** (Rust)
   - High-performance code intelligence
   - Multi-language support

3. **Shrimp Task Manager** (Node.js)
   - Task tracking and management
   - Integration with project workflows

4. **Context7** (Node.js)
   - Semantic code search
   - Context retrieval
   - Requires `CONTEXT7_API_KEY`

### MCP Server Guidelines
- Use Docker-based execution for stability (via `mcp/mcp-docker-runner.js`)
- Check server health before making requests
- Handle server unavailability gracefully
- Respect rate limits and timeouts

## Dashboard Integration (Option C)

### WebSocket Communication
- Connect to `ws://localhost:8001/ws`
- Send structured JSON messages
- Handle reconnection automatically
- Display real-time logs with color coding

### Control Commands
- `START_DEMO`: Run mock agent
- `PAUSE`: Suspend execution
- `RESUME`: Continue execution
- `CLEAR`: Reset logs

## Environment Variables

### Required Variables
```bash
# Core Configuration
PROJECT_NAME="my_project"
PROJECT_MODE="option_c"  # a, b, or c

# Logging
LOG_DB_PATH=".logs/events.db"
LOG_LEVEL="INFO"

# Option C Specific
CLI_COMMAND_PATH="path/to/cli"  # or "mock" for testing
CLI_TIMEOUT=600
GIT_BRANCH_PREFIX="feature/ai-task-"
```

### Optional Variables
```bash
# Option B (Full Auto)
ANTHROPIC_API_KEY=""
OPENAI_API_KEY=""
TAVILY_API_KEY=""

# MCP Servers
CONTEXT7_API_KEY=""
MCP_DOCKER_HOST="localhost"
MCP_CONTEXT_PORT=8080
MCP_CODANNA_PORT=8081
```

## Testing Guidelines

### Mock Agent Testing
- Use `mock_agent.py` or `mock_agent.sh` for local testing
- Simulates realistic agent behavior with delays
- No API keys required
- Validates Dashboard functionality

### Integration Testing
1. Test each mode independently
2. Verify MCP server connectivity
3. Validate Git workflow (branching, commits)
4. Check Dashboard WebSocket communication
5. Test error handling and recovery

## Security Considerations

- **Never commit** `.env` files with real API keys
- Use `.env.example` templates for sharing
- Validate user input before shell execution
- Sanitize file paths to prevent directory traversal
- Review auto-generated Git commits before pushing

## Performance Optimization

### Parallel Execution
- Use asyncio for concurrent operations
- Batch MCP server requests when possible
- Implement caching for repeated queries

### Resource Management
- Set reasonable timeouts (default: 600s)
- Clean up temporary files
- Limit log database size (rotation/archival)
- Monitor WebSocket connection count

## Documentation Standards

- Keep README.md updated with new features
- Provide clear examples in QUICKSTART.md
- Document breaking changes in TROUBLESHOOTING.md
- Use Mermaid diagrams for architecture visualization
- Include step-by-step workflows for common tasks
