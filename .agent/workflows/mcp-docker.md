---
description: Manage Docker-based MCP servers
---

# Manage MCP Servers (Docker)

Workflow for managing project-scoped MCP servers using Docker.

> **Note**: MCP servers are **project-scoped**, not globally installed. Each project can have its own MCP server configuration and instances.

## MCP Server Overview

Available servers in this boilerplate:
- **Serena** - Python code analysis (uv-based)
- **Codanna** - Rust code intelligence
- **Shrimp Task Manager** - Node.js task management
- **Context7** - Semantic code search (requires API key)

## Start MCP Servers

// turbo-all
1. Navigate to MCP directory:
```bash
cd /Users/sukbeom/Desktop/workspace/boilerplate/mcp
```

2. Start all MCP servers:
```bash
docker-compose -f docker-compose.mcp.yml up -d
```

3. Verify servers are running:
```bash
docker-compose -f docker-compose.mcp.yml ps
```

## Check Server Logs

4. View logs for all servers:
```bash
docker-compose -f docker-compose.mcp.yml logs -f
```

## Stop MCP Servers

5. Stop all servers:
```bash
docker-compose -f docker-compose.mcp.yml down
```

6. Stop and remove volumes (clean slate):
```bash
docker-compose -f docker-compose.mcp.yml down -v
```

## MCP Server Configuration

7. View current MCP configuration:
```bash
cat .agent/mcp_config.json
```

8. Edit MCP configuration (if needed):
```bash
# Edit .agent/mcp_config.json
# Then restart Antigravity to pick up changes
```

## Troubleshooting

**Port conflicts:**
```bash
# Check what's using ports 8080, 8081
lsof -i :8080
lsof -i :8081
```

**Docker build failures:**
```bash
# Rebuild from scratch
docker-compose -f docker-compose.mcp.yml build --no-cache
```

**Server not responding:**
```bash
# Check logs for errors
docker-compose -f docker-compose.mcp.yml logs <service-name>

# Restart the service
docker-compose -f docker-compose.mcp.yml restart <service-name>
```
