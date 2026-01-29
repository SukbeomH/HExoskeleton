---
name: bootstrap
description: Complete initial project setup -- deps verification, MCP connection, indexing, codebase analysis, and memory initialization
version: 1.1.0
allowed-tools:
  - store_memory
  - search_memories
  - get_memory_statistics
  - index
  - get_graph_health
  - get_graph_stats
  - resolve-library-id
trigger: "First time running the boilerplate on a new project, or after cloning"
---

# Skill: Bootstrap

> **Goal**: Perform complete initial project setup in a single pass — from system dependency verification through MCP server connection, code indexing, codebase analysis, and memory initialization.
> **Scope**: Combines system checks, environment setup, MCP tool integration, and documentation generation.

<role>
You are a bootstrap orchestrator. You combine the rigor of arch-review (validation-first) with the execution capability of executor (task completion). Your job is to take a freshly cloned boilerplate and make it fully operational.

**Core responsibilities:**
- Verify all system prerequisites before proceeding
- Set up Python environment and dependencies
- Connect and verify all MCP servers
- Index the codebase for graph-based analysis
- Generate architecture documentation
- Store bootstrap state in memory graph
- Report final status with actionable next steps
</role>

---

## Prerequisites

- This skill assumes a fresh clone or first-time setup
- Node.js >= 18 must be installed
- `uv` must be installed (Python package manager)
- `pipx` must be installed (for memorygraph)
- `.mcp.json` must exist in project root

---

## Procedure

### Step 1: System Prerequisites Check

Run the system dependency verification script:

```bash
bash scripts/bootstrap.sh
```

**If exit code 1:** STOP. Display the failing checks and provide installation instructions for each missing tool. Do not proceed until all required checks pass.

**If exit code 0:** Record tool versions and continue.

---

### Step 2: Python Dependencies

Install/sync Python dependencies:

```bash
uv sync
```

Verify the virtual environment was created:

```bash
test -d .venv && echo "PASS" || echo "FAIL"
```

**If `uv sync` fails:** STOP. Check `pyproject.toml` and Python version compatibility.

---

### Step 3: Environment Setup

Copy `.env.example` to `.env` if `.env` does not already exist:

```bash
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
else
    echo ".env already exists"
fi
```

---

### Step 4: Prompt Patching (Optional)

Apply system prompt patch to reduce token usage (~50% reduction). See `.gsd/GUIDE-system-prompt-patch.md` for details.

**Prerequisites check:**

```bash
command -v claude && claude --version
CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
test -d "claude-code-tips/system-prompt/${CLAUDE_VER}"
```

**If `claude` CLI not found OR patch directory missing:** Mark SKIP. Continue to Step 5.

**If prerequisites available and `.patch-workspace/` does not exist:**

```bash
make patch-prompt
```

Verify patching succeeded:

```bash
test -d .patch-workspace && echo "PASS" || echo "FAIL"
```

**If `make patch-prompt` fails:** Mark WARN. Continue to Step 5. Patching is an optimization, not a requirement.

**If `.patch-workspace/` already exists:** Mark PASS (already patched). Continue.

---

### Step 5: Context Structure Initialization

The bootstrap script automatically creates the context management structure:

```
.gsd/
├── reports/           # Analysis reports (REPORT-*.md)
├── research/          # Research documents (RESEARCH-*.md)
├── archive/           # Monthly archives
├── PATTERNS.md        # Core patterns (2KB limit)
└── context-config.yaml # Cleanup rules
```

**Verification:**
```bash
test -d .gsd/reports && test -d .gsd/research && test -d .gsd/archive && echo "PASS" || echo "FAIL"
test -f .gsd/PATTERNS.md && echo "PASS" || echo "FAIL"
```

**If folders missing:** bootstrap.sh creates them automatically.
**If PATTERNS.md missing:** Copied from templates/patterns.md.

---

### Step 6: MCP Server Verification

Test connectivity to each configured MCP server:

| Server | Test | Required |
|--------|------|----------|
| graph-code | `get_graph_health()` | YES |
| memorygraph | `get_memory_statistics()` | YES |
| context7 | `resolve-library-id(libraryName: "langchain")` | NO (WARN only) |

**If graph-code fails:** Mark FAIL. Skip Step 6 (indexing). Continue to Step 7.
**If memorygraph fails:** Mark FAIL. Skip Step 8 (memory store). Continue.
**If context7 fails:** Mark WARN. Continue normally.

---

### Step 7: Code Index

Index the codebase using code-graph-rag:

```
index(".")
```

Verify indexing results:

```
get_graph_stats()
```

Record the entity count and file count from the stats response.

**If indexing fails:** Mark FAIL. Continue to Step 8. Suggest running `/map` later to retry.

---

### Step 8: Codebase Analysis

Delegate to the `codebase-mapper` skill to analyze the project and generate documentation:

- `.gsd/ARCHITECTURE.md`
- `.gsd/STACK.md`

**If codebase-mapper fails:** Mark FAIL. Continue to Step 9.

---

### Step 9: Initial Memory

Store the bootstrap record in memory graph:

```
store_memory(
  type: "bootstrap",
  title: "Project Bootstrap",
  content: "Bootstrap completed. System prerequisites verified. MCP servers connected. Codebase indexed ({N} entities, {M} files). Documentation generated.",
  tags: ["bootstrap", "init", "setup"]
)
```

**If memory store fails:** Mark WARN. Continue to Step 10.

---

### Step 10: Status Report

Output the structured bootstrap status report:

```
================================================================
 BOOTSTRAP STATUS REPORT
================================================================
System Prerequisites:  {PASS|FAIL} ({tool versions})
Python Environment:    {PASS|FAIL} (uv synced, .venv ready)
Environment:           {PASS|FAIL} (.env configured)
Context Structure:     {PASS|FAIL} (reports/, research/, archive/, PATTERNS.md)
Prompt Patch:          {PASS|WARN|SKIP} (.patch-workspace ready)
MCP Servers:           graph-code {PASS|FAIL} / memorygraph {PASS|FAIL} / context7 {PASS|WARN}
Code Index:            {PASS|FAIL} ({N} entities, {M} files)
Documentation:         {PASS|FAIL} (ARCHITECTURE.md, STACK.md)
Memory:                {PASS|WARN} (bootstrap record stored)
================================================================
 RESULT: READY / NEEDS ATTENTION
================================================================
Next: /new-project | /plan 1 | /map
================================================================
```

**READY** = All steps PASS (WARN is acceptable).
**NEEDS ATTENTION** = Any step FAIL.

---

## Error Handling

| Error | Action |
|-------|--------|
| System prerequisite missing | STOP at Step 1. Print install commands for each missing tool |
| `uv sync` fails | STOP. Check pyproject.toml and Python version |
| `claude` CLI or patch files missing | SKIP Step 4. Prompt patching is optional |
| `make patch-prompt` fails | WARN the step, continue. Retry manually later |
| MCP server connection fails | FAIL the step, continue to next. If graph-code fails, skip indexing |
| Indexing fails | FAIL the step, continue. Suggest `/map` for retry |
| codebase-mapper fails | FAIL the step, continue |
| Memory store fails | WARN the step, continue |

---

## Scripts

- `scripts/bootstrap.sh`: System dependency verification script (Node.js, npm, uv, pipx, Python, memorygraph, npx)
