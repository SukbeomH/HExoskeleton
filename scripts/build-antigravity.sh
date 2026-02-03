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

# --- Phase 2: Skills Migration (with model from agents) ---
echo ""
echo "[Phase 2] Migrating skills to Antigravity format..."

# Model mapping function
map_model() {
    local model_raw="$1"
    local model_key
    model_key=$(echo "$model_raw" | tr '[:upper:]' '[:lower:]')

    case "$model_key" in
        haiku) echo "anthropic/claude-haiku-4-20250514" ;;
        sonnet) echo "anthropic/claude-sonnet-4-20250514" ;;
        opus) echo "anthropic/claude-opus-4-20250514" ;;
        gemini|gemini-pro) echo "google/gemini-2.5-pro" ;;
        gpt-4|gpt-4o) echo "openai/gpt-4o" ;;
        */*) echo "$model_raw" ;;  # Already in provider/model format
        *) echo "" ;;  # Unknown, skip
    esac
}

# Skills are already in compatible format (YAML frontmatter with name/description)
for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$ANTIGRAVITY/.agent/skills/${skill_name}"
    mkdir -p "$target_dir"

    # Copy SKILL.md and any subdirectories (scripts, examples, resources)
    cp -r "$skill_dir"/* "$target_dir/" 2>/dev/null || true

    # Check if corresponding agent file exists with model setting
    agent_file="$BOILERPLATE/.claude/agents/${skill_name}.md"
    model_line=""
    if [ -f "$agent_file" ]; then
        # Extract model from agent frontmatter (handle CRLF)
        model_raw=$(tr -d '\r' < "$agent_file" | sed -n '/^---/,/^---/p' | grep "^model:" | sed 's/model: *//' | tr -d '"')
        if [ -n "$model_raw" ]; then
            model_mapped=$(map_model "$model_raw")
            if [ -n "$model_mapped" ]; then
                model_line="model: $model_mapped"
            fi
        fi
    fi

    # Inject model into SKILL.md frontmatter if not already present
    if [ -f "$target_dir/SKILL.md" ] && [ -n "$model_line" ]; then
        if ! tr -d '\r' < "$target_dir/SKILL.md" | grep -q "^model:"; then
            if tr -d '\r' < "$target_dir/SKILL.md" | grep -q "^description:"; then
                # Portable sed: write to temp file (works on both macOS and Linux)
                tmp_file="${target_dir}/SKILL.md.tmp"
                awk -v ml="$model_line" '/^description:/{print; print ml; next}1' "$target_dir/SKILL.md" > "$tmp_file"
                mv "$tmp_file" "$target_dir/SKILL.md"
            fi
        fi
    fi

    # Verify description exists in frontmatter (required for Antigravity)
    if [ -f "$target_dir/SKILL.md" ]; then
        # Handle CRLF line endings
        if tr -d '\r' < "$target_dir/SKILL.md" | grep -q "^description:"; then
            if [ -n "$model_line" ]; then
                echo "  [+] ${skill_name} (${model_raw:-default})"
            else
                echo "  [+] ${skill_name}"
            fi
        else
            echo "  [WARN] ${skill_name} - missing description in frontmatter"
        fi
    fi
done
SKILLS_COUNT=$(ls -d "$ANTIGRAVITY/.agent/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "  [=] Total skills: ${SKILLS_COUNT}"

# --- Phase 3: Workflows ---
echo ""
echo "[Phase 3] Generating workflows..."

WORKFLOWS_COUNT=0
if [ -d "$BOILERPLATE/.agent/workflows" ]; then
    # Legacy workflows exist — copy with description enforcement
    for workflow in "$BOILERPLATE"/.agent/workflows/*.md; do
        [ -f "$workflow" ] || continue
        filename=$(basename "$workflow")
        target="$ANTIGRAVITY/.agent/workflows/${filename}"

        if tr -d '\r' < "$workflow" | grep -q "^description:"; then
            cp "$workflow" "$target"
            echo "  [+] ${filename}"
        else
            workflow_name="${filename%.md}"
            desc="Workflow for ${workflow_name//-/ }"
            if head -1 "$workflow" | tr -d '\r' | grep -q "^---$"; then
                awk 'NR==1{print; print "description: \"'"$desc"'\""; next}1' "$workflow" > "$target"
            else
                { echo "---"; echo "description: \"${desc}\""; echo "---"; echo ""; cat "$workflow"; } > "$target"
            fi
            echo "  [+] ${filename} (added description)"
        fi
    done
else
    # Generate workflows from SKILL.md content
    # Antigravity workflows: step-by-step procedures invoked via /workflow-name
    python3 - "$BOILERPLATE" "$ANTIGRAVITY" << 'PYEOF'
import sys, os, re, textwrap

boilerplate = sys.argv[1]
antigravity = sys.argv[2]
skills_dir = os.path.join(boilerplate, '.claude', 'skills')
wf_dir = os.path.join(antigravity, '.agent', 'workflows')

def extract_frontmatter(content):
    """Extract YAML frontmatter fields."""
    fm = {}
    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if m:
        for line in m.group(1).splitlines():
            if ':' in line:
                key, val = line.split(':', 1)
                fm[key.strip()] = val.strip().strip('"').strip("'")
    return fm

def extract_body(content):
    """Extract body after frontmatter."""
    m = re.match(r'^---\s*\n.*?\n---\s*\n', content, re.DOTALL)
    return content[m.end():] if m else content

def extract_steps(body):
    """Extract step sections (## Step N or ### Step N patterns)."""
    steps = []
    # Find numbered step headers
    pattern = r'(?:^#{2,3}\s+(?:Step\s+\d+|단계\s+\d+)[:\s]*(.*?)$)'
    matches = list(re.finditer(pattern, body, re.MULTILINE | re.IGNORECASE))

    if matches:
        for i, match in enumerate(matches):
            start = match.start()
            end = matches[i+1].start() if i+1 < len(matches) else len(body)
            section = body[start:end].strip()
            # Truncate long sections
            lines = section.splitlines()
            if len(lines) > 25:
                section = '\n'.join(lines[:25]) + '\n...'
            steps.append(section)

    return steps

def extract_workflow_section(body):
    """Extract ## Workflow or ## Execution Flow section."""
    pattern = r'(^#{2}\s+(?:Workflow|Execution Flow|Verification Process|Search Protocol|Debug Flow|Review Process|Core Process).*?)(?=\n#{1,2}\s|\Z)'
    m = re.search(pattern, body, re.MULTILINE | re.DOTALL | re.IGNORECASE)
    if m:
        section = m.group(1).strip()
        lines = section.splitlines()
        if len(lines) > 60:
            section = '\n'.join(lines[:60]) + '\n...'
        return section
    return None

for skill_name in sorted(os.listdir(skills_dir)):
    skill_file = os.path.join(skills_dir, skill_name, 'SKILL.md')
    if not os.path.isfile(skill_file):
        continue

    with open(skill_file, 'r') as f:
        content = f.read()

    fm = extract_frontmatter(content)
    body = extract_body(content)
    desc = fm.get('description', f'Workflow for {skill_name.replace("-", " ")}')

    # Try to extract procedural content
    workflow_section = extract_workflow_section(body)
    steps = extract_steps(body)

    # Build workflow content
    wf_lines = [
        '---',
        f'description: "{desc}"',
        '---',
        '',
        f'# /{skill_name}',
        '',
        desc,
        '',
    ]

    if workflow_section:
        wf_lines.append(workflow_section)
        wf_lines.append('')
    elif steps:
        wf_lines.append('## Steps')
        wf_lines.append('')
        for step in steps:
            wf_lines.append(step)
            wf_lines.append('')
    else:
        # Fallback: extract all ## sections as workflow outline
        sections = re.findall(r'^(#{2}\s+.+)$', body, re.MULTILINE)
        if sections:
            wf_lines.append('## Procedure')
            wf_lines.append('')
            for i, sec in enumerate(sections[:10], 1):
                heading = sec.lstrip('#').strip()
                wf_lines.append(f'{i}. {heading}')
            wf_lines.append('')

    # Enforce Antigravity 12,000 char limit
    wf_content = '\n'.join(wf_lines)
    if len(wf_content) > 11500:
        wf_content = wf_content[:11500] + '\n\n> *Truncated for 12,000 char limit*\n'

    wf_path = os.path.join(wf_dir, f'{skill_name}.md')
    with open(wf_path, 'w') as f:
        f.write(wf_content)

    print(f'  [+] {skill_name}.md ({len(wf_content)} chars)')
PYEOF
fi

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
* Use mcp-memory-service for persistent agent memory
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
    # memory: keep as is

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

# Copy ALL hook scripts (Python and Shell)
echo "  Copying hook scripts..."
HOOK_COUNT=0
for script in "$BOILERPLATE"/.claude/hooks/*.py "$BOILERPLATE"/.claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    basename_script=$(basename "$script")
    # Skip _json_parse.sh (internal utility)
    [[ "$basename_script" == _* ]] && continue
    cp "$script" "$ANTIGRAVITY/scripts/"
    chmod +x "$ANTIGRAVITY/scripts/$basename_script"
    HOOK_COUNT=$((HOOK_COUNT + 1))
done
echo "  [+] Copied ${HOOK_COUNT} hook scripts"

# Copy _json_parse.sh as utility (required by shell hooks)
if [ -f "$BOILERPLATE/.claude/hooks/_json_parse.sh" ]; then
    cp "$BOILERPLATE/.claude/hooks/_json_parse.sh" "$ANTIGRAVITY/scripts/"
    echo "  [+] Copied _json_parse.sh utility"
fi

# Create hooks migration guide
cat > "$ANTIGRAVITY/scripts/HOOKS-MIGRATION.md" << 'HOOKGUIDEEOF'
# Hooks Migration Guide for Antigravity

Antigravity doesn't have direct hook equivalents like Claude Code.
Instead, hooks functionality is achieved through **Rules**, **Workflows**, and **Settings**.

## Hook Mapping

| Original Hook | Antigravity Approach | Location |
|---------------|---------------------|----------|
| `bash-guard.py` | **Rules** (안전 규칙) + **Terminal Deny List** | `.agent/rules/safety.md` + Settings |
| `file-protect.py` | **Rules** (파일 보호 규칙) | `.agent/rules/safety.md` |
| `auto-format.sh` | **Workflow** 또는 에디터 설정 | `.agent/workflows/format.md` |
| `session-start.sh` | **Planning Mode** 자동 컨텍스트 로드 | Agent Mode: Planning |
| `post-turn-index.sh` | **MCP 서버** (graph-code) 자동 인덱싱 | `mcp-settings.json` |
| `post-turn-verify.sh` | **Workflow** (`/quick-check`) | `.agent/workflows/quick-check.md` |
| `pre-compact-save.sh` | **Workflow** (`/pause`) | `.agent/workflows/pause.md` |
| `save-session-changes.sh` | **Planning Mode Artifacts** | 자동 아티팩트 저장 |
| `save-transcript.sh` | **내장 기능** | Antigravity 자동 저장 |
| `mcp-store-memory.sh` | **MCP 서버** (mcp-memory-service) | `mcp-settings.json` |
| `stop-context-save.sh` | **Workflow** (`/handoff`) | `.agent/workflows/handoff.md` |
| `track-modifications.sh` | **Git Integration** | 내장 기능 |

## Antigravity Settings 권장 설정

### Terminal Command Policy
Settings > Agent > Terminal Command Auto Execution:
- **Always Proceed** (권장): Rules가 안전장치 역할
- Allow List: `ls`, `cat`, `git status`, `git log`, `uv sync`, `npm test`
- Deny List: `rm -rf`, `git push --force`, `pip install`

### Agent Mode
- **Planning Mode** (권장): session-start.sh 역할 대체
  - 자동으로 프로젝트 컨텍스트 로드
  - Task Groups로 작업 구성
  - Artifacts 생성 및 검토

## 스크립트 직접 실행 (선택)

일부 hooks는 스크립트로 유지하여 수동 실행 가능:

```bash
# 코드 인덱싱 (post-turn-index.sh 대체)
# MCP graph-code 서버가 자동 처리

# 포맷팅 (auto-format.sh)
python scripts/auto-format.sh <file>

# 안전 검사 (bash-guard.py)
echo '{"tool_input":{"command":"git push --force"}}' | python scripts/bash-guard.py
```

## Rules에 반영된 Hook 기능

### safety.md
- bash-guard.py의 파괴적 명령 차단 규칙 반영
- file-protect.py의 민감 파일 보호 규칙 반영

### gsd-workflow.md
- session-start.sh의 GSD 상태 로드 규칙 반영
- post-turn-verify.sh의 검증 규칙 반영
HOOKGUIDEEOF
echo "  [+] Created HOOKS-MIGRATION.md guide"

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
| `memory` | Persistent agent memory (8 tools) |
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

echo "  Workflows: ${workflow_count}"
[ "$workflow_count" -ge 1 ] || echo "    [WARN] No workflows found"

echo "  Rules:     ${rules_count} (expected: 3)"
[ "$rules_count" -ge 3 ] || echo "    [WARN] Missing rules"

# Workflow quality check
echo ""
echo "[Workflow Quality]"
wf_too_short=0
wf_no_desc=0
for wf in "$ANTIGRAVITY/.agent/workflows/"*.md; do
    [ -f "$wf" ] || continue
    wf_name=$(basename "$wf")
    char_count=$(wc -c < "$wf" | tr -d ' ')
    if [ "$char_count" -gt 12000 ]; then
        echo "  [WARN] ${wf_name}: exceeds 12,000 char limit (${char_count})"
    fi
    if [ "$char_count" -lt 100 ]; then
        echo "  [WARN] ${wf_name}: too short (${char_count} chars)"
        wf_too_short=$((wf_too_short + 1))
    fi
    if ! grep -q "^description:" "$wf" 2>/dev/null; then
        echo "  [WARN] ${wf_name}: missing description"
        wf_no_desc=$((wf_no_desc + 1))
    fi
done
[ "$wf_too_short" -eq 0 ] && [ "$wf_no_desc" -eq 0 ] && echo "  [OK] All workflows have description and substantive content"

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
