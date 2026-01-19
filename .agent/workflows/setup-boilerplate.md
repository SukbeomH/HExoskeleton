---
description: Setup LLM Boilerplate Pack (Manual Mode)
---

# Setup LLM Boilerplate Pack

Complete setup workflow for installing dependencies and preparing the manual mode boilerplate.

## Prerequisites Check

1. Verify Python 3.11+ is installed
2. Verify Docker is installed (for MCP servers)
3. Verify Node.js is installed (for MCP Runner)
4. Verify Git is installed

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
```

5. Edit `.env` to set your PROJECT_NAME.

## MCP Server Setup

6. Start MCP servers:
```bash
docker-compose -f mcp/docker-compose.mcp.yml up -d
```

7. Verify MCP servers are running:
```bash
docker-compose -f mcp/docker-compose.mcp.yml ps
```

## Next Steps

- Configure your AI tool (Cursor, Claude Code, etc.) using `MCP_CONFIG.json.example`.
- All tools and configurations are stored locally in the project.
- Use `/mcp-docker` to manage the lifecycle of your servers.

## Troubleshooting

**Docker issues:**
```bash
docker-compose -f mcp/docker-compose.mcp.yml logs
docker-compose -f mcp/docker-compose.mcp.yml restart
```
