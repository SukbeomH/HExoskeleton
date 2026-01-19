# MCP Configuration Guide for Antigravity

## How MCP Configuration Works

### Project-Scoped Configuration (Recommended) ✅

MCP servers are configured **per-project**, not globally. This ensures:
- ✅ Project isolation (no conflicts between projects)
- ✅ Different server versions per project
- ✅ Project-specific API keys
- ✅ Different `PROJECT_ROOT` paths

**Location**: `/path/to/your/project/.agent/mcp_config.json`

When you open a project in Antigravity, it automatically reads the MCP configuration from that project's `.agent/` directory.

### Example: LLM Boilerplate Pack

**File**: `/Users/sukbeom/Desktop/workspace/boilerplate/.agent/mcp_config.json`

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["serena"],
      "env": {
        "PROJECT_ROOT": "/Users/sukbeom/Desktop/workspace/boilerplate"
      }
    },
    "codanna": {
      "command": "/Users/sukbeom/.cargo/bin/codanna",
      "args": [],
      "env": {
        "PROJECT_ROOT": "/Users/sukbeom/Desktop/workspace/boilerplate"
      }
    }
  }
}
```

**Key Point**: `PROJECT_ROOT` points to **this specific project**.

---

## Global Configuration (Optional)

**Location**: `~/.gemini/antigravity/mcp_config.json`

This file should normally be **empty** or contain only truly global servers that all projects share:

```json
{
  "mcpServers": {}
}
```

**When to use global config**:
- Rarely needed
- Only for servers that ALL projects should have
- Most cases should use project-scoped config

---

## Setting Up for Different Projects

### Project A
**Path**: `/Users/sukbeom/projects/projectA/.agent/mcp_config.json`

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["serena"],
      "env": {
        "PROJECT_ROOT": "/Users/sukbeom/projects/projectA"  ← Project A path
      }
    }
  }
}
```

### Project B
**Path**: `/Users/sukbeom/projects/projectB/.agent/mcp_config.json`

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY_B}",  ← Different API key
        "PROJECT_ROOT": "/Users/sukbeom/projects/projectB"  ← Project B path
      }
    }
  }
}
```

**Result**:
- Project A uses only Serena
- Project B uses only Context7 with its own API key
- No conflicts!

---

## Environment Variables

Use `.env` files in each project:

**Project A**: `/Users/sukbeom/projects/projectA/.env`
```bash
CONTEXT7_API_KEY=key-for-project-a
```

**Project B**: `/Users/sukbeom/projects/projectB/.env`
```bash
CONTEXT7_API_KEY=key-for-project-b
```

---

## Verification

### Check Current Project's MCP Config
```bash
cat .agent/mcp_config.json
```

### Check Global MCP Config (should be empty)
```bash
cat ~/.gemini/antigravity/mcp_config.json
# Expected: {"mcpServers": {}}
```

### In Antigravity
1. Open a project
2. Check MCP server list in sidebar
3. Should see only servers defined in **that project's** `.agent/mcp_config.json`

---

## Best Practices

1. **Always use project-scoped config** (`.agent/mcp_config.json`)
2. **Keep global config empty** unless absolutely necessary
3. **Use environment variables** for API keys (never hardcode)
4. **Set PROJECT_ROOT** to the project's absolute path
5. **Document servers** in project's `.agent/context.md`

---

## Summary

✅ **Correct**: Each project has `.agent/mcp_config.json`
❌ **Wrong**: Hardcoding all project paths in global config

**Antigravity reads**: Project's `.agent/mcp_config.json` when you open that project.
