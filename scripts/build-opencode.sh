#!/usr/bin/env bash
#
# OpenCode Build Script
# Converts boilerplate to OpenCode format with model field support
#
set -euo pipefail

# --- Configuration ---
BOILERPLATE="$(cd "$(dirname "$0")/.." && pwd)"
OPENCODE="${BOILERPLATE}/opencode-boilerplate"

echo "=== OpenCode Builder ==="
echo "Source: ${BOILERPLATE}"
echo "Target: ${OPENCODE}"
echo ""

# --- Phase 1: Directory Structure ---
echo "[Phase 1] Creating directory structure..."
rm -rf "$OPENCODE"
mkdir -p "$OPENCODE"/.opencode/{agents,plugins,commands,skill}
mkdir -p "$OPENCODE"/templates/gsd/{templates,examples}
mkdir -p "$OPENCODE"/scripts

echo "  [+] .opencode/agents/"
echo "  [+] .opencode/plugins/"
echo "  [+] .opencode/commands/"
echo "  [+] .opencode/skill/"
echo "  [+] templates/gsd/"
echo "  [+] scripts/"

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
    ".gsd/SPEC.md"
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
echo "[Phase 7] Creating AGENTS.md..."

if [ -f "$BOILERPLATE/CLAUDE.md" ]; then
    cp "$BOILERPLATE/CLAUDE.md" "$OPENCODE/AGENTS.md"
    echo "  [+] AGENTS.md created from CLAUDE.md"
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

# --- Phase 8: GSD Templates ---
echo ""
echo "[Phase 8] Copying GSD templates..."

# Templates
cp "$BOILERPLATE"/.gsd/templates/*.md "$OPENCODE/templates/gsd/templates/" 2>/dev/null || true
cp "$BOILERPLATE"/.gsd/templates/*.yaml "$OPENCODE/templates/gsd/templates/" 2>/dev/null || true
TEMPLATES_COUNT=$(find "$OPENCODE/templates/gsd/templates" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] ${TEMPLATES_COUNT} templates"

# Examples
cp "$BOILERPLATE"/.gsd/examples/*.md "$OPENCODE/templates/gsd/examples/" 2>/dev/null || true
EXAMPLES_COUNT=$(find "$OPENCODE/templates/gsd/examples" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] ${EXAMPLES_COUNT} examples"

# Working document shells
for doc in SPEC DECISIONS JOURNAL ROADMAP PATTERNS STATE TODO STACK CHANGELOG; do
    doc_lower=$(echo "$doc" | tr '[:upper:]' '[:lower:]')
    cat > "$OPENCODE/templates/gsd/${doc}.md" << EOF
# ${doc}

<!-- Initialize with /init command -->
<!-- See templates/${doc_lower}.md for full template -->
EOF
done
echo "  [+] 9 working document shells"

# --- Phase 9: Utility Scripts ---
echo ""
echo "[Phase 9] Creating utility scripts..."

# scaffold-gsd.sh
cat > "$OPENCODE/scripts/scaffold-gsd.sh" << 'SCAFFOLDEOF'
#!/usr/bin/env bash
#
# scaffold-gsd.sh - Initialize GSD document structure
#
set -euo pipefail

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
chmod +x "$OPENCODE/scripts/scaffold-gsd.sh"
echo "  [+] scaffold-gsd.sh"

# Copy ALL hook scripts (Python and Shell)
echo "  Copying hook scripts..."
HOOK_COUNT=0
for script in "$BOILERPLATE"/.claude/hooks/*.py "$BOILERPLATE"/.claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    basename_script=$(basename "$script")
    [[ "$basename_script" == _* ]] && continue
    cp "$script" "$OPENCODE/scripts/"
    chmod +x "$OPENCODE/scripts/$basename_script"
    HOOK_COUNT=$((HOOK_COUNT + 1))
done
echo "  [+] Copied ${HOOK_COUNT} hook scripts"

# Copy utility
if [ -f "$BOILERPLATE/.claude/hooks/_json_parse.sh" ]; then
    cp "$BOILERPLATE/.claude/hooks/_json_parse.sh" "$OPENCODE/scripts/"
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
{"name":"opencode-plugins","type":"module","dependencies":{"@opencode-ai/plugin":"latest"}}
PKGEOF

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

## Features

- ✅ **Model per Agent**: Each agent has its own model configuration
- ✅ **Token Optimization**: Haiku for planning, Sonnet/Opus for implementation
- ✅ **Compaction**: Auto context compaction with pruning
- ✅ **Multi-provider**: Anthropic, OpenAI, Google, and more

## Quick Start

1. **Copy to your project**
   ```bash
   cp -r opencode-boilerplate/.opencode /path/to/project/
   cp opencode-boilerplate/opencode.json /path/to/project/
   cp opencode-boilerplate/AGENTS.md /path/to/project/
   cp opencode-boilerplate/.mcp.json /path/to/project/
   ```

2. **Initialize GSD Documents**
   ```bash
   bash scripts/scaffold-gsd.sh
   ```

3. **Start OpenCode**
   ```bash
   opencode
   ```

## Directory Structure

```
.opencode/
├── agents/          # Agent definitions with model config
│   ├── planner.md   # model: anthropic/claude-opus-4-20250514
│   ├── executor.md  # model: anthropic/claude-sonnet-4-20250514
│   └── ...
├── commands/        # Workflow commands (/plan, /execute, etc.)
├── plugins/         # TypeScript plugins
└── skill/           # Skills (SKILL.md format)

opencode.json        # Main config with agent model mapping
AGENTS.md            # Project rules (equivalent to CLAUDE.md)
.mcp.json            # MCP server configuration
```

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

- `auto`: Automatically compact when context is full
- `prune`: Remove old tool outputs
- `small_model`: Use Haiku for title generation, etc.

## Commands

| Command | Description |
|---------|-------------|
| `/plan` | Create implementation plan |
| `/execute` | Execute planned work |
| `/verify` | Verify completed work |
| `/debug` | Systematic debugging |
| `/help` | List all commands |

## MCP Servers

Pre-configured in `.mcp.json`:

| Server | Purpose |
|--------|---------|
| `graph-code` | AST-based code analysis |
| `memory` | Persistent agent memory (8 tools) |
| `context7` | Library documentation |

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
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Phase 11] Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

errors=0

# Structure check
echo ""
echo "[Structure]"
for dir in .opencode/agents .opencode/commands .opencode/skill templates scripts; do
    if [ -d "$OPENCODE/$dir" ]; then
        echo "  [OK] $dir/"
    else
        echo "  [FAIL] $dir/ missing"
        errors=$((errors + 1))
    fi
done

# Counts
echo ""
echo "[Counts]"
agent_count=$(ls "$OPENCODE/.opencode/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
command_count=$(ls "$OPENCODE/.opencode/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls -d "$OPENCODE/.opencode/skill"/*/ 2>/dev/null | wc -l | tr -d ' ')

echo "  Agents:   ${agent_count} (expected: 13)"
[ "$agent_count" -ge 12 ] || echo "    [WARN] Low agent count"

echo "  Commands: ${command_count}"
[ "$command_count" -ge 1 ] || echo "    [WARN] No commands found"

echo "  Skills:   ${skill_count} (expected: 15)"
[ "$skill_count" -ge 14 ] || echo "    [WARN] Low skill count"

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
if python3 -c "import json; json.load(open('$OPENCODE/opencode.json'))" 2>/dev/null; then
    echo "  [OK] opencode.json"
else
    echo "  [FAIL] opencode.json invalid"
    errors=$((errors + 1))
fi
if [ -f "$OPENCODE/.mcp.json" ]; then
    if python3 -c "import json; json.load(open('$OPENCODE/.mcp.json'))" 2>/dev/null; then
        echo "  [OK] .mcp.json"
    else
        echo "  [FAIL] .mcp.json invalid"
        errors=$((errors + 1))
    fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $errors -eq 0 ]; then
    echo "BUILD SUCCESSFUL"
    echo ""
    echo "OpenCode workspace created at: $OPENCODE"
    echo ""
    echo "To use:"
    echo "  1. Copy to your project:"
    echo "     cp -r $OPENCODE/.opencode /path/to/project/"
    echo "     cp $OPENCODE/opencode.json /path/to/project/"
    echo "     cp $OPENCODE/AGENTS.md /path/to/project/"
    if [ -f "$OPENCODE/.mcp.json" ]; then
        echo "     cp $OPENCODE/.mcp.json /path/to/project/"
    fi
    echo ""
    echo "  2. Or use directly:"
    echo "     cd $OPENCODE && opencode"
    echo ""
    echo "Key features:"
    echo "  ✅ Model per agent (${with_model} agents configured)"
    echo "  ✅ Token optimization (compaction + small_model)"
    echo "  ✅ ${command_count} workflow commands"
    echo "  ✅ ${skill_count} skills"
else
    echo "BUILD COMPLETED WITH $errors ERROR(S)"
    exit 1
fi
