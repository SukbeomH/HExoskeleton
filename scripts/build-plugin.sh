#!/usr/bin/env bash
#
# HExoskeleton Plugin Build Script
# Converts boilerplate to Claude Code plugin format
#
set -euo pipefail

# --- Configuration ---
BOILERPLATE="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="${BOILERPLATE}/hxsk-plugin"

# shellcheck source=build-common.sh
source "$(cd "$(dirname "$0")" && pwd)/build-common.sh"

init_build "HExoskeleton Plugin Builder" "$BOILERPLATE" "$PLUGIN"

# --- Phase 1: Directory Structure + Manifest ---
echo "[Phase 1] Creating directory structure..."
rm -rf "$PLUGIN"
mkdir -p "$PLUGIN"/{.claude-plugin,commands,skills,agents,hooks,scripts}
mkdir -p "$PLUGIN"/templates/hxsk/{templates,examples}
mkdir -p "$PLUGIN"/references/issue-templates

# Get version from release-please manifest or default to 1.0.0
VERSION="1.0.0"
MANIFEST="${BOILERPLATE}/.release-please-manifest.json"
if [ -f "$MANIFEST" ]; then
    VERSION=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST" | head -1 | tr -d '"')
    [ -z "$VERSION" ] && VERSION="1.0.0"
fi

# Create plugin.json manifest (minimal - default directories auto-discovered)
cat > "$PLUGIN/.claude-plugin/plugin.json" << EOF
{
  "name": "hxsk",
  "version": "${VERSION}",
  "description": "HExoskeleton - AI agent development methodology with code-graph-rag and memory-graph integration"
}
EOF
echo "  [+] plugin.json created (version: ${VERSION})"

# --- Phase 2: Commands (Workflows) ---
echo ""
echo "[Phase 2] Copying commands (workflows)..."
COMMANDS_COUNT=0
if [ -d "$BOILERPLATE/.agent/workflows" ]; then
    cp "$BOILERPLATE"/.agent/workflows/*.md "$PLUGIN/commands/" 2>/dev/null || true
    COMMANDS_COUNT=$(ls "$PLUGIN/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  [+] Copied ${COMMANDS_COUNT} workflow commands"
else
    echo "  [SKIP] .agent/workflows/ not found — generating from skills"
    # Generate command stubs from skills (each skill becomes a /hxsk:command)
    for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
        skill_name=$(basename "$skill_dir")
        skill_file="$skill_dir/SKILL.md"
        [ -f "$skill_file" ] || continue

        # Extract description from SKILL.md frontmatter
        desc=$(sed -n '/^---/,/^---/p' "$skill_file" | tr -d '\r' | grep "^description:" | sed 's/description: *//' | tr -d '"')
        [ -z "$desc" ] && desc="Run ${skill_name} skill"

        cat > "$PLUGIN/commands/${skill_name}.md" << CMDEOF
---
description: ${desc}
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /hxsk:${skill_name}

${desc}

Invoke the **${skill_name}** skill. See \`skills/${skill_name}/SKILL.md\` for detailed instructions.
CMDEOF
    done
    COMMANDS_COUNT=$(ls "$PLUGIN/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  [+] Generated ${COMMANDS_COUNT} commands from skills"
fi

# Create init.md (new scaffolding command)
cat > "$PLUGIN/commands/init.md" << 'INITEOF'
---
description: Initialize HExoskeleton document system and compare infrastructure files
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /hxsk:init - HExoskeleton Initialization

Initialize the HExoskeleton document system in the current project.

## What This Command Does

1. **Scaffold HXSK Documents**: Creates `.hxsk/` directory with working documents and templates
2. **Compare Infrastructure**: Shows diff between plugin references and project files
3. **Interactive Setup**: If SPEC.md is empty, guides you through project information collection

## Execution Steps

### Step 1: Scaffold HXSK Directory

Run the scaffolding script to create the HXSK document structure:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-hxsk.sh"
```

This creates:
- `.hxsk/SPEC.md` - Project specification
- `.hxsk/DECISIONS.md` - Architecture decision records
- `.hxsk/JOURNAL.md` - Development journal
- `.hxsk/ROADMAP.md` - Project roadmap
- `.hxsk/templates/` - Document templates (22 files)
- `.hxsk/examples/` - Usage examples (3 files)

### Step 2: Compare Infrastructure Files

Run the infrastructure comparison script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-infra.sh"
```

This compares your project files against HXSK reference configurations:
- `pyproject.toml` - Python project config
- `Makefile` - Build automation
- `.gitignore` - Git ignore patterns
- `CLAUDE.md` - Claude Code instructions
- And more...

### Step 3: Interactive Setup (if needed)

If `.hxsk/SPEC.md` is empty or contains only placeholder content:

1. **Read the template**: Read `.hxsk/templates/spec.md` to understand the document structure
2. **Collect project information** via AskUserQuestion:
   - Project name and brief description (Vision)
   - Primary programming language(s) and frameworks
   - 2-3 key goals
   - Known constraints (technical, business, timeline)
   - Success criteria (measurable outcomes)
3. **Populate SPEC.md**: Write the collected information using the template structure from `templates/spec.md`
   - Keep `Status: DRAFT` until user finalizes
   - Fill in all sections with collected info
   - Remove placeholder text like `{Goal 1}`

**Important**: The working document must follow the template structure, not just contain raw answers.

## After Initialization

Once initialized, you can use HXSK commands:
- `/hxsk:plan` - Create implementation plans
- `/hxsk:execute` - Execute planned work
- `/hxsk:verify` - Verify completed work
- `/hxsk:help` - List all available commands
INITEOF
echo "  [+] Created init.md command"
COMMANDS_COUNT=$((COMMANDS_COUNT + 1))
echo "  [=] Total commands: ${COMMANDS_COUNT}"

# --- Phase 3: Skills ---
echo ""
echo "[Phase 3] Copying skills..."
for d in "$BOILERPLATE"/.claude/skills/*/; do
    skill_name=$(basename "$d")
    cp -r "$d" "$PLUGIN/skills/${skill_name}"
done
SKILLS_COUNT=$(ls -d "$PLUGIN/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] Copied ${SKILLS_COUNT} skills"

# Transform memory script refs in SKILL.md files:
#   scripts/md-*.sh → ${CLAUDE_PLUGIN_ROOT}/scripts/md-*.sh
# Use portable sed: macOS requires -i '', Linux requires -i
_sed_inplace() {
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}
while IFS= read -r f; do
    _sed_inplace \
        -e 's|bash scripts/md-store-memory\.sh|bash ${CLAUDE_PLUGIN_ROOT}/scripts/md-store-memory.sh|g' \
        -e 's|bash scripts/md-recall-memory\.sh|bash ${CLAUDE_PLUGIN_ROOT}/scripts/md-recall-memory.sh|g' \
        -e 's|\.claude/skills/\([^/]*\)/scripts/|${CLAUDE_PLUGIN_ROOT}/skills/\1/scripts/|g' \
        "$f"
done < <(find "$PLUGIN/skills" -name "SKILL.md")
echo "  [+] Transformed memory + self-ref paths in SKILL.md files"

# --- Phase 4a: Agents ---
echo ""
echo "[Phase 4a] Copying agents..."
cp "$BOILERPLATE"/.claude/agents/*.md "$PLUGIN/agents/"
AGENTS_COUNT=$(ls "$PLUGIN/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] Copied ${AGENTS_COUNT} agents"

# --- Phase 4b: Hooks (with path transformation) ---
echo ""
echo "[Phase 4b] Transforming hooks..."

# Transform hooks from settings.json
# Change: "$CLAUDE_PROJECT_DIR"/.claude/hooks/X -> ${CLAUDE_PLUGIN_ROOT}/scripts/X
# Pure bash hooks.json transformation
# Extract hooks object from settings.json, wrap in {"hooks": ...}
awk '
    BEGIN { depth=0; in_hooks=0; in_str=0; print "{\"hooks\":" }
    /"hooks"[[:space:]]*:[[:space:]]*\{/ && !in_hooks {
        in_hooks=1; depth=0
        # Find the opening brace on this line
        for (i=1; i<=length($0); i++) {
            c = substr($0,i,1)
            if (c == "\"") { in_str=!in_str; continue }
            if (in_str) continue
            if (c == "{") { depth++; if (depth==1) { print substr($0,i); break } }
        }
        next
    }
    in_hooks {
        for (i=1; i<=length($0); i++) {
            c = substr($0,i,1)
            if (c == "\\") { i++; continue }
            if (c == "\"") { in_str=!in_str; continue }
            if (in_str) continue
            if (c == "{") depth++
            if (c == "}") {
                depth--
                if (depth == 0) {
                    print substr($0, 1, i)
                    in_hooks=0
                    break
                }
            }
        }
        if (in_hooks) print
    }
    END { print "}" }
' "$BOILERPLATE/.claude/settings.json" \
| sed 's|\\"\$CLAUDE_PROJECT_DIR\\"/.claude/hooks/|${CLAUDE_PLUGIN_ROOT}/scripts/|g' \
> "$PLUGIN/hooks/hooks.json"
echo "  [+] Created hooks.json with transformed paths"

# --- Phase 4c: Hook Scripts ---
echo ""
echo "[Phase 4c] Copying hook scripts..."
for script in "$BOILERPLATE"/.claude/hooks/*.sh "$BOILERPLATE"/.claude/hooks/*.py; do
    if [ -f "$script" ]; then
        cp "$script" "$PLUGIN/scripts/"
        chmod +x "$PLUGIN/scripts/$(basename "$script")"
    fi
done
HOOK_SCRIPTS_COUNT=$(ls "$PLUGIN/scripts/"*.{sh,py} 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] Copied ${HOOK_SCRIPTS_COUNT} hook scripts"

# --- Phase 5a: MCP Config (optional - skip if .mcp.json not present) ---
echo ""
echo "[Phase 5a] Creating MCP config..."
if [ -f "$BOILERPLATE/.mcp.json" ]; then
    sed \
        -e 's|": "\."$|": "${CLAUDE_PROJECT_DIR:-.}"|' \
        -e '/"context7"/,/}/d' \
        -e '/"enable_tool_search"/d' \
        "$BOILERPLATE/.mcp.json" > "$PLUGIN/.mcp.json"
    echo "  [+] Created .mcp.json with adjusted paths"
else
    echo "  [SKIP] .mcp.json not found (pure bash mode)"
fi

# --- Phase 5b: HXSK Templates ---
echo ""
echo "[Phase 5b] Copying HXSK templates..."
# Templates (md files)
cp "$BOILERPLATE"/.hxsk/templates/*.md "$PLUGIN/templates/hxsk/templates/"
TEMPLATES_COUNT=$(ls "$PLUGIN/templates/hxsk/templates/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] Copied ${TEMPLATES_COUNT} templates"

# Templates (yaml files)
cp "$BOILERPLATE"/.hxsk/templates/*.yaml "$PLUGIN/templates/hxsk/templates/" 2>/dev/null || true
YAML_COUNT=$(ls "$PLUGIN/templates/hxsk/templates/"*.yaml 2>/dev/null | wc -l | tr -d ' ')
[ "$YAML_COUNT" -gt 0 ] && echo "  [+] Copied ${YAML_COUNT} yaml configs"

# Examples
cp "$BOILERPLATE"/.hxsk/examples/*.md "$PLUGIN/templates/hxsk/examples/"
EXAMPLES_COUNT=$(ls "$PLUGIN/templates/hxsk/examples/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] Copied ${EXAMPLES_COUNT} examples"

# Working document shells (complete set)
for doc in SPEC DECISIONS JOURNAL ROADMAP PATTERNS STATE TODO STACK CHANGELOG; do
    # Create empty shell files for scaffolding
    cat > "$PLUGIN/templates/hxsk/${doc}.md" << EOF
# ${doc}

<!-- This file will be populated during /hxsk:init -->
<!-- See templates/${doc,,}.md for the full template -->
EOF
done
echo "  [+] Created 9 working document shells"

# --- Phase 5c: Infrastructure References ---
echo ""
echo "[Phase 5c] Copying infrastructure references..."

# Direct copies
[ -f "$BOILERPLATE/pyproject.toml" ] && cp "$BOILERPLATE/pyproject.toml" "$PLUGIN/references/"
[ -f "$BOILERPLATE/Makefile" ] && cp "$BOILERPLATE/Makefile" "$PLUGIN/references/"
[ -f "$BOILERPLATE/.gitignore" ] && cp "$BOILERPLATE/.gitignore" "$PLUGIN/references/gitignore.txt"
[ -f "$BOILERPLATE/CLAUDE.md" ] && cp "$BOILERPLATE/CLAUDE.md" "$PLUGIN/references/"
[ -f "$BOILERPLATE/.env.example" ] && cp "$BOILERPLATE/.env.example" "$PLUGIN/references/env.example"

# Nested copies
[ -f "$BOILERPLATE/.github/workflows/ci.yml" ] && cp "$BOILERPLATE/.github/workflows/ci.yml" "$PLUGIN/references/"
[ -f "$BOILERPLATE/.vscode/settings.json" ] && cp "$BOILERPLATE/.vscode/settings.json" "$PLUGIN/references/vscode-settings.json"
[ -f "$BOILERPLATE/.vscode/extensions.json" ] && cp "$BOILERPLATE/.vscode/extensions.json" "$PLUGIN/references/vscode-extensions.json"
[ -f "$BOILERPLATE/.github/agents/agent.md" ] && cp "$BOILERPLATE/.github/agents/agent.md" "$PLUGIN/references/github-agent.md"

# Issue templates
for tpl in "$BOILERPLATE"/.github/ISSUE_TEMPLATE/*.yml; do
    [ -f "$tpl" ] && cp "$tpl" "$PLUGIN/references/issue-templates/"
done

REFS_COUNT=$(find "$PLUGIN/references" -type f | wc -l | tr -d ' ')
echo "  [+] Copied ${REFS_COUNT} reference files"

# --- Phase 5d: Utility Scripts ---
echo ""
echo "[Phase 5d] Copying utility scripts..."
for util in compact-context.sh organize-docs.sh; do
    if [ -f "$BOILERPLATE/scripts/$util" ]; then
        cp "$BOILERPLATE/scripts/$util" "$PLUGIN/scripts/"
        chmod +x "$PLUGIN/scripts/$util"
        echo "  [+] Copied $util"
    fi
done

# --- Phase 6a: Scaffold HXSK Script ---
echo ""
echo "[Phase 6a] Creating scaffold-hxsk.sh..."
cat > "$PLUGIN/scripts/scaffold-hxsk.sh" << 'SCAFFOLDEOF'
#!/usr/bin/env bash
#
# scaffold-hxsk.sh - Initialize HXSK document structure in a project
#
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TARGET="$PROJECT_DIR/.hxsk"

echo "Scaffolding HXSK documents..."
echo "  Plugin: ${PLUGIN_ROOT}"
echo "  Target: ${TARGET}"
echo ""

# Create directories
mkdir -p "$TARGET" "$TARGET/templates" "$TARGET/examples" "$TARGET/archive" "$TARGET/reports" "$TARGET/research"

# Copy working documents (all shell files)
for f in "$PLUGIN_ROOT"/templates/hxsk/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] $(basename "$f") - already exists"
    else
        cp "$f" "$dst"
        echo "[CREATED] $(basename "$f")"
    fi
done

# Copy yaml configs
for f in "$PLUGIN_ROOT"/templates/hxsk/templates/*.yaml; do
    [ -f "$f" ] || continue
    dst="$TARGET/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] $(basename "$f") - already exists"
    else
        cp "$f" "$dst"
        echo "[CREATED] $(basename "$f")"
    fi
done

# Copy templates
for f in "$PLUGIN_ROOT"/templates/hxsk/templates/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/templates/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] templates/$(basename "$f") - already exists"
    else
        cp "$f" "$dst"
        echo "[CREATED] templates/$(basename "$f")"
    fi
done

# Copy examples
for f in "$PLUGIN_ROOT"/templates/hxsk/examples/*.md; do
    [ -f "$f" ] || continue
    dst="$TARGET/examples/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "[SKIP] examples/$(basename "$f") - already exists"
    else
        cp "$f" "$dst"
        echo "[CREATED] examples/$(basename "$f")"
    fi
done

echo ""
echo "HXSK scaffolding complete!"
echo "  Working docs: .hxsk/{SPEC,DECISIONS,JOURNAL,ROADMAP,PATTERNS,STATE,TODO,STACK,CHANGELOG}.md"
echo "  Config:       .hxsk/context-config.yaml"
echo "  Templates:    .hxsk/templates/"
echo "  Examples:     .hxsk/examples/"
echo "  Directories:  .hxsk/{archive,reports,research}/"
SCAFFOLDEOF
chmod +x "$PLUGIN/scripts/scaffold-hxsk.sh"
echo "  [+] Created scaffold-hxsk.sh"

# --- Phase 6b: Scaffold Infra Script ---
echo ""
echo "[Phase 6b] Creating scaffold-infra.sh..."
cat > "$PLUGIN/scripts/scaffold-infra.sh" << 'INFRAEOF'
#!/usr/bin/env bash
#
# scaffold-infra.sh - Compare project files against HXSK references
#
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "Comparing infrastructure files..."
echo "  Plugin: ${PLUGIN_ROOT}"
echo "  Project: ${PROJECT_DIR}"
echo ""

# Define mappings: reference_file -> project_path
declare -A MAP=(
    ["pyproject.toml"]="pyproject.toml"
    ["Makefile"]="Makefile"
    ["gitignore.txt"]=".gitignore"
    ["ci.yml"]=".github/workflows/ci.yml"
    ["CLAUDE.md"]="CLAUDE.md"
    ["vscode-settings.json"]=".vscode/settings.json"
    ["vscode-extensions.json"]=".vscode/extensions.json"
    ["github-agent.md"]=".github/agents/agent.md"
    ["env.example"]=".env.example"
)

has_diff=0

for ref in "${!MAP[@]}"; do
    ref_path="$PLUGIN_ROOT/references/$ref"
    proj_path="$PROJECT_DIR/${MAP[$ref]}"

    if [ ! -f "$ref_path" ]; then
        continue
    fi

    if [ ! -f "$proj_path" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[MISSING] ${MAP[$ref]}"
        echo "  Reference available at: $ref_path"
        echo ""
        has_diff=1
    else
        # Check if files differ
        if ! diff -q "$proj_path" "$ref_path" > /dev/null 2>&1; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "[DIFFERS] ${MAP[$ref]}"
            echo ""
            diff -u "$proj_path" "$ref_path" | head -50 || true
            echo ""
            has_diff=1
        fi
    fi
done

# Check issue templates
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Issue Templates]"
for ref in "$PLUGIN_ROOT"/references/issue-templates/*.yml; do
    [ -f "$ref" ] || continue
    tpl_name=$(basename "$ref")
    proj_tpl="$PROJECT_DIR/.github/ISSUE_TEMPLATE/$tpl_name"

    if [ ! -f "$proj_tpl" ]; then
        echo "  [MISSING] .github/ISSUE_TEMPLATE/$tpl_name"
        has_diff=1
    elif ! diff -q "$proj_tpl" "$ref" > /dev/null 2>&1; then
        echo "  [DIFFERS] .github/ISSUE_TEMPLATE/$tpl_name"
        has_diff=1
    else
        echo "  [OK] .github/ISSUE_TEMPLATE/$tpl_name"
    fi
done

echo ""
if [ $has_diff -eq 0 ]; then
    echo "All infrastructure files match references!"
else
    echo "Review the differences above."
    echo "Reference files are in: $PLUGIN_ROOT/references/"
fi
INFRAEOF
chmod +x "$PLUGIN/scripts/scaffold-infra.sh"
echo "  [+] Created scaffold-infra.sh"

# --- Phase 6c: README ---
echo ""
echo "[Phase 6c] Creating README.md..."
# Generate README dynamically from actual build output
# --- Generate README (pure bash) ---
PLUGIN_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    "$PLUGIN/.claude-plugin/plugin.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Collect commands
CMD_ROWS=""
CMD_COUNT=0
for f in "$PLUGIN/commands/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "${f%.md}")
    desc=$(extract_frontmatter_field "$f" "description")
    [ -z "$desc" ] && desc="Run ${name}"
    CMD_ROWS="${CMD_ROWS}| \`/hxsk:${name}\` | ${desc} |
"
    CMD_COUNT=$((CMD_COUNT + 1))
done

# Collect skills
SKILL_ROWS=""
SKILL_COUNT=0
for d in "$PLUGIN/skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    sm="$d/SKILL.md"
    desc=""
    [ -f "$sm" ] && desc=$(extract_frontmatter_field "$sm" "description")
    [ -z "$desc" ] && desc="Run ${name} skill"
    SKILL_ROWS="${SKILL_ROWS}| \`${name}\` | ${desc} |
"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

# Collect agents
AGENT_ROWS=""
AGENT_COUNT=0
for f in "$PLUGIN/agents/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "${f%.md}")
    desc=$(extract_frontmatter_field "$f" "description")
    [ -z "$desc" ] && desc="${name} agent"
    AGENT_ROWS="${AGENT_ROWS}| \`${name}\` | ${desc} |
"
    AGENT_COUNT=$((AGENT_COUNT + 1))
done

cat > "$PLUGIN/README.md" << READMEEOF
# HExoskeleton for Claude Code

**Get Shit Done** v${PLUGIN_VERSION} — AI agent development methodology with pure bash-based memory system.

**외부 종속성 없음** — Node.js, Python 환경, MCP 서버 설치 없이 바로 사용 가능합니다.

## Installation

\`\`\`bash
claude --plugin-dir /path/to/hxsk-plugin
\`\`\`

## Commands (${CMD_COUNT})

| Command | Description |
|---------|-------------|
${CMD_ROWS}
## Skills (${SKILL_COUNT})

| Skill | Description |
|-------|-------------|
${SKILL_ROWS}
## Agents (${AGENT_COUNT})

| Agent | Description |
|-------|-------------|
${AGENT_ROWS}
## Hooks

| Event | Action |
|-------|--------|
| **SessionStart** | Environment setup, status check |
| **PreToolUse** | File protection, bash guard |
| **PostToolUse** | Auto-format, track modifications |
| **Stop** | Verify work, save context |
| **SessionEnd** | Save transcript, session changes |

## License

MIT
READMEEOF

echo "  [+] Created README.md (v${PLUGIN_VERSION}, ${CMD_COUNT} commands, ${SKILL_COUNT} skills, ${AGENT_COUNT} agents)"

# --- Phase 7: Clean up (no install scripts needed) ---
echo ""
echo "[Phase 7] Plugin is used via --plugin-dir flag. No install scripts needed."
# Remove marketplace.json if leftover from previous builds
rm -f "$PLUGIN/.claude-plugin/marketplace.json"

# --- Phase 8: Verification ---
verify_header 8
verify_dirs "$PLUGIN" .claude-plugin commands skills agents hooks scripts templates references

# Count check
echo ""
echo "[Counts]"
cmd_count=$(ls "$PLUGIN/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls -d "$PLUGIN/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
agent_count=$(ls "$PLUGIN/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
script_count=$(find "$PLUGIN/scripts" -type f \( -name "*.sh" -o -name "*.py" \) | wc -l | tr -d ' ')
template_count=$(ls "$PLUGIN/templates/hxsk/templates/"*.md 2>/dev/null | wc -l | tr -d ' ')

echo "  Commands:  ${cmd_count}"
[ "$cmd_count" -ge 1 ] || { echo "    [WARN] No commands found"; }

verify_count "Skills" "$skill_count" 18
verify_count "Agents" "$agent_count" 16
verify_count "Scripts" "$script_count" 17
verify_count "Templates" "$template_count" 22

# Transformation check
echo ""
echo "[Transformations]"

# hooks.json should not contain .claude/hooks/
if grep -q '\.claude/hooks/' "$PLUGIN/hooks/hooks.json" 2>/dev/null; then
    echo "  [FAIL] hooks.json still contains .claude/hooks/ references"
    BUILD_ERRORS=$((BUILD_ERRORS + 1))
else
    echo "  [OK] hooks.json paths transformed"
fi

# SKILL.md files should not contain .claude/hooks/ references
if grep -rl '\.claude/hooks/' "$PLUGIN/skills/" 2>/dev/null | grep -q .; then
    echo "  [FAIL] SKILL.md files still contain .claude/hooks/ references"
    BUILD_ERRORS=$((BUILD_ERRORS + 1))
else
    echo "  [OK] SKILL.md paths transformed"
fi

# .mcp.json should contain CLAUDE_PROJECT_DIR (optional)
if [ -f "$PLUGIN/.mcp.json" ]; then
    if grep -q 'CLAUDE_PROJECT_DIR' "$PLUGIN/.mcp.json" 2>/dev/null; then
        echo "  [OK] .mcp.json contains CLAUDE_PROJECT_DIR"
    else
        echo "  [FAIL] .mcp.json missing CLAUDE_PROJECT_DIR"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
    fi
else
    echo "  [SKIP] .mcp.json not present (pure bash mode)"
fi

# Permission check
echo ""
echo "[Permissions]"
non_exec=0
for script in "$PLUGIN/scripts/"*.{sh,py}; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
        echo "  [FAIL] $(basename "$script") not executable"
        non_exec=$((non_exec + 1))
    fi
done
if [ $non_exec -eq 0 ]; then
    echo "  [OK] All scripts executable"
else
    BUILD_ERRORS=$((BUILD_ERRORS + non_exec))
fi

# JSON validity check
echo ""
echo "[JSON Validity]"
verify_json "$PLUGIN/.claude-plugin/plugin.json"
verify_json "$PLUGIN/hooks/hooks.json"
verify_json_optional "$PLUGIN/.mcp.json"

# Summary
print_build_result "$PLUGIN" \
    "To use:" \
    "  claude --plugin-dir $PLUGIN" \
    "" \
    "To use permanently (shell alias):" \
    "  alias claude='claude --plugin-dir $PLUGIN'"
