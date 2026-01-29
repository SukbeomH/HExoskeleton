#!/usr/bin/env bash
#
# Antigravity Build Script
# Converts boilerplate to Google Antigravity IDE format
#
set -euo pipefail

# --- Configuration ---
BOILERPLATE="$(cd "$(dirname "$0")/.." && pwd)"
ANTIGRAVITY="${BOILERPLATE}/antigravity-boilerplate"

echo "=== Antigravity Builder ==="
echo "Source: ${BOILERPLATE}"
echo "Target: ${ANTIGRAVITY}"
echo ""

# --- Phase 1: Directory Structure ---
echo "[Phase 1] Creating directory structure..."
rm -rf "$ANTIGRAVITY"
mkdir -p "$ANTIGRAVITY"/.agent/{skills,workflows,rules}
mkdir -p "$ANTIGRAVITY"/templates/gsd/{templates,examples}
mkdir -p "$ANTIGRAVITY"/scripts

echo "  [+] .agent/skills/"
echo "  [+] .agent/workflows/"
echo "  [+] .agent/rules/"
echo "  [+] templates/gsd/"
echo "  [+] scripts/"

# --- Phase 2: Skills Migration ---
echo ""
echo "[Phase 2] Migrating skills to Antigravity format..."

# Skills are already in compatible format (YAML frontmatter with name/description)
for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$ANTIGRAVITY/.agent/skills/${skill_name}"
    mkdir -p "$target_dir"

    # Copy SKILL.md and any subdirectories (scripts, examples, resources)
    cp -r "$skill_dir"/* "$target_dir/" 2>/dev/null || true

    # Verify description exists in frontmatter (required for Antigravity)
    if [ -f "$target_dir/SKILL.md" ]; then
        if grep -q "^description:" "$target_dir/SKILL.md"; then
            echo "  [+] ${skill_name}"
        else
            echo "  [WARN] ${skill_name} - missing description in frontmatter"
        fi
    fi
done
SKILLS_COUNT=$(ls -d "$ANTIGRAVITY/.agent/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "  [=] Total skills: ${SKILLS_COUNT}"

# --- Phase 3: Workflows ---
echo ""
echo "[Phase 3] Copying workflows..."

# Workflows need description in frontmatter for Antigravity
for workflow in "$BOILERPLATE"/.agent/workflows/*.md; do
    [ -f "$workflow" ] || continue
    filename=$(basename "$workflow")
    target="$ANTIGRAVITY/.agent/workflows/${filename}"

    # Check if workflow has description in frontmatter
    if grep -q "^description:" "$workflow" 2>/dev/null; then
        cp "$workflow" "$target"
        echo "  [+] ${filename}"
    else
        # Add description frontmatter based on filename
        workflow_name="${filename%.md}"
        desc="Workflow for ${workflow_name//-/ }"

        # Check if file has frontmatter
        if head -1 "$workflow" | grep -q "^---"; then
            # Insert description after first ---
            awk 'NR==1{print; print "description: \"'"$desc"'\""; next}1' "$workflow" > "$target"
        else
            # Add new frontmatter
            echo "---" > "$target"
            echo "description: \"${desc}\"" >> "$target"
            echo "---" >> "$target"
            echo "" >> "$target"
            cat "$workflow" >> "$target"
        fi
        echo "  [+] ${filename} (added description)"
    fi
done
WORKFLOWS_COUNT=$(ls "$ANTIGRAVITY/.agent/workflows/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  [=] Total workflows: ${WORKFLOWS_COUNT}"

# --- Phase 4: Rules from CLAUDE.md ---
echo ""
echo "[Phase 4] Creating rules from CLAUDE.md..."

# Extract code style rules
cat > "$ANTIGRAVITY/.agent/rules/code-style.md" << 'RULESEOF'
# Code Style Rules

These rules are always active and govern code generation behavior.

## Python Standards
* Use Python 3.12 exclusively
* Follow PEP 8 with line-length 100
* Maximum McCabe complexity: 10
* Maximum function arguments: 6
* Use TypedDict for state definitions
* Naming exceptions: `*Factory`, `Create*` patterns

## Package Management
* Package manager: uv only
* Never use pip or poetry
* Commands: `uv sync`, `uv add <package>`, `uv run <command>`

## Code Quality
* Run `uv run ruff check . --fix` for linting
* Run `uv run mypy .` for type checking
* Run `uv run pytest tests/` for testing

## Formatting
* Use ruff format for Python files
* Prefer editing existing files over creating new ones
* Keep solutions simple and focused
RULESEOF
echo "  [+] code-style.md"

# Extract safety rules
cat > "$ANTIGRAVITY/.agent/rules/safety.md" << 'SAFETYEOF'
# Safety Rules

These rules prevent dangerous actions and protect sensitive data.

## Never Do
* Read or print `.env` or credential files
* Commit hardcoded secrets or API keys
* Run destructive git commands without explicit user request
* Skip failing tests to "fix later"
* Print unconditional success messages without verification
* Assume API signatures without verification

## Always Do
* Use `analyze_code_impact` before refactoring or deleting code
* Read `.gsd/SPEC.md` before implementation
* Verify empirically with command execution results
* Create atomic commits per task

## Ask First
* Adding external dependencies (`uv add`)
* Deleting files outside task scope
* Changing public API signatures or database schema
* Architectural decisions affecting 3+ modules

## Terminal Safety
* Review commands before execution in review mode
* Use allow/deny lists for terminal auto-execution
* Never run `rm -rf` on directories without explicit paths
SAFETYEOF
echo "  [+] safety.md"

# Extract workflow rules
cat > "$ANTIGRAVITY/.agent/rules/gsd-workflow.md" << 'GSDEOF'
# GSD Workflow Rules

Rules for the Get Shit Done methodology.

## Validation Philosophy
* Empirical evidence only - "it seems to work" is not evidence
* Collect all failures before reporting (don't stop at first)
* Mock only external APIs/network, prefer real objects
* 3 consecutive failures = change approach

## GSD Cycle
1. SPEC.md (Planning Lock) - Project specification
2. PLAN.md - Implementation plans with atomic tasks
3. EXECUTE - Execute with atomic commits
4. VERIFY - Verify with empirical evidence

## MCP Tools Priority
* Use code-graph-rag tools (query, analyze_code_impact) before reading files directly
* Use memorygraph for persistent agent memory
* Use context7 for library documentation lookup

## Commit Protocol
* Atomic commits per completed task
* Conventional commit format with emoji
* Always include Co-Authored-By header
GSDEOF
echo "  [+] gsd-workflow.md"

# --- Phase 5: MCP Configuration ---
echo ""
echo "[Phase 5] Creating MCP configuration..."

# Transform MCP config for Antigravity
# Antigravity uses mcp-settings.json (can be copied to ~/.gemini/antigravity/)
python3 - "$BOILERPLATE" "$ANTIGRAVITY" << 'PYEOF'
import json
import sys

boilerplate = sys.argv[1]
antigravity = sys.argv[2]

with open(f"{boilerplate}/.mcp.json", 'r') as f:
    mcp = json.load(f)

# Transform for Antigravity
# - Keep structure but adjust paths
if 'mcpServers' in mcp:
    servers = mcp['mcpServers']

    # graph-code: use current directory as default
    if 'graph-code' in servers:
        args = servers['graph-code'].get('args', [])
        servers['graph-code']['args'] = [
            '.' if arg == '.' else arg
            for arg in args
        ]

    # context7: keep if present (user needs API key)
    # memorygraph: keep as is

# Remove non-standard fields
mcp.pop('enable_tool_search', None)

# Write config (Antigravity standard name)
output_path = f"{antigravity}/mcp-settings.json"
with open(output_path, 'w') as f:
    json.dump(mcp, f, indent=2)

print(f"  [+] mcp-settings.json")
PYEOF

# --- Phase 6: GSD Templates ---
echo ""
echo "[Phase 6] Copying GSD templates..."

# Templates
cp "$BOILERPLATE"/.gsd/templates/*.md "$ANTIGRAVITY/templates/gsd/templates/" 2>/dev/null || true
cp "$BOILERPLATE"/.gsd/templates/*.yaml "$ANTIGRAVITY/templates/gsd/templates/" 2>/dev/null || true
TEMPLATES_COUNT=$(find "$ANTIGRAVITY/templates/gsd/templates" -type f | wc -l | tr -d ' ')
echo "  [+] ${TEMPLATES_COUNT} templates"

# Examples
cp "$BOILERPLATE"/.gsd/examples/*.md "$ANTIGRAVITY/templates/gsd/examples/" 2>/dev/null || true
EXAMPLES_COUNT=$(find "$ANTIGRAVITY/templates/gsd/examples" -type f | wc -l | tr -d ' ')
echo "  [+] ${EXAMPLES_COUNT} examples"

# Working document shells
for doc in SPEC DECISIONS JOURNAL ROADMAP PATTERNS STATE TODO STACK CHANGELOG; do
    doc_lower=$(echo "$doc" | tr '[:upper:]' '[:lower:]')
    cat > "$ANTIGRAVITY/templates/gsd/${doc}.md" << EOF
# ${doc}

<!-- Initialize with /init workflow -->
<!-- See templates/${doc_lower}.md for full template -->
EOF
done
echo "  [+] 9 working document shells"

# --- Phase 7: Utility Scripts ---
echo ""
echo "[Phase 7] Creating utility scripts..."

# scaffold-gsd.sh
cat > "$ANTIGRAVITY/scripts/scaffold-gsd.sh" << 'SCAFFOLDEOF'
#!/bin/zsh
#
# scaffold-gsd.sh - Initialize GSD document structure
#
setopt ERR_EXIT
setopt NO_UNSET

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/gsd"
TARGET="${1:-.gsd}"

echo "Scaffolding GSD documents to ${TARGET}..."

mkdir -p "$TARGET"/{templates,examples,archive,reports,research}

# Copy working documents
for f in "$TEMPLATE_DIR"/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] $(basename "$f")"
    else
        cp "$f" "$dst"
        echo "[CREATED] $(basename "$f")"
    fi
done

# Copy yaml configs
for f in "$TEMPLATE_DIR"/templates/*.yaml; do
    [ -f "$f" ] || continue
    dst="$TARGET/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] $(basename "$f")"
    else
        cp "$f" "$dst"
        echo "[CREATED] $(basename "$f")"
    fi
done

# Copy templates
for f in "$TEMPLATE_DIR"/templates/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/templates/$(basename "$f")"
    [ -f "$dst" ] && continue
    cp "$f" "$dst"
    echo "[CREATED] templates/$(basename "$f")"
done

# Copy examples
for f in "$TEMPLATE_DIR"/examples/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/examples/$(basename "$f")"
    [ -f "$dst" ] && continue
    cp "$f" "$dst"
    echo "[CREATED] examples/$(basename "$f")"
done

echo ""
echo "GSD scaffolding complete!"
SCAFFOLDEOF
chmod +x "$ANTIGRAVITY/scripts/scaffold-gsd.sh"
echo "  [+] scaffold-gsd.sh"

# Copy hook scripts (may be useful)
for script in "$BOILERPLATE"/.claude/hooks/*.py; do
    [ -f "$script" ] || continue
    cp "$script" "$ANTIGRAVITY/scripts/"
    chmod +x "$ANTIGRAVITY/scripts/$(basename "$script")"
done
echo "  [+] Copied Python hook scripts"

# --- Phase 8: README ---
echo ""
echo "[Phase 8] Creating README..."

cat > "$ANTIGRAVITY/README.md" << 'READMEEOF'
# Antigravity Boilerplate

AI agent development boilerplate for **Google Antigravity IDE**.

## Quick Start

1. **Open in Antigravity**
   ```bash
   # Open this directory as workspace in Antigravity
   antigravity .
   ```

2. **Configure MCP Servers**
   - Go to Agent panel "..." → MCP Servers → Manage MCP Servers → View raw config
   - Copy contents from `mcp-settings.json` to your config
   - Or copy to global config: `~/.gemini/antigravity/mcp-settings.json`

3. **Initialize GSD Documents**
   ```bash
   zsh scripts/scaffold-gsd.sh
   ```

## Directory Structure

```
.agent/
├── skills/          # 15 AI skills (SKILL.md format)
│   ├── planner/     # Planning skill
│   ├── executor/    # Execution skill
│   └── ...
├── workflows/       # 30 workflow commands (// turbo supported)
│   ├── plan.md      # /plan command
│   ├── execute.md   # /execute command
│   └── ...
└── rules/           # Always-on passive rules
    ├── code-style.md
    ├── safety.md
    └── gsd-workflow.md

templates/gsd/       # GSD document templates
scripts/             # Utility scripts
mcp-settings.json    # MCP server configuration
```

## Skills

Skills are specialized agent capabilities in `.agent/skills/[name]/SKILL.md`.

| Skill | Description |
|-------|-------------|
| `planner` | Creates executable phase plans |
| `executor` | Executes plans with atomic commits |
| `verifier` | Verifies work with empirical evidence |
| `commit` | Conventional emoji commits |
| `create-pr` | Pull request creation |
| `pr-review` | Multi-persona code review |
| `clean` | Code quality tools (ruff, mypy) |
| `debugger` | Systematic debugging |
| `impact-analysis` | Change impact analysis |
| `arch-review` | Architecture review |
| `codebase-mapper` | Codebase structure mapping |
| `plan-checker` | Plan validation |
| `context-health-monitor` | Context complexity monitoring |
| `bootstrap` | Project initialization |
| `empirical-validation` | Proof-based validation |

## Workflows

Workflows are standardized recipes in `.agent/workflows/*.md`. Trigger via `/` commands or natural language.

### Turbo Mode

Add `// turbo` comment to auto-execute commands:
```markdown
1. Run tests
// turbo
2. `npm run test`
```

Or `// turbo-all` at the top for all commands.

### Key Workflows

| Command | Description |
|---------|-------------|
| `/plan` | Create implementation plan |
| `/execute` | Execute planned work |
| `/verify` | Verify completed work |
| `/debug` | Systematic debugging |
| `/map` | Map codebase structure |
| `/new-project` | Initialize new project |
| `/help` | List all commands |

## Rules

Rules in `.agent/rules/*.md` are always-on passive guidelines that govern agent behavior.

| Rule | Purpose |
|------|---------|
| `code-style.md` | Python standards, formatting |
| `safety.md` | Dangerous action prevention |
| `gsd-workflow.md` | GSD methodology rules |

## MCP Servers

Pre-configured in `mcp-settings.json`:

| Server | Purpose |
|--------|---------|
| `graph-code` | AST-based code analysis (19 tools) |
| `memorygraph` | Persistent agent memory (12 tools) |
| `context7` | Library documentation lookup |

### Setup Options

**Option 1: Project-level** (recommended)
- Copy `mcp-settings.json` content via Agent panel → MCP Servers

**Option 2: Global**
```bash
mkdir -p ~/.gemini/antigravity
cp mcp-settings.json ~/.gemini/antigravity/
```

### Environment Variables

```bash
# Required for context7
export CONTEXT7_API_KEY="your-api-key"
```

## Agent Settings

Recommended Antigravity settings:

| Setting | Value | Reason |
|---------|-------|--------|
| **Agent Mode** | Planning | Better for complex tasks |
| **Artifact Review** | Request Review | Review plans before execution |
| **Terminal Policy** | Always Proceed | With safety rules active |

## GSD Methodology

Get Shit Done workflow:

1. **SPEC.md** - Define project specification
2. **PLAN.md** - Create implementation plans
3. **EXECUTE** - Execute with atomic commits
4. **VERIFY** - Verify with empirical evidence

## Migration from Claude Code

| Claude Code | Antigravity |
|-------------|-------------|
| `CLAUDE.md` | `.agent/rules/*.md` |
| `.claude/skills/` | `.agent/skills/` |
| Claude Hooks | `.agent/workflows/` (use `// turbo`) |
| `.mcp.json` | `mcp-settings.json` |

## License

MIT
READMEEOF
echo "  [+] README.md"

# --- Phase 9: Verification ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Phase 9] Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

errors=0

# Structure check
echo ""
echo "[Structure]"
for dir in .agent/skills .agent/workflows .agent/rules templates scripts; do
    if [ -d "$ANTIGRAVITY/$dir" ]; then
        echo "  [OK] $dir/"
    else
        echo "  [FAIL] $dir/ missing"
        errors=$((errors + 1))
    fi
done

# Counts
echo ""
echo "[Counts]"
skill_count=$(ls -d "$ANTIGRAVITY/.agent/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
workflow_count=$(ls "$ANTIGRAVITY/.agent/workflows/"*.md 2>/dev/null | wc -l | tr -d ' ')
rules_count=$(ls "$ANTIGRAVITY/.agent/rules/"*.md 2>/dev/null | wc -l | tr -d ' ')

echo "  Skills:    ${skill_count} (expected: 15)"
[ "$skill_count" -ge 14 ] || echo "    [WARN] Low skill count"

echo "  Workflows: ${workflow_count} (expected: 30)"
[ "$workflow_count" -ge 29 ] || echo "    [WARN] Low workflow count"

echo "  Rules:     ${rules_count} (expected: 3)"
[ "$rules_count" -ge 3 ] || echo "    [WARN] Missing rules"

# Skill description check
echo ""
echo "[Skill Descriptions]"
missing_desc=0
for skill in "$ANTIGRAVITY/.agent/skills"/*/SKILL.md; do
    [ -f "$skill" ] || continue
    if ! grep -q "^description:" "$skill"; then
        echo "  [WARN] $(dirname "$skill" | xargs basename) missing description"
        missing_desc=$((missing_desc + 1))
    fi
done
if [ $missing_desc -eq 0 ]; then
    echo "  [OK] All skills have descriptions"
fi

# JSON validity
echo ""
echo "[JSON Validity]"
if python3 -c "import json; json.load(open('$ANTIGRAVITY/mcp-settings.json'))" 2>/dev/null; then
    echo "  [OK] mcp-settings.json"
else
    echo "  [FAIL] mcp-settings.json invalid"
    errors=$((errors + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $errors -eq 0 ]; then
    echo "BUILD SUCCESSFUL"
    echo ""
    echo "Antigravity workspace created at: $ANTIGRAVITY"
    echo ""
    echo "To use:"
    echo "  1. Open $ANTIGRAVITY in Antigravity IDE"
    echo "  2. Configure MCP servers from mcp-settings.json"
    echo "     - Agent panel → ... → MCP Servers → Manage → View raw config"
    echo "     - Or: cp mcp-settings.json ~/.gemini/antigravity/"
    echo "  3. Run: zsh scripts/scaffold-gsd.sh"
    echo ""
    echo "Or copy to an existing project:"
    echo "  cp -r $ANTIGRAVITY/.agent /path/to/project/"
    echo "  cp $ANTIGRAVITY/mcp-settings.json /path/to/project/"
else
    echo "BUILD COMPLETED WITH $errors ERROR(S)"
    exit 1
fi
