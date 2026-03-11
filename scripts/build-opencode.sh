#!/usr/bin/env bash
#
# OpenCode Build Script
# Converts boilerplate to OpenCode format with model field support
#
set -euo pipefail

# --- Configuration ---
BOILERPLATE="$(cd "$(dirname "$0")/.." && pwd)"
OPENCODE="${BOILERPLATE}/opencode-boilerplate"

# shellcheck source=build-common.sh
source "$(cd "$(dirname "$0")" && pwd)/build-common.sh"

init_build "OpenCode Builder" "$BOILERPLATE" "$OPENCODE"

# --- Phase 1: Directory Structure ---
echo "[Phase 1] Creating directory structure..."
rm -rf "$OPENCODE"
mkdir -p "$OPENCODE"/.opencode/{agents,plugins,commands,skill}
mkdir -p "$OPENCODE"/.hxsk/{scripts,templates,examples}

echo "  [+] .opencode/agents/"
echo "  [+] .opencode/plugins/"
echo "  [+] .opencode/commands/"
echo "  [+] .opencode/skill/"
echo "  [+] .hxsk/scripts/"
echo "  [+] .hxsk/templates/"

# --- Phase 2: Agents Migration (with model field) ---
echo ""
echo "[Phase 2] Migrating agents with model configuration..."

# Model mapping function
map_model() {
    local model_raw="$1"
    local model_key
    model_key=$(echo "$model_raw" | tr '[:upper:]' '[:lower:]')

    case "$model_key" in
        haiku) echo "anthropic/claude-haiku-4-20250514" ;;
        sonnet) echo "anthropic/claude-sonnet-4-20250514" ;;
        opus) echo "anthropic/claude-opus-4-20250514" ;;
        claude-3-haiku) echo "anthropic/claude-haiku-4-20250514" ;;
        claude-3-sonnet) echo "anthropic/claude-sonnet-4-20250514" ;;
        claude-3-opus) echo "anthropic/claude-opus-4-20250514" ;;
        gemini|gemini-pro) echo "google/gemini-2.5-pro" ;;
        gpt-4|gpt-4o) echo "openai/gpt-4o" ;;
        */*) echo "$model_raw" ;;  # Already in provider/model format
        *) echo "anthropic/claude-sonnet-4-20250514" ;;  # Default
    esac
}

# Tool mapping function
map_tool() {
    local tool="$1"
    local tool_key
    tool_key=$(echo "$tool" | tr '[:upper:]' '[:lower:]')

    case "$tool_key" in
        read) echo "read" ;;
        write) echo "write" ;;
        edit) echo "edit" ;;
        bash) echo "bash" ;;
        grep) echo "grep" ;;
        glob) echo "glob" ;;
        webfetch) echo "webfetch" ;;
        multiedit) echo "edit" ;;
        *) echo "$tool_key" ;;
    esac
}

for agent in "$BOILERPLATE"/.claude/agents/*.md; do
    [ -f "$agent" ] || continue
    filename=$(basename "$agent")
    agent_name="${filename%.md}"
    target="$OPENCODE/.opencode/agents/${filename}"

    # Extract frontmatter fields (handle CRLF)
    frontmatter=$(sed -n '/^---/,/^---/p' "$agent" | tr -d '\r')
    description=$(echo "$frontmatter" | grep "^description:" | sed 's/description: *//' | tr -d '"' || echo "")
    model_raw=$(echo "$frontmatter" | grep "^model:" | sed 's/model: *//' | tr -d '"' || echo "")
    tools_raw=$(echo "$frontmatter" | grep "^tools:" | sed 's/tools: *//' || echo "")

    # Map model to OpenCode format
    model_opencode=""
    if [ -n "$model_raw" ]; then
        model_opencode=$(map_model "$model_raw")
        if [ "$model_opencode" = "anthropic/claude-sonnet-4-20250514" ] && [ "$model_raw" != "sonnet" ] && [[ "$model_raw" != *"/"* ]]; then
            echo "    [WARN] Unknown model '$model_raw' -> defaulting to sonnet"
        fi
    fi

    # Convert tools to OpenCode format (YAML map)
    tools_yaml=""
    if [ -n "$tools_raw" ]; then
        # Parse array like ["Read", "Write", "Edit"]
        tools_clean=$(echo "$tools_raw" | tr -d '[]"' | tr ',' '\n' | tr -d ' ')
        for tool in $tools_clean; do
            tool_mapped=$(map_tool "$tool")
            tools_yaml="${tools_yaml}  ${tool_mapped}: true
"
        done
    fi

    # Extract body (after frontmatter)
    body=$(awk '/^---$/{c++;next}c==2' "$agent")

    # Build OpenCode agent file with proper frontmatter
    {
        echo "---"
        [ -n "$description" ] && echo "description: \"$description\""
        echo "mode: subagent"
        [ -n "$model_opencode" ] && echo "model: $model_opencode"
        echo "temperature: 0.1"
        if [ -n "$tools_yaml" ]; then
            echo "tools:"
            echo -e "$tools_yaml" | sed '/^$/d'
        fi
        echo "---"
        echo ""
        echo "$body"
    } > "$target"

    echo "  [+] ${agent_name} (model: ${model_opencode:-default})"
done

AGENTS_COUNT=$(ls "$OPENCODE/.opencode/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  [=] Total agents: ${AGENTS_COUNT}"

# --- Phase 3: Skills Migration ---
echo ""
echo "[Phase 3] Migrating skills..."

for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$OPENCODE/.opencode/skill/${skill_name}"
    mkdir -p "$target_dir"

    # Copy all skill contents
    cp -r "$skill_dir"/* "$target_dir/" 2>/dev/null || true

    echo "  [+] ${skill_name}"
done

SKILLS_COUNT=$(ls -d "$OPENCODE/.opencode/skill"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "  [=] Total skills: ${SKILLS_COUNT}"

# --- Phase 4: Commands (Workflows) ---
echo ""
echo "[Phase 4] Copying commands (workflows)..."

COMMANDS_COUNT=0
if [ -d "$BOILERPLATE/.agent/workflows" ]; then
    for workflow in "$BOILERPLATE"/.agent/workflows/*.md; do
        [ -f "$workflow" ] || continue
        filename=$(basename "$workflow")
        target="$OPENCODE/.opencode/commands/${filename}"

        if grep -q "^description:" "$workflow" 2>/dev/null; then
            cp "$workflow" "$target"
        else
            workflow_name="${filename%.md}"
            desc="Workflow for ${workflow_name//-/ }"

            if head -1 "$workflow" | grep -q "^---"; then
                awk 'NR==1{print; print "description: \"'"$desc"'\""; next}1' "$workflow" > "$target"
            else
                {
                    echo "---"
                    echo "description: \"${desc}\""
                    echo "---"
                    echo ""
                    cat "$workflow"
                } > "$target"
            fi
        fi
    done
    COMMANDS_COUNT=$(ls "$OPENCODE/.opencode/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  [+] Copied ${COMMANDS_COUNT} workflow commands"
else
    echo "  [SKIP] .agent/workflows/ not found — generating from skills"
    for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
        skill_name=$(basename "$skill_dir")
        skill_file="$skill_dir/SKILL.md"
        [ -f "$skill_file" ] || continue
        desc=$(sed -n '/^---/,/^---/p' "$skill_file" | tr -d '\r' | grep "^description:" | sed 's/description: *//' | tr -d '"')
        [ -z "$desc" ] && desc="Command for ${skill_name//-/ }"
        cat > "$OPENCODE/.opencode/commands/${skill_name}.md" << CMDEOF
---
description: "${desc}"
---

# ${skill_name}

${desc}

Invoke the **${skill_name}** skill.
CMDEOF
    done
    COMMANDS_COUNT=$(ls "$OPENCODE/.opencode/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  [+] Generated ${COMMANDS_COUNT} commands from skills"
fi

# --- Phase 5: OpenCode Config (opencode.json) ---
echo ""
echo "[Phase 5] Creating opencode.json..."

# Build agents config from migrated agents
agents_json="{"
first=true
for agent in "$OPENCODE/.opencode/agents/"*.md; do
    [ -f "$agent" ] || continue
    agent_name=$(basename "${agent%.md}")

    # Extract model from frontmatter
    model=$(grep "^model:" "$agent" | sed 's/model: *//' | tr -d '"' || echo "")

    if [ "$first" = true ]; then
        first=false
    else
        agents_json+=","
    fi

    agents_json+="
    \"${agent_name}\": {
      \"mode\": \"subagent\",
      \"model\": \"${model:-anthropic/claude-sonnet-4-20250514}\"
    }"
done
agents_json+="
  }"

cat > "$OPENCODE/opencode.json" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "compaction": {
    "auto": true,
    "prune": true
  },
  "small_model": "anthropic/claude-haiku-4-20250514",
  "instructions": [
    "AGENTS.md",
    ".hxsk/SPEC.md"
  ],
  "agent": ${agents_json}
}
EOF
echo "  [+] opencode.json created with ${AGENTS_COUNT} agent configs"

# --- Phase 6: MCP Configuration (optional) ---
echo ""
echo "[Phase 6] Creating MCP configuration..."

if [ -f "$BOILERPLATE/.mcp.json" ]; then
    python3 - "$BOILERPLATE" "$OPENCODE" << 'PYEOF'
import json
import sys

boilerplate = sys.argv[1]
opencode = sys.argv[2]

with open(f"{boilerplate}/.mcp.json", 'r') as f:
    mcp = json.load(f)

# Transform for OpenCode
if 'mcpServers' in mcp:
    servers = mcp['mcpServers']

    # graph-code: use current directory
    if 'graph-code' in servers:
        args = servers['graph-code'].get('args', [])
        servers['graph-code']['args'] = [
            '.' if arg == '.' else arg
            for arg in args
        ]

# Remove non-standard fields
mcp.pop('enable_tool_search', None)

# Write config
output_path = f"{opencode}/.mcp.json"
with open(output_path, 'w') as f:
    json.dump(mcp, f, indent=2)

print("  [+] .mcp.json created")
PYEOF
else
    echo "  [SKIP] .mcp.json not found (pure bash mode)"
fi

# --- Phase 7: AGENTS.md (from CLAUDE.md) ---
echo ""
echo "[Phase 7] Creating AGENTS.md from CLAUDE.md (OpenCode-patched)..."

if [ -f "$BOILERPLATE/CLAUDE.md" ]; then
    sed \
        -e 's|CLAUDE\.md|AGENTS.md|g' \
        -e 's|Claude Code (claude\.ai/code)|OpenCode|g' \
        -e 's|claude\.ai/code|OpenCode|g' \
        -e 's|Claude Code|OpenCode|g' \
        -e 's|\.claude/skills/|.opencode/skill/|g' \
        -e 's|\.claude/agents/|.opencode/agents/|g' \
        -e 's|\.claude/|.opencode/|g' \
        -e 's|`skills/` — Modular skill definitions|`skill/` — Modular skill definitions|g' \
        -e 's|scripts/md-store-memory\.sh|.hxsk/scripts/md-store-memory.sh|g' \
        -e 's|scripts/md-recall-memory\.sh|.hxsk/scripts/md-recall-memory.sh|g' \
        -e 's|\*\*scripts/\*\*|**.hxsk/scripts/**|g' \
        -e 's|`hooks/` — Event hooks and utility scripts|`plugins/` — TypeScript plugins|g' \
        -e 's|`settings\.json` — .* settings|`opencode.json` — OpenCode project settings|g' \
        -e 's|`settings\.json`|`opencode.json`|g' \
        -e 's|(Grep, Glob, Read)|(grep, find, cat)|g' \
        -e 's|Grep/Glob|grep/find|g' \
        -e 's|`Grep(pattern: "{project context}", path: ".hxsk/memories/")`|`grep -r "{project context}" .hxsk/memories/`|g' \
        -e 's|`Grep(path: ".hxsk/memories/")`|`grep -r <pattern> .hxsk/memories/`|g' \
        -e 's|`Glob(pattern: ".hxsk/memories/{type}/\*\.md")`|`find .hxsk/memories/{type}/ -name "*.md"`|g' \
        "$BOILERPLATE/CLAUDE.md" > "$OPENCODE/AGENTS.md"
    echo "  [+] AGENTS.md created from CLAUDE.md (OpenCode-patched)"
else
    cat > "$OPENCODE/AGENTS.md" << 'AGENTSEOF'
# Project Rules

This file contains project-specific rules and guidelines for the AI agent.

## Code Standards

* Follow project coding conventions
* Use type hints where applicable
* Write comprehensive tests

## Workflow

* Plan before implementing
* Verify empirically
* Commit atomically
AGENTSEOF
    echo "  [+] AGENTS.md created (default template)"
fi

# --- Phase 8: HXSK Templates ---
echo ""
echo "[Phase 8] Copying HXSK templates..."

# Templates
cp "$BOILERPLATE"/.hxsk/templates/*.md "$OPENCODE/.hxsk/templates/" 2>/dev/null || true
cp "$BOILERPLATE"/.hxsk/templates/*.yaml "$OPENCODE/.hxsk/templates/" 2>/dev/null || true
TEMPLATES_COUNT=$(find "$OPENCODE/.hxsk/templates" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] ${TEMPLATES_COUNT} templates"

# Examples
cp "$BOILERPLATE"/.hxsk/examples/*.md "$OPENCODE/.hxsk/examples/" 2>/dev/null || true
EXAMPLES_COUNT=$(find "$OPENCODE/.hxsk/examples" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] ${EXAMPLES_COUNT} examples"

# --- Phase 9: Utility Scripts ---
echo ""
echo "[Phase 9] Creating utility scripts..."

# scaffold-hxsk.sh
cat > "$OPENCODE/.hxsk/scripts/scaffold-hxsk.sh" << 'SCAFFOLDEOF'
#!/usr/bin/env bash
#
# scaffold-hxsk.sh - Initialize HXSK working documents from bundled templates
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HXSK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Scaffolding HXSK working documents..."
echo "  HXSK dir: ${HXSK_DIR}"

mkdir -p "$HXSK_DIR"/{archive,reports,research,memories}

# Create working documents from templates
CREATED=0
SKIPPED=0
for f in "$HXSK_DIR"/templates/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    upper=$(echo "${base%.md}" | tr '[:lower:]' '[:upper:]')
    dst="$HXSK_DIR/${upper}.md"
    if [ -f "$dst" ]; then
        echo "  [SKIP] ${upper}.md"
        SKIPPED=$((SKIPPED + 1))
    else
        cp "$f" "$dst"
        echo "  [CREATED] ${upper}.md"
        CREATED=$((CREATED + 1))
    fi
done

# Copy yaml configs to root
for f in "$HXSK_DIR"/templates/*.yaml; do
    [ -f "$f" ] || continue
    dst="$HXSK_DIR/$(basename "$f")"
    if [ -f "$dst" ]; then
        echo "  [SKIP] $(basename "$f")"
        SKIPPED=$((SKIPPED + 1))
    else
        cp "$f" "$dst"
        echo "  [CREATED] $(basename "$f")"
        CREATED=$((CREATED + 1))
    fi
done

echo ""
echo "HXSK scaffolding complete! (created: $CREATED, skipped: $SKIPPED)"
SCAFFOLDEOF
chmod +x "$OPENCODE/.hxsk/scripts/scaffold-hxsk.sh"
echo "  [+] scaffold-hxsk.sh"

# Copy ALL hook scripts (Python and Shell)
echo "  Copying hook scripts..."
HOOK_COUNT=0
for script in "$BOILERPLATE"/.claude/hooks/*.py "$BOILERPLATE"/.claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    basename_script=$(basename "$script")
    [[ "$basename_script" == _* ]] && continue
    cp "$script" "$OPENCODE/.hxsk/scripts/"
    chmod +x "$OPENCODE/.hxsk/scripts/$basename_script"
    HOOK_COUNT=$((HOOK_COUNT + 1))
done
echo "  [+] Copied ${HOOK_COUNT} hook scripts"

# Copy utility
if [ -f "$BOILERPLATE/.claude/hooks/_json_parse.sh" ]; then
    cp "$BOILERPLATE/.claude/hooks/_json_parse.sh" "$OPENCODE/.hxsk/scripts/"
fi

# Convert hooks to TypeScript plugins using converter script
echo "  Converting hooks to TypeScript plugins..."
if python3 "$BOILERPLATE/scripts/convert-hooks-to-plugins.py" "$BOILERPLATE/.claude/hooks" "$OPENCODE/.opencode/plugins" 2>&1 | grep -v "^$"; then
    echo "  [+] Plugins converted successfully"
else
    echo "  [WARN] Plugin conversion had issues, creating minimal templates"
    # Fallback: create minimal templates
    cat > "$OPENCODE/.opencode/plugins/bash-guard.ts" << 'EOF'
import type { Plugin } from "@opencode-ai/plugin"
export const BashGuardPlugin: Plugin = async () => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return
    const cmd = output.args?.command || ""
    if (/git\s+push\s+.*--force/.test(cmd)) throw new Error("Blocked: Use --force-with-lease")
  },
})
EOF
fi

# Ensure package.json exists
cat > "$OPENCODE/.opencode/package.json" << 'PKGEOF'
{"name":"opencode-plugins","type":"module","dependencies":{"@opencode-ai/plugin":"^1.2.10"}}
PKGEOF

# Install plugin dependencies
echo "  Installing plugin dependencies..."
if command -v npm >/dev/null 2>&1; then
    if (cd "$OPENCODE/.opencode" && npm install --silent 2>&1); then
        echo "  [+] npm install completed"
    else
        echo "  [WARN] npm install failed — plugins may not load. Run: cd $OPENCODE/.opencode && npm install"
    fi
else
    echo "  [WARN] npm not found — skip install. Run manually: cd $OPENCODE/.opencode && npm install"
fi

# Create migration guide
cat > "$OPENCODE/.opencode/plugins/MIGRATION-GUIDE.md" << 'GUIDEEOF'
# Hooks → Plugins Migration Guide

| Claude Hook | OpenCode Event |
|-------------|----------------|
| PreToolUse | tool.execute.before |
| PostToolUse | tool.execute.after |
| SessionStart | session.created |
| AfterResponse | session.idle |

## Plugin Structure
```typescript
export const MyPlugin: Plugin = async ({ $ }) => ({
  "tool.execute.before": async (input, output) => {
    // Check input.tool and output.args
  },
})
```
GUIDEEOF
echo "  [+] Created MIGRATION-GUIDE.md"

# --- Phase 10: README ---
echo ""
echo "[Phase 10] Creating README..."

cat > "$OPENCODE/README.md" << 'READMEEOF'
# OpenCode Boilerplate

AI agent development boilerplate for **OpenCode**.

**외부 종속성 없음** — 순수 bash 기반 메모리 시스템으로 바로 사용 가능합니다.

## Features

- ✅ **Model per Agent**: Each agent has its own model configuration
- ✅ **Token Optimization**: Haiku for planning, Sonnet/Opus for implementation
- ✅ **Compaction**: Auto context compaction with pruning
- ✅ **Multi-provider**: Anthropic, OpenAI, Google, and more
- ✅ **Pure Bash Memory**: 외부 종속성 없는 파일 기반 메모리 시스템

## Quick Start

1. **Copy to your project**
   ```bash
   cp -r opencode-boilerplate/.opencode /path/to/project/
   cp -r opencode-boilerplate/.hxsk /path/to/project/
   cp opencode-boilerplate/opencode.json /path/to/project/
   cp opencode-boilerplate/AGENTS.md /path/to/project/
   ```

2. **Initialize HXSK Working Documents**
   ```bash
   bash .hxsk/scripts/scaffold-hxsk.sh
   ```

3. **Start OpenCode**
   ```bash
   opencode
   ```

## Directory Structure

```
.opencode/
├── agents/          # 16 agents with model config
├── commands/        # Workflow commands (/plan, /execute, etc.)
├── plugins/         # TypeScript plugins
└── skill/           # 18 skills (SKILL.md format)

.hxsk/
├── scripts/         # Utility scripts (메모리, 스캐폴딩)
├── templates/       # Document templates
├── examples/        # Example documents
├── SPEC.md, DECISIONS.md, ...  # Working documents (after scaffold)
└── memories/        # File-based agent memory

opencode.json        # Main config with agent model mapping
AGENTS.md            # Project rules (equivalent to CLAUDE.md)
```

## Memory System (순수 Bash)

외부 종속성 없는 파일 기반 메모리 시스템:

```bash
# 메모리 저장
bash .hxsk/scripts/md-store-memory.sh "제목" "내용" "태그" "타입"

# 메모리 검색
bash .hxsk/scripts/md-recall-memory.sh "검색어" "." 5 compact
```

14개 메모리 타입: `architecture-decision`, `root-cause`, `session-summary` 등

## Agent Model Configuration

Each agent in `.opencode/agents/*.md` has a model specified:

```yaml
---
description: "Creates executable phase plans..."
mode: subagent
model: anthropic/claude-opus-4-20250514
temperature: 0.1
tools:
  read: true
  grep: true
  glob: true
---
```

### Model Mapping

| Task Type | Recommended Model | Rationale |
|-----------|-------------------|-----------|
| Planning | opus | Complex reasoning |
| Execution | sonnet | Balanced speed/quality |
| Quick tasks | haiku | Fast, cost-effective |
| Research | gemini-2.5-pro | Large context |

## Token Optimization

The `opencode.json` includes token-saving features:

```json
{
  "compaction": {
    "auto": true,
    "prune": true
  },
  "small_model": "anthropic/claude-haiku-4-20250514"
}
```

## Commands

| Command | Description |
|---------|-------------|
| `/plan` | Create implementation plan |
| `/execute` | Execute planned work |
| `/verify` | Verify completed work |
| `/debug` | Systematic debugging |
| `/help` | List all commands |

## MCP Servers (선택적)

MCP 서버는 **선택적**입니다. 기본 기능은 순수 bash로 동작합니다.

| Server | Purpose | Install |
|--------|---------|---------|
| `graph-code` | AST-based code analysis | `npm i -g @er77/code-graph-rag-mcp` |
| `memory` | Semantic memory search | `pipx install mcp-memory-service` |

## Migration from Claude Code

| Claude Code | OpenCode |
|-------------|----------|
| `CLAUDE.md` | `AGENTS.md` |
| `.claude/agents/` | `.opencode/agents/` |
| `.claude/skills/` | `.opencode/skill/` |
| `.agent/workflows/` | `.opencode/commands/` |
| `.claude/settings.json` | `opencode.json` |

### Key Difference

**Claude Code**: `model:` field in agent frontmatter is **ignored**
**OpenCode**: `model:` field is **actually applied** ✅

## License

MIT
READMEEOF
echo "  [+] README.md"

# --- Phase 11: Verification ---
verify_header 11
verify_dirs "$OPENCODE" .opencode/agents .opencode/commands .opencode/skill .hxsk/scripts .hxsk/templates

# Counts
echo ""
echo "[Counts]"
agent_count=$(ls "$OPENCODE/.opencode/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
command_count=$(ls "$OPENCODE/.opencode/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls -d "$OPENCODE/.opencode/skill"/*/ 2>/dev/null | wc -l | tr -d ' ')

verify_count "Agents" "$agent_count" 16
verify_count "Commands" "$command_count" 18
verify_count "Skills" "$skill_count" 18

# Model field check
echo ""
echo "[Model Configuration]"
with_model=0
for agent in "$OPENCODE/.opencode/agents/"*.md; do
    [ -f "$agent" ] || continue
    if grep -q "^model:" "$agent"; then
        with_model=$((with_model + 1))
    else
        echo "  [WARN] $(basename "$agent") has no model"
    fi
done
echo "  [OK] ${with_model}/${agent_count} agents have model configured"

# JSON validity
echo ""
echo "[JSON Validity]"
verify_json "$OPENCODE/opencode.json"
verify_json_optional "$OPENCODE/.mcp.json"

# Summary
mcp_line=""
[ -f "$OPENCODE/.mcp.json" ] && mcp_line="     cp $OPENCODE/.mcp.json /path/to/project/"

usage_lines=(
    "To use:"
    "  1. Copy to your project:"
    "     cp -r $OPENCODE/.opencode /path/to/project/"
    "     cp -r $OPENCODE/.hxsk /path/to/project/"
    "     cp $OPENCODE/opencode.json /path/to/project/"
    "     cp $OPENCODE/AGENTS.md /path/to/project/"
)
[ -n "$mcp_line" ] && usage_lines+=("$mcp_line")
usage_lines+=(
    ""
    "  2. Or use directly:"
    "     cd $OPENCODE && opencode"
    ""
    "Key features:"
    "  Model per agent (${with_model} agents configured)"
    "  Token optimization (compaction + small_model)"
    "  ${command_count} workflow commands"
    "  ${skill_count} skills"
)
print_build_result "$OPENCODE" "${usage_lines[@]}"
