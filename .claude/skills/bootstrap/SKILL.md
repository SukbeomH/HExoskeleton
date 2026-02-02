---
name: bootstrap
description: Complete initial project setup -- deps verification, Qlty integration, multi-language detection, MCP connection, indexing, codebase analysis, and memory initialization
version: 2.0.0
allowed-tools:
  - memory_store
  - memory_search
  - memory_stats
  - index
  - get_graph_health
  - get_graph_stats
  - resolve-library-id
trigger: "First time running the boilerplate on a new project, or after cloning"
---

# Skill: Bootstrap

> **Goal**: Perform complete initial project setup in a single pass — from system dependency verification through Qlty integration, multi-language detection, MCP server connection, code indexing, codebase analysis, and memory initialization.
> **Scope**: Combines system checks, Qlty CLI setup, language/tool detection, environment setup, MCP tool integration, and documentation generation.

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
- `pipx` must be installed (for mcp-memory-service)
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

### Step 3.5: Qlty CLI Check

Check if Qlty CLI is installed:

```bash
command -v qlty &>/dev/null && qlty --version
```

**If not installed:** Ask the user whether to install Qlty CLI:
```
"Qlty CLI가 설치되어 있지 않습니다. 설치하시겠습니까?
Qlty는 70+ 린터/포맷터를 지원하는 통합 코드 품질 도구입니다."
Options: [설치] [건너뛰기]
```

If user chooses install:
```bash
curl https://qlty.sh | sh
```

**If user skips or install fails:** Mark WARN. Continue without Qlty (Python fallback 유지).

---

### Step 3.6: Qlty Init

If Qlty CLI is available, initialize the project:

```bash
qlty init
```

This creates `.qlty/qlty.toml` with auto-detected linters and formatters.

Verify:
```bash
test -f .qlty/qlty.toml && echo "PASS" || echo "FAIL"
```

**If `qlty init` fails:** Mark WARN. Continue without Qlty integration.

---

### Step 3.7: Language Detection

Detect the project's primary language using `scripts/detect-language.sh`:

```bash
source scripts/detect-language.sh
LANG=$(detect_language .)
PKG=$(detect_pkg_manager .)
TEST=$(detect_test_runner .)
```

Ask user to confirm:
```
"이 프로젝트는 [{LANG}]로 감지됩니다. 맞습니까?"
Options: [맞음] [다른 언어]
```

---

### Step 3.8: Package Manager Detection

Show detected package manager and confirm:
```
"패키지 관리자: [{PKG}] (lockfile: {lockfile})
테스트 러너: [{TEST}]

이 설정을 사용하시겠습니까?"
Options: [그대로 사용] [일부 수정] [직접 설정]
```

---

### Step 3.9: Qlty Detected Tools

If Qlty is available, show detected plugins:
```bash
qlty plugins list 2>/dev/null
```

Display detected linters/formatters to user for confirmation.

---

### Step 3.10: User Confirmation

Collect all detected settings and present to user for final confirmation before generating config.

---

### Step 3.11: Generate project-config.yaml

Generate `.gsd/project-config.yaml` based on detection results and user confirmation:

- Use template from `.gsd/templates/project-config.yaml`
- Fill in detected values (language, package manager, test runner, Qlty settings)
- Set `_meta.generated_at` to current timestamp
- Set `_meta.user_confirmed` to true/false

Verify:
```bash
test -f .gsd/project-config.yaml && echo "PASS" || echo "FAIL"
```

**If Qlty was not installed:** Set `qlty.enabled: false` in the config.

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
| memory | `memory_stats()` | YES |
| context7 | `resolve-library-id(libraryName: "langchain")` | NO (WARN only) |

**If graph-code fails:** Mark FAIL. Skip Step 6 (indexing). Continue to Step 7.
**If memory fails:** Mark FAIL. Skip Step 9 (memory store). Continue.
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
memory_store(
  content: "## Project Bootstrap\n\nBootstrap completed. System prerequisites verified. MCP servers connected. Codebase indexed ({N} entities, {M} files). Documentation generated.",
  metadata: {
    tags: "bootstrap,init,setup",
    type: "bootstrap"
  }
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
Language Environment:  {PASS|FAIL} ({language} detected, deps synced)
Environment:           {PASS|FAIL} (.env configured)
Qlty CLI:              {PASS|WARN|SKIP} ({version or reason})
Project Config:        {PASS|FAIL} (project-config.yaml generated)
Context Structure:     {PASS|FAIL} (reports/, research/, archive/, PATTERNS.md)
Prompt Patch:          {PASS|WARN|SKIP} (.patch-workspace ready)
MCP Servers:           graph-code {PASS|FAIL} / memory {PASS|FAIL} / context7 {PASS|WARN}
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

- `scripts/bootstrap.sh`: System dependency verification script (Node.js, npm, uv, pipx, Python, memory, npx)
- `scripts/detect-language.sh`: Language, package manager, and test runner detection functions
- `scripts/load-config.sh`: project-config.yaml loader (exports environment variables)
