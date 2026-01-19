---
description: Setup LLM Boilerplate Pack
---

# Setup LLM Boilerplate Pack

Complete setup workflow for installing dependencies and preparing the boilerplate framework.

## Prerequisites Check

1. Verify Python 3.11+ is installed
2. Verify Docker is installed (for MCP servers)
3. Verify Git is installed

## Installation Steps

// turbo
1. Navigate to the boilerplate directory:
```bash
cd /Users/sukbeom/Desktop/workspace/boilerplate
```

// turbo
2. Create and activate virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate
```

3. Install Python dependencies:
```bash
pip install -r requirements.txt
```

## Environment Configuration

4. Copy environment variable templates:
```bash
cp .env.example .env
cp .env.mcp.example .env.mcp
```

5. Edit `.env.mcp` to add your API keys:
   - `CONTEXT7_API_KEY` - Required for Context7 MCP server
   - Other keys as needed

## MCP Server Setup (Project-Scoped)

6. Build MCP server Docker images (project-specific):
```bash
cd mcp
docker-compose -f docker-compose.mcp.yml build
```

7. Start MCP servers (runs in project scope):
```bash
docker-compose -f docker-compose.mcp.yml up -d
```

8. Verify MCP servers are running:
```bash
docker-compose -f docker-compose.mcp.yml ps
```

## Launch the Boilerplate

// turbo
9. Start the Launcher GUI:
```bash
cd /Users/sukbeom/Desktop/workspace/boilerplate
python -m launcher.app
```

10. Open browser to `http://localhost:8000`

## Next Steps

- Use the Launcher to scan and inject into target projects
- Each injected project will have its own `.agent-booster/` directory
- MCP servers are project-scoped (not global)

## Troubleshooting

**Port conflicts:**
```bash
lsof -ti:8000 | xargs kill
lsof -ti:8001 | xargs kill
```

**Docker issues:**
```bash
docker-compose -f mcp/docker-compose.mcp.yml logs
docker-compose -f mcp/docker-compose.mcp.yml restart
```

**MCP server not connecting:**
- Check `.env.mcp` has correct API keys
- Verify Docker containers are running
- Check firewall settings for ports 8080, 8081
