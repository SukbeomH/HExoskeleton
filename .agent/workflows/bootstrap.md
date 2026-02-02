---
description: Complete initial project setup — deps, MCP, indexing, analysis, memory
---

# /bootstrap Workflow

<role>
You are a GSD bootstrap orchestrator. You set up a freshly cloned boilerplate project from zero to fully operational in one pass.

**Core responsibilities:**
- Verify system prerequisites
- Detect language, package manager, test runner (Detect)
- Show detection results and get user confirmation (Ask-Confirm)
- Generate project-config.yaml and install dependencies
- Initialize Qlty CLI if available
- Connect MCP servers
- Index the codebase
- Analyze and document architecture
- Generate CLAUDE.md dynamically
- Store initial memory state
- Report final status
</role>

<objective>
Perform complete first-time project setup: system dependency verification, Python environment, MCP server connection, code indexing, codebase analysis, and memory initialization.

This is the first command to run after cloning the boilerplate into a new project. It validates everything needed for the GSD workflow and AI-assisted development.

**Creates/Verifies:**
- `.gsd/project-config.yaml` — Project configuration (language, tools, qlty)
- `.qlty/qlty.toml` — Qlty CLI configuration (if qlty installed)
- `CLAUDE.md` — Dynamically generated from project-config.yaml
- Dependencies directory (`.venv/`, `node_modules/`, etc.)
- `.env` — Environment configuration
- `.patch-workspace/` — Patched Claude Code CLI (optional, ~50% token reduction)
- `.code-graph-rag/` — Code index data
- `.gsd/ARCHITECTURE.md` — System architecture documentation
- `.gsd/STACK.md` — Technology stack documentation
- Bootstrap memory record in mcp-memory-service

**After this command:** Run `/new-project` or `/plan 1` to begin development.
</objective>

<context>
**No arguments required.** Operates on current project directory.

**Prerequisites:**
- Boilerplate cloned or initialized
- `.mcp.json` exists in project root
- Project manifest file exists (`pyproject.toml`, `package.json`, `go.mod`, or `Cargo.toml`)

**Related make target:** `make setup` (simpler alternative without MCP/memory integration)
</context>

<process>

## Step 0: Idempotency Check

Before running any setup, check if bootstrap has already been completed:

```
search_memories(tags: ["bootstrap", "init"])
```

Also check for existing artifacts:

```bash
HAS_VENV=$(test -d .venv && echo "yes" || echo "no")
HAS_ENV=$(test -f .env && echo "yes" || echo "no")
HAS_INDEX=$(test -d .code-graph-rag && echo "yes" || echo "no")
HAS_ARCH=$(test -f .gsd/ARCHITECTURE.md && echo "yes" || echo "no")
HAS_PATCH=$(test -d .patch-workspace && echo "yes" || echo "no")
```

**If bootstrap memory exists AND all artifacts present:**

```
================================================================
 BOOTSTRAP: Already completed
================================================================

Previous bootstrap found. All artifacts exist.

Options:
  A) Re-bootstrap — Run full setup again (overwrites existing)
  B) Status check — Show current environment status only
  C) Cancel — Exit without changes

Select [A/B/C]:
================================================================
```

Wait for user selection:
- **A) Re-bootstrap:** Continue to Step 1.
- **B) Status check:** Jump to Step 9 (status report only).
- **C) Cancel:** Exit.

**If no bootstrap memory OR missing artifacts:** Continue to Step 1.

---

## Step 1: System Prerequisites

Display banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD >>> BOOTSTRAP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Run system prerequisite checks:

```bash
bash scripts/bootstrap.sh
```

**If exit 1 (required check failed):**
```
BOOTSTRAP STOPPED: Missing required system dependencies.
Install the tools listed above, then re-run /bootstrap.
```
Exit workflow.

**If exit 0:** Record tool versions. Continue.

---

## Step 2: Language Detection + Qlty Init + User Confirm

### 2a. Detect Language

Run language detection using the detect-language helper:

```bash
source scripts/detect-language.sh
DETECTED_LANG=$(detect_language .)
DETECTED_PKG=$(detect_pkg_manager .)
DETECTED_TEST=$(detect_test_runner .)
DETECTED_TEST_CMD=$(get_test_cmd "$DETECTED_TEST" "$DETECTED_PKG")
echo "Language: $DETECTED_LANG | Pkg Manager: $DETECTED_PKG | Test Runner: $DETECTED_TEST"
```

### 2b. Qlty Init (optional)

If `qlty` is installed and `.qlty/qlty.toml` does not exist:

```bash
if command -v qlty &>/dev/null && [[ ! -f .qlty/qlty.toml ]]; then
    qlty init
fi
```

If `.qlty/qlty.toml` already exists: Record PASS (already initialized). Continue.
If `qlty` not installed: Record SKIP. Continue with fallback tools.

### 2c. Show Detection Results to User (AskUserQuestion)

Present detected results to the user for confirmation using `AskUserQuestion`:

**Question 1: Language Confirmation**
```
"이 프로젝트는 [{DETECTED_LANG}]로 감지됩니다. 맞습니까?"
Options:
  - "맞음" — 감지된 언어를 사용
  - "Python" — Python으로 설정
  - "Node.js" — Node.js로 설정
  - "Go / Rust / 기타" — 다른 언어로 설정
```

**Question 2: Tool Confirmation**
```
"감지된 도구 설정:
 - Package Manager: {DETECTED_PKG}
 - Test Runner: {DETECTED_TEST}
 - Qlty: {installed/not installed}

이 설정을 사용하시겠습니까?"
Options:
  - "그대로 사용" — 감지된 설정 적용
  - "일부 수정" — 사용자가 수정할 항목 지정
```

Wait for user response. Apply confirmed or modified values.

### 2d. Generate project-config.yaml

After user confirmation, generate `.gsd/project-config.yaml`:

```bash
source scripts/detect-language.sh

# Use confirmed values (from AskUserQuestion response)
LANG="${CONFIRMED_LANG}"           # e.g., python, node, go, rust
PKG="${CONFIRMED_PKG}"             # e.g., uv, npm, yarn
TEST_RUNNER="${CONFIRMED_TEST}"    # e.g., pytest, jest, vitest
TEST_CMD="${CONFIRMED_TEST_CMD}"   # e.g., "uv run pytest tests/"
HAS_QLTY=$(command -v qlty &>/dev/null && echo "true" || echo "false")

cat > .gsd/project-config.yaml << EOFYAML
project:
  name: "$(basename "$(pwd)")"
  primary_language: "${LANG}"

language:
  name: "${LANG}"
  variant: null
  version: null

package_manager:
  name: "${PKG}"
  lockfile: "$(get_lockfile "${PKG}")"
  install: "$(get_install_cmd "${PKG}")"
  add: "$(get_add_cmd "${PKG}")"
  run: "$(get_run_cmd "${PKG}")"

qlty:
  enabled: ${HAS_QLTY}
  config_file: ".qlty/qlty.toml"
  check_command: "qlty check"
  fix_command: "qlty check --fix"
  format_command: "qlty fmt"

tools:
  test_runner:
    name: "${TEST_RUNNER}"
    config_file: null
    command: "${TEST_CMD}"

environment:
  dependency_dir: "$(get_dependency_dir "${LANG}")"
  dependency_file: "$(get_dependency_file "${LANG}")"
  ignore_dirs:
    - "$(get_dependency_dir "${LANG}")"
    - ".git"
    - ".qlty"
  file_extensions:
    - "$(get_file_extensions "${LANG}")"

_meta:
  generated_by: bootstrap
  generated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  user_confirmed: true
  qlty_version: "$(qlty --version 2>/dev/null || echo 'not installed')"
EOFYAML
```

Record: PASS (project-config.yaml generated) or FAIL.

---

## Step 3: Dependencies

Install dependencies based on `project-config.yaml`:

```bash
source scripts/load-config.sh
eval "$PKG_INSTALL_CMD"
```

Verify:
```bash
# Check language-specific dependency directory
if [[ -n "$DEPENDENCY_DIR" ]]; then
    test -d "$DEPENDENCY_DIR" && echo "PASS: $DEPENDENCY_DIR ready" || echo "FAIL: $DEPENDENCY_DIR not created"
else
    echo "PASS: no dependency directory expected"
fi
```

**If fails:** STOP. Display:
```
BOOTSTRAP STOPPED: Dependency installation failed.
Check ${DEPENDENCY_FILE} and language runtime.
```

**If passes:** Continue.

---

## Step 4: Environment Setup

```bash
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
else
    echo ".env already exists — skipping"
fi
```

---

## Step 5: Prompt Patching (Optional)

Reduce Claude Code system prompt token usage by ~50%. See `.gsd/GUIDE-system-prompt-patch.md`.

**Check prerequisites:**

```bash
CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
test -d "claude-code-tips/system-prompt/${CLAUDE_VER}"
```

**If `claude` CLI not found OR patch directory missing:** Record SKIP. Continue to Step 5.

**If `.patch-workspace/` already exists:** Record PASS (already patched). Continue.

**If prerequisites available and `.patch-workspace/` does not exist:**

```bash
make patch-prompt
```

Verify:
```bash
test -d .patch-workspace && echo "PASS" || echo "WARN"
```

**If `make patch-prompt` fails:** Record WARN. Continue. Patching can be retried later with `make patch-prompt`.

---

## Step 6: MCP Server Verification

Test each MCP server connection:

### 6a. graph-code
```
get_graph_health()
```
Record: PASS or FAIL.

### 6b. mcp-memory-service
```
memory_stats()
```
Record: PASS or FAIL.

### 6c. context7 (optional)
```
resolve-library-id(libraryName: "langchain")
```
Record: PASS or WARN (failure is acceptable).

**If graph-code FAIL:** Skip Step 7 (indexing).
**If mcp-memory-service FAIL:** Skip Step 9 (memory store).

---

## Step 7: Code Index

**Skip if:** graph-code failed in Step 6.

```
index(".")
```

Verify results:
```
get_graph_stats()
```

Record entity count and file count.

**If fails:** Record FAIL. Continue. Suggest `make index` or `/map` for retry.

---

## Step 8: Codebase Analysis

Delegate to the `codebase-mapper` skill:
- Generate `.gsd/ARCHITECTURE.md`
- Generate `.gsd/STACK.md`

**If fails:** Record FAIL. Continue.

---

## Step 9: CLAUDE.md Dynamic Generation

Generate `CLAUDE.md` based on `project-config.yaml`:

```bash
bash scripts/generate-claude-md.sh
```

**If fails:** Record WARN. Continue. CLAUDE.md can be manually created.

---

## Step 10: Initial Memory

**Skip if:** mcp-memory-service failed in Step 6.

```
memory_store(
  content: "## Project Bootstrap\n\nBootstrap completed. System prerequisites verified. MCP servers connected. Codebase indexed. Documentation generated.",
  metadata: {
    tags: "bootstrap,init,setup",
    type: "bootstrap"
  }
)
```

**If fails:** Record WARN. Continue.

---

## Step 11: Status Report

Output structured report:

```
================================================================
 BOOTSTRAP STATUS REPORT
================================================================
System Prerequisites:  {PASS|FAIL} ({tool versions})
Language Detection:    {PASS|FAIL} ({language} / {pkg_manager} / {test_runner})
Qlty Init:             {PASS|SKIP} ({plugins count} plugins)
User Confirmation:     {PASS} (project-config.yaml generated)
Dependencies:          {PASS|FAIL} ({pkg_install_cmd} completed)
Environment:           {PASS|FAIL} (.env configured)
Prompt Patch:          {PASS|WARN|SKIP} (.patch-workspace ready)
MCP Servers:           graph-code {PASS|FAIL} / memory {PASS|FAIL} / context7 {PASS|WARN}
Code Index:            {PASS|FAIL|SKIP} ({N} entities, {M} files)
Documentation:         {PASS|FAIL} (ARCHITECTURE.md, STACK.md)
CLAUDE.md:             {PASS|WARN} (dynamically generated)
Memory:                {PASS|WARN|SKIP} (bootstrap record stored)
================================================================
 RESULT: READY / NEEDS ATTENTION
================================================================
```

**READY:** All critical steps passed (WARN/SKIP acceptable).
**NEEDS ATTENTION:** Any required step FAIL.

</process>

<offer_next>

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD >>> BOOTSTRAP COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

───────────────────────────────────────────────────────

 NEXT

/new-project — Initialize a new GSD project
/plan 1      — Create Phase 1 execution plans
/map         — Re-analyze codebase architecture

───────────────────────────────────────────────────────
```

</offer_next>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/new-project` | Run after bootstrap to initialize GSD project |
| `/map` | Re-run codebase analysis if bootstrap mapping failed |
| `/plan` | Start planning after project is bootstrapped |

### Skills
| Skill | Purpose |
|-------|---------|
| `codebase-mapper` | Delegated to in Step 7 for architecture analysis |
| `arch-review` | Uses indexed codebase from bootstrap for validation |
| `executor` | Uses MCP connections verified by bootstrap |

### Make Targets
| Target | Relationship |
|--------|--------------|
| `make setup` | Simpler alternative (no MCP verification, no memory) |
| `make check-deps` | Subset of Step 1 (system prerequisites only) |
| `make patch-prompt` | Subset of Step 4 (prompt patching only) |
| `make index` | Subset of Step 6 (code indexing only) |
| `make status` | Quick tool status check |
</related>
