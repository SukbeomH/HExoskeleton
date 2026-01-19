# LLM Boilerplate Pack - Getting Started with Antigravity

## Quick Start

This boilerplate is designed to work seamlessly with **Google Antigravity**. Follow this guide to get up and running.

## Prerequisites

- Python 3.11+
- Docker (for MCP servers)
- Git
- Node.js 18+ (for some MCP servers)

## Setup Steps

### 1. Clone and Open in Antigravity

```bash
# Open the boilerplate project in Antigravity
# Antigravity will automatically detect .agent/ configuration
```

### 2. Install Dependencies

```bash
# Run the setup workflow
/setup-boilerplate
```

Or manually:
```bash
cd /Users/sukbeom/Desktop/workspace/boilerplate
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure Environment Variables

```bash
# Copy templates
cp .env.example .env
cp .env.mcp.example .env.mcp

# Edit .env.mcp and add your API keys
# Required: CONTEXT7_API_KEY
```

### 3. Verify MCP Configuration

The MCP servers are configured **project-scoped** in `.agent/mcp_config.json`:

```bash
# Check project's MCP config
cat .agent/mcp_config.json
```

**Important**:
- ✅ Each project has its own `.agent/mcp_config.json`
- ✅ Antigravity reads this file when you open the project
- ❌ Global config (`~/.gemini/antigravity/mcp_config.json`) should be empty

See [MCP_CONFIG_GUIDE.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/.agent/MCP_CONFIG_GUIDE.md) for detailed explanation.

### 4. Start MCP Servers (Project-Scoped)

```bash
# Use the MCP workflow
/mcp-docker

# Or manually
cd mcp
docker-compose -f docker-compose.mcp.yml up -d
```

**Available MCP Servers:**
- **Serena** - Python code analysis
- **Codanna** - Multi-language code intelligence
- **Shrimp Task Manager** - Task tracking
- **Context7** - Semantic search (requires API key)

### 5. Verify MCP Integration

In Antigravity:
1. Check MCP server status in the sidebar
2. All 4 servers should show as "Connected"
3. If not, check logs: `docker-compose -f mcp/docker-compose.mcp.yml logs`

## Available Workflows (Slash Commands)

Antigravity recognizes these custom workflows:

| Command | Description |
|---------|-------------|
| `/setup-boilerplate` | Install dependencies and set up environment |
| `/run-option-c` | Start the Hybrid Dashboard mode |
| `/mcp-docker` | Manage Docker-based MCP servers |

## Using the Boilerplate

### Option A: Manual Mode
Configuration files only. You control everything.

### Option B: Full Auto Mode
LangGraph-based autonomous agent. Requires API keys.

### Option C: Hybrid Mode (Recommended)
Real-time dashboard with pause/resume controls.

```bash
# Start Launcher to inject into projects
python -m launcher.app
# Visit http://localhost:8000
```

## Working with State Files

This project follows the **GSD (Get Shit Done)** methodology for state management:

### Core Files (Auto-Created)

- `.gsd/SPEC.md` - Project specification (finalize before coding)
- `.gsd/STATE.md` - Session memory and current position
- `.gsd/ROADMAP.md` - Phases and progress tracking
- `.gsd/DECISIONS.md` - Architecture decisions
- `.gsd/JOURNAL.md` - Session log

These files help Antigravity maintain context across sessions.

## Project Structure Overview

```
boilerplate/
├── .agent/              # Antigravity configuration
│   ├── rules.md        # Project-specific rules
│   ├── context.md      # Architecture documentation
│   ├── workflows/      # Slash commands
│   └── mcp_config.json # MCP server config (project-scoped)
│
├── kits/               # Injection packages
│   ├── option_a/       # Manual mode
│   ├── option_b/       # Full auto mode
│   └── option_c/       # Hybrid mode
│
├── launcher/           # GUI for injection
├── mcp/               # MCP server Docker setup
└── langchain_tools/   # Core libraries
```

## Testing the Setup

### Test 1: MCP Servers
```bash
# Check all servers are running
docker-compose -f mcp/docker-compose.mcp.yml ps

# Expected: All services showing "Up"
```

### Test 2: Launcher
```bash
# Start the launcher
python -m launcher.app

# Should open browser at http://localhost:8000
```

### Test 3: Option C Dashboard
```bash
# Run the workflow
/run-option-c

# Or manually
cd <injected-project>/.agent-booster
python -m uvicorn runtime.app:app --port 8001
```

## Injecting into Your Projects

1. **Start Launcher**: `python -m launcher.app`
2. **Scan Project**: Enter target project path
3. **Select Mode**: Choose Option A, B, or C
4. **Inject**: Click "Inject Selected Kit"
5. **Result**: Files copied to `<project>/.agent-booster/`

## MCP Server Scope

> **Important**: MCP servers are **project-scoped**, not global.

Each project gets its own:
- MCP configuration (`.agent/mcp_config.json`)
- Docker containers (when injected with Docker setup)
- Environment variables (`.env.mcp`)

This ensures:
- ✅ Isolated dependencies per project
- ✅ Different API keys per project
- ✅ No global conflicts

## Troubleshooting

### MCP Servers Not Connecting

1. Check Docker containers:
```bash
docker-compose -f mcp/docker-compose.mcp.yml ps
```

2. View logs:
```bash
docker-compose -f mcp/docker-compose.mcp.yml logs -f
```

3. Restart services:
```bash
docker-compose -f mcp/docker-compose.mcp.yml restart
```

### Port Conflicts

```bash
# Kill processes on conflicting ports
lsof -ti:8000 | xargs kill
lsof -ti:8001 | xargs kill
lsof -ti:8080 | xargs kill
lsof -ti:8081 | xargs kill
```

### Context7 Authentication Errors

- Verify `CONTEXT7_API_KEY` in `.env.mcp`
- Get API key from: https://context7.com
- Restart Context7 container after updating

### Dashboard Not Loading

- Check `.env` file exists in `.agent-booster/`
- Verify `PROJECT_ROOT` path is correct
- Refresh browser (F5)
- Check WebSocket connection in browser console

## Next Steps

1. ✅ Verify all MCP servers are connected
2. ✅ Run `/setup-boilerplate` workflow
3. ✅ Test Option C Dashboard with mock agent
4. 📖 Read [context.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/.agent/context.md) for architecture details
5. 📖 Read [rules.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/.agent/rules.md) for coding guidelines

## Getting Help

- **Documentation**: See [README.md](../README.md) and [QUICKSTART.md](../QUICKSTART.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- **Architecture**: See [context.md](context.md)
- **Workflows**: Check `.agent/workflows/` directory

## Philosophy

This boilerplate follows these principles:

1. **Safe Injection** - Never modify existing project files
2. **Mode Flexibility** - Choose your control level
3. **Project Scope** - MCP servers isolated per project
4. **State Management** - GSD methodology for context
5. **Empirical Validation** - Prove it works, don't assume

---

**Ready?** Start with `/setup-boilerplate` and then use the Launcher to inject into your first project!
