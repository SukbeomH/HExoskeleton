# Option A: Manual Mode Instructions

## Overview
This mode provides **configuration files only** for users who prefer to work with their own tools manually. No automation is included—you retain full control over your workflow.

## What's Included
- **MCP Server Configurations**: Pre-configured Docker Compose files for Serena, Codanna, and Shrimp Task Manager.
- **Environment Template**: `.env.example` with all necessary variables.
- **Git Workflow Integration**: Pre-configured `.gitignore` and branch strategies.

## Prerequisites
- Docker & Docker Compose
- Your preferred AI coding tool (Claude Code, Codex CLI, Cursor, etc.)

## Setup

### 1. Configure Environment
Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
```

Key variables:
```bash
PROJECT_MODE="option_a"
PROJECT_NAME="your-project-name"
```

### 2. Start MCP Services
```bash
docker-compose -f mcp/docker-compose.mcp.yml up -d
```

This starts:
- **Serena** (Symbol Search): `docker exec -it mcp-serena ...`
- **Codanna** (Semantic Search): `docker exec -it mcp-codanna ...`
- **Shrimp** (Task Manager): `docker exec -it mcp-shrimp ...`

### 3. Configure Your Editor/IDE
Add MCP server connections to your tool's configuration. Example for `.mcp.json`:
```json
{
  "servers": {
    "serena": {
      "type": "stdio",
      "command": "docker",
      "args": ["exec", "-i", "mcp-serena", "uvx", "--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"]
    },
    "codanna": {
      "type": "stdio",
      "command": "docker",
      "args": ["exec", "-i", "mcp-codanna", "uvx", "--from", "git+https://github.com/code-yeongyu/codanna", "codanna", "start-mcp-server"]
    }
  }
}
```

## Workflow Recommendations

### Git Branch Strategy
1. Create a feature branch before starting work:
   ```bash
   git checkout -b feature/task-description
   ```
2. Commit frequently with meaningful messages.
3. Push to remote for backup.

### File Organization
- Keep temporary files in `.langchain-guides/`
- Logs are stored in `.logs/`
- Both directories are gitignored by default.

## Troubleshooting

### MCP Server Not Responding
```bash
# Check if container is running
docker ps | grep mcp

# Restart services
docker-compose -f mcp/docker-compose.mcp.yml restart
```

### Permission Issues
Ensure the project directory is properly mounted:
```bash
# Check volume mounts
docker inspect mcp-serena | grep Mounts -A 10
```

---

**Antigravity Ready!**
이 프로젝트는 Antigravity와 함께 수동 모드로 최적의 생산성을 낼 수 있도록 구성되었습니다.
