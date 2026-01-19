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

2. Verify environment variables:
```bash
cat ../.env.mcp
```

Ensure `CONTEXT7_API_KEY` is set.

3. Build Docker images (first time only):
```bash
docker-compose -f docker-compose.mcp.yml build
```

4. Start all MCP servers:
```bash
docker-compose -f docker-compose.mcp.yml up -d
```

5. Verify servers are running:
```bash
docker-compose -f docker-compose.mcp.yml ps
```

Expected output:
```
NAME                STATUS              PORTS
serena              running
codanna             running             0.0.0.0:8081->8081/tcp
shrimp              running
context7            running             0.0.0.0:8080->8080/tcp
```

## Check Server Logs

6. View logs for all servers:
```bash
docker-compose -f docker-compose.mcp.yml logs -f
```

7. View logs for specific server:
```bash
docker-compose -f docker-compose.mcp.yml logs -f serena
docker-compose -f docker-compose.mcp.yml logs -f codanna
docker-compose -f docker-compose.mcp.yml logs -f shrimp
docker-compose -f docker-compose.mcp.yml logs -f context7
```

## Stop MCP Servers

8. Stop all servers:
```bash
docker-compose -f docker-compose.mcp.yml down
```

9. Stop and remove volumes (clean slate):
```bash
docker-compose -f docker-compose.mcp.yml down -v
```

## Restart Individual Server

10. Restart specific server:
```bash
docker-compose -f docker-compose.mcp.yml restart serena
```

## Rebuild After Changes

11. Rebuild specific server image:
```bash
docker-compose -f docker-compose.mcp.yml build --no-cache serena
docker-compose -f docker-compose.mcp.yml up -d serena
```

## Test MCP Server Connection

12. Test Context7 (HTTP endpoint):
```bash
curl -X POST http://localhost:8080/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

13. Test Codanna (HTTP endpoint):
```bash
curl http://localhost:8081/health
```

## MCP Server Configuration

14. View current MCP configuration:
```bash
cat .agent/mcp_config.json
```

15. Edit MCP configuration (if needed):
```bash
# Edit .agent/mcp_config.json
# Then restart Antigravity to pick up changes
```

## Project-Scoped Setup

When injecting into a new project:

16. Copy MCP configuration to injected project:
```bash
# This is done automatically by the Launcher
# Result: <target-project>/.agent-booster/mcp/docker-compose.mcp.yml
```

17. Each project gets its own MCP server instances:
```bash
cd <target-project>/.agent-booster/mcp
docker-compose -f docker-compose.mcp.yml up -d
```

## Troubleshooting

**Port conflicts:**
```bash
# Check what's using ports 8080, 8081
lsof -i :8080
lsof -i :8081

# Kill conflicting processes
lsof -ti:8080 | xargs kill
lsof -ti:8081 | xargs kill
```

**Docker build failures:**
```bash
# Clean Docker cache
docker system prune -a

# Rebuild from scratch
docker-compose -f docker-compose.mcp.yml build --no-cache
```

**Server not responding:**
```bash
# Check container status
docker-compose -f docker-compose.mcp.yml ps

# Check logs for errors
docker-compose -f docker-compose.mcp.yml logs <service-name>

# Restart the service
docker-compose -f docker-compose.mcp.yml restart <service-name>
```

**Context7 authentication errors:**
- Verify `CONTEXT7_API_KEY` in `.env.mcp`
- Check API key is valid at https://context7.com
- Restart Context7 container after updating key

## Health Check Commands

```bash
# Quick health check for all services
docker-compose -f docker-compose.mcp.yml ps --format json | jq '.[] | {name: .Name, status: .Status}'

# Monitor resource usage
docker stats $(docker-compose -f docker-compose.mcp.yml ps -q)
```
