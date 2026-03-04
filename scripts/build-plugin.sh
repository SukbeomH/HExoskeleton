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
    VERSION=$(python3 -c "import json; m=json.load(open('$MANIFEST')); print(m.get('.', m.get('hxsk-plugin', '1.0.0')))")
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
export BOILERPLATE
python3 - "$BOILERPLATE" "$PLUGIN" << 'PYEOF'
import json
import re
import sys

boilerplate = sys.argv[1]
plugin_dir = sys.argv[2]

with open(f"{boilerplate}/.claude/settings.json", 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

def transform_command(cmd):
    # "$CLAUDE_PROJECT_DIR"/.claude/hooks/X -> ${CLAUDE_PLUGIN_ROOT}/scripts/X
    pattern = r'"?\$CLAUDE_PROJECT_DIR"?/\.claude/hooks/([^"\s]+)'
    replacement = r'${CLAUDE_PLUGIN_ROOT}/scripts/\1'
    return re.sub(pattern, replacement, cmd)

def transform_hooks_recursive(obj):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key == 'command' and isinstance(value, str):
                obj[key] = transform_command(value)
            else:
                transform_hooks_recursive(value)
    elif isinstance(obj, list):
        for item in obj:
            transform_hooks_recursive(item)

transform_hooks_recursive(hooks)

# Wrap hooks in "hooks" key for plugin format
output = {"hooks": hooks}

output_path = f"{plugin_dir}/hooks/hooks.json"
with open(output_path, 'w') as f:
    json.dump(output, f, indent=2)
PYEOF
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
    # Transform graph-code args and remove servers requiring env vars
    python3 - "$BOILERPLATE" "$PLUGIN" << 'PYEOF'
import json
import sys

boilerplate = sys.argv[1]
plugin_dir = sys.argv[2]

with open(f"{boilerplate}/.mcp.json", 'r') as f:
    mcp = json.load(f)

# Transform graph-code args
if 'mcpServers' in mcp and 'graph-code' in mcp['mcpServers']:
    args = mcp['mcpServers']['graph-code'].get('args', [])
    # Replace "." with "${CLAUDE_PROJECT_DIR:-.}"
    mcp['mcpServers']['graph-code']['args'] = [
        '${CLAUDE_PROJECT_DIR:-.}' if arg == '.' else arg
        for arg in args
    ]

# Remove servers requiring environment variables (context7)
if 'mcpServers' in mcp:
    mcp['mcpServers'].pop('context7', None)

# Remove non-standard fields
mcp.pop('enable_tool_search', None)

output_path = f"{plugin_dir}/.mcp.json"
with open(output_path, 'w') as f:
    json.dump(mcp, f, indent=2)
PYEOF
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
python3 - "$PLUGIN" << 'READMEPY'
import json, os, re, sys

plugin_dir = sys.argv[1]

# Read version
with open(os.path.join(plugin_dir, ".claude-plugin", "plugin.json")) as f:
    version = json.load(f).get("version", "0.0.0")

# Collect commands with descriptions
commands = []
cmd_dir = os.path.join(plugin_dir, "commands")
if os.path.isdir(cmd_dir):
    for f in sorted(os.listdir(cmd_dir)):
        if not f.endswith(".md"):
            continue
        name = f[:-3]
        desc = ""
        with open(os.path.join(cmd_dir, f)) as fh:
            in_front = False
            for line in fh:
                if line.strip() == "---":
                    in_front = not in_front
                    continue
                if in_front and line.startswith("description:"):
                    desc = line.split(":", 1)[1].strip().strip('"')
                    break
        commands.append((name, desc))

# Collect skills
skills = []
skill_dir = os.path.join(plugin_dir, "skills")
if os.path.isdir(skill_dir):
    for d in sorted(os.listdir(skill_dir)):
        skill_md = os.path.join(skill_dir, d, "SKILL.md")
        if not os.path.isfile(skill_md):
            continue
        desc = ""
        with open(skill_md) as fh:
            in_front = False
            for line in fh:
                if line.strip() == "---":
                    in_front = not in_front
                    continue
                if in_front and line.startswith("description:"):
                    desc = line.split(":", 1)[1].strip().strip('"')
                    break
        skills.append((d, desc or f"Run {d} skill"))

# Collect agents
agents = []
agent_dir = os.path.join(plugin_dir, "agents")
if os.path.isdir(agent_dir):
    for f in sorted(os.listdir(agent_dir)):
        if not f.endswith(".md"):
            continue
        name = f[:-3]
        desc = ""
        with open(os.path.join(agent_dir, f)) as fh:
            in_front = False
            for line in fh:
                if line.strip() == "---":
                    in_front = not in_front
                    continue
                if in_front and line.startswith("description:"):
                    desc = line.split(":", 1)[1].strip().strip('"')
                    break
        agents.append((name, desc or f"{name} agent"))

# Build README
readme = f"""# HExoskeleton for Claude Code

**Get Shit Done** v{version} — AI agent development methodology with pure bash-based memory system.

**외부 종속성 없음** — Node.js, Python 환경, MCP 서버 설치 없이 바로 사용 가능합니다.

## Installation

```bash
# Use with --plugin-dir flag
claude --plugin-dir /path/to/hxsk-plugin

# Or set a shell alias for convenience (~/.zshrc or ~/.bashrc)
alias claude='claude --plugin-dir /path/to/hxsk-plugin'
```

### GitHub Release에서 설치

```bash
# 최신 버전
VERSION=$(gh release view --json tagName -q .tagName | sed 's/hxsk-plugin-v//')
curl -L "https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/latest/download/hxsk-plugin-${{VERSION}}.zip" -o hxsk-plugin.zip
unzip hxsk-plugin.zip -d ~/.claude/plugins/hxsk
```

## Prerequisites

- **Claude Code** CLI

### Optional: MCP Servers

MCP 서버는 **선택적**입니다. 기본 메모리 기능은 순수 bash 스크립트로 제공됩니다.

| Server | Install | Role |
|--------|---------|------|
| code-graph-rag *(optional)* | `npm i -g @er77/code-graph-rag-mcp` | AST-based code analysis |
| mcp-memory-service *(optional)* | `pipx install mcp-memory-service` | Semantic memory search |
| context7 *(optional)* | Project `.mcp.json`에 직접 추가 | Library documentation lookup |

## Memory System

순수 bash 기반 메모리 시스템 (외부 종속성 없음):

```bash
# 메모리 저장
bash scripts/md-store-memory.sh "제목" "내용" "태그1,태그2" "타입"

# 메모리 검색
bash scripts/md-recall-memory.sh "검색어" "." 5 compact
```

14개 메모리 타입: `architecture-decision`, `root-cause`, `debug-eliminated`, `session-summary` 등

## Quick Start

```bash
/hxsk:init          # Initialize HXSK documents
/hxsk:bootstrap     # Full project setup
/hxsk:planner       # Create implementation plan
/hxsk:executor      # Execute planned work
/hxsk:verifier      # Verify completed work
```

## Commands ({len(commands)})

| Command | Description |
|---------|-------------|
"""

for name, desc in commands:
    readme += f"| `/hxsk:{name}` | {desc} |\n"

readme += f"""
## Skills ({len(skills)})

| Skill | Description |
|-------|-------------|
"""

for name, desc in skills:
    readme += f"| `{name}` | {desc} |\n"

readme += f"""
## Agents ({len(agents)})

| Agent | Description |
|-------|-------------|
"""

for name, desc in agents:
    readme += f"| `{name}` | {desc} |\n"

readme += """
## HXSK Document Structure

After `/hxsk:init`:

```
.hxsk/
├── SPEC.md           # Project specification
├── DECISIONS.md      # Architecture decision records
├── JOURNAL.md        # Development journal
├── ROADMAP.md        # Project roadmap
├── PATTERNS.md       # Distilled learnings (2KB limit)
├── STATE.md          # Current execution state
├── TODO.md           # Task tracking
├── STACK.md          # Technology stack
├── CHANGELOG.md      # Change history
├── templates/        # Document templates
└── examples/         # Usage examples
```

## Hooks

| Event | Action |
|-------|--------|
| **SessionStart** | Environment setup, status check |
| **PreToolUse** | File protection (`file-protect.py`), bash guard (`bash-guard.py`) |
| **PostToolUse** | Auto-format, track modifications |
| **PreCompact** | Save state before context compaction |
| **Stop** | Index code changes, verify work, save context |
| **SubagentStop** | Summarize findings, update PATTERNS.md |
| **SessionEnd** | Save transcript, session changes |

## MCP Server Paths

Plugin uses dynamic paths — no hardcoded absolute paths:

| Variable | Resolves To |
|----------|-------------|
| `${CLAUDE_PROJECT_DIR:-.}` | Current project directory |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin installation directory |

Memory DB: `${CLAUDE_PROJECT_DIR}/.agent/data/memory-service/memories.db` (project-isolated)

## License

MIT
"""

with open(os.path.join(plugin_dir, "README.md"), "w") as f:
    f.write(readme)

print(f"  [+] Created README.md (v{version}, {len(commands)} commands, {len(skills)} skills, {len(agents)} agents)")
READMEPY

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

verify_count "Skills" "$skill_count" 17
verify_count "Agents" "$agent_count" 15
verify_count "Scripts" "$script_count" 9
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
