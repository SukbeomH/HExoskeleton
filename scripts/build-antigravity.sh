#!/usr/bin/env bash
#
# Antigravity Build Script (v2)
# Converts boilerplate to Google Antigravity IDE format
#
# Design principles:
#   - Pure bash only (no external interpreter dependency)
#   - Dynamic content extraction from CLAUDE.md
#   - Non-standard frontmatter stripped from skills
#   - Claude-specific references transformed
#   - Agent files → Workflow files (meaningful content)
#
set -euo pipefail

# --- Configuration ---
BOILERPLATE="$(cd "$(dirname "$0")/.." && pwd)"
ANTIGRAVITY="${BOILERPLATE}/antigravity-boilerplate"
CLAUDE_MD="${BOILERPLATE}/CLAUDE.md"

echo "=== Antigravity Builder v2 ==="
echo "Source: ${BOILERPLATE}"
echo "Target: ${ANTIGRAVITY}"
echo ""

# ================================================================
# Utility Functions
# ================================================================

# Extract a ## section from a markdown file (content between ## Header and next ##)
# Usage: extract_section "file" "Section Name"
extract_section() {
    local file="$1"
    local section="$2"
    awk -v sec="$section" '
        BEGIN { found=0; printing=0 }
        /^## / {
            if (printing) exit
            if ($0 ~ "^## " sec) { found=1; printing=1 }
        }
        printing { print }
    ' "$file"
}

# Extract a ### subsection from stdin
# Usage: echo "$content" | extract_subsection "Subsection Name"
extract_subsection() {
    local section="$1"
    awk -v sec="$section" '
        BEGIN { found=0; printing=0 }
        /^### / {
            if (printing) exit
            if ($0 ~ "^### " sec) { found=1; printing=1 }
        }
        printing { print }
    '
}

# Remove non-standard YAML frontmatter fields from a SKILL.md
# Keeps only: name, description (Antigravity Agent Skills spec)
# Removes: version, trigger, allowed-tools (+ sub-list), model
sanitize_frontmatter() {
    local file="$1"
    awk '
        BEGIN { in_fm=0; skip_list=0 }
        NR==1 && /^---/ { in_fm=1; print; next }
        in_fm && /^---/ { in_fm=0; skip_list=0; print; next }
        in_fm {
            # Skip YAML list items that belong to a stripped field
            if (skip_list && /^  - /) { next }
            skip_list=0

            # Strip non-standard fields
            if (/^(version|trigger|allowed-tools|model):/) {
                if (/^allowed-tools:/) { skip_list=1 }
                next
            }
            print
        }
        !in_fm { print }
    ' "$file"
}

# Transform Claude-specific references in skill content
# - Remove <role>...</role> tags (preserve content between them)
# - Outside code blocks: Grep( → search(, Glob( → find_files(, Read( → read_file(
transform_tool_refs() {
    awk '
        BEGIN { in_code=0 }
        /^```/ { in_code = !in_code; print; next }
        {
            # Remove <role> and </role> tags (keep line content)
            gsub(/<\/?role>/, "")

            # Only transform tool refs outside code blocks
            if (!in_code) {
                gsub(/Grep\(/, "search(")
                gsub(/Glob\(/, "find_files(")
                gsub(/Read\(/, "read_file(")
            }
            print
        }
    '
}

# Split a large skill file into SKILL.md + references/full-guide.md
# Usage: split_large_skill "target_dir" max_lines
split_large_skill() {
    local target_dir="$1"
    local max_lines="${2:-500}"
    local skill_file="${target_dir}/SKILL.md"

    [ -f "$skill_file" ] || return 0

    local line_count
    line_count=$(wc -l < "$skill_file" | tr -d ' ')

    if [ "$line_count" -le "$max_lines" ]; then
        return 0
    fi

    mkdir -p "${target_dir}/references"

    # Move full content to references/full-guide.md
    cp "$skill_file" "${target_dir}/references/full-guide.md"

    # Truncate SKILL.md: keep frontmatter + first sections up to max_lines
    local truncated
    truncated=$(head -n "$max_lines" "$skill_file")

    # Append reference pointer
    {
        echo "$truncated"
        echo ""
        echo "> Full guide: [references/full-guide.md](references/full-guide.md)"
    } > "$skill_file"

    echo "    [split] $(basename "$target_dir"): ${line_count} → ${max_lines} lines + full-guide.md"
}

# ================================================================
# Phase 1: Directory Structure
# ================================================================
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

# ================================================================
# Phase 2: Skills Migration (sanitized)
# ================================================================
echo ""
echo "[Phase 2] Migrating skills to Antigravity format..."

for skill_dir in "$BOILERPLATE"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target_dir="$ANTIGRAVITY/.agent/skills/${skill_name}"
    mkdir -p "$target_dir"

    if [ -f "$skill_dir/SKILL.md" ]; then
        # Pipeline: sanitize frontmatter → transform tool refs → write
        sanitize_frontmatter "$skill_dir/SKILL.md" | transform_tool_refs > "$target_dir/SKILL.md"
        echo "  [+] ${skill_name}"
    fi

    # Copy subdirectories (scripts, examples, resources) — skip SKILL.md itself
    for subdir in "$skill_dir"*/; do
        [ -d "$subdir" ] || continue
        subdir_name=$(basename "$subdir")
        cp -r "$subdir" "$target_dir/"
        echo "    [+] ${skill_name}/${subdir_name}/"
    done

    # Split large skills (>500 lines)
    split_large_skill "$target_dir" 500
done

SKILLS_COUNT=$(find "$ANTIGRAVITY/.agent/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "  [=] Total skills: ${SKILLS_COUNT}"

# ================================================================
# Phase 3: Workflows from Agent files (pure bash)
# ================================================================
echo ""
echo "[Phase 3] Generating workflows from agent files..."

WORKFLOWS_COUNT=0
for agent_file in "$BOILERPLATE"/.claude/agents/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file" .md)

    # Extract description from frontmatter
    desc=$(awk '
        BEGIN { in_fm=0 }
        NR==1 && /^---/ { in_fm=1; next }
        in_fm && /^---/ { exit }
        in_fm && /^description:/ {
            sub(/^description: */, "")
            gsub(/"/, "")
            print
            exit
        }
    ' "$agent_file")

    if [ -z "$desc" ]; then
        desc="Workflow for ${agent_name//-/ }"
    fi

    # Extract body (everything after second ---)
    body=$(awk '
        BEGIN { fm_count=0 }
        /^---/ { fm_count++; if (fm_count==2) { getline; } next }
        fm_count >= 2 { print }
    ' "$agent_file")

    # Transform Claude-specific tool references in body
    body=$(echo "$body" | transform_tool_refs)

    # Build workflow file
    wf_path="$ANTIGRAVITY/.agent/workflows/${agent_name}.md"
    {
        echo "---"
        echo "description: \"${desc}\""
        echo "---"
        echo ""
        echo "$body"
    } > "$wf_path"

    # Enforce 12,000 char limit
    char_count=$(wc -c < "$wf_path" | tr -d ' ')
    if [ "$char_count" -gt 12000 ]; then
        head -c 11500 "$wf_path" > "${wf_path}.tmp"
        {
            cat "${wf_path}.tmp"
            echo ""
            echo "> *Truncated for 12,000 char limit*"
        } > "$wf_path"
        rm -f "${wf_path}.tmp"
        echo "  [+] ${agent_name}.md (truncated: ${char_count} → 12000)"
    else
        echo "  [+] ${agent_name}.md (${char_count} chars)"
    fi

    WORKFLOWS_COUNT=$((WORKFLOWS_COUNT + 1))
done

echo "  [=] Total workflows: ${WORKFLOWS_COUNT}"

# ================================================================
# Phase 4: Rules from CLAUDE.md (dynamic extraction)
# ================================================================
echo ""
echo "[Phase 4] Creating rules from CLAUDE.md..."

# Rule 1: agent-boundaries.md — from ## Agent Boundaries
{
    echo "---"
    echo 'description: "Agent behavioral boundaries — always do, ask first, never do"'
    echo "---"
    echo ""
    extract_section "$CLAUDE_MD" "Agent Boundaries"
} | transform_tool_refs > "$ANTIGRAVITY/.agent/rules/agent-boundaries.md"
echo "  [+] agent-boundaries.md"

# Rule 2: validation.md — from ## Validation
{
    echo "---"
    echo 'description: "Empirical validation rules — evidence-based verification"'
    echo "---"
    echo ""
    extract_section "$CLAUDE_MD" "Validation"
} > "$ANTIGRAVITY/.agent/rules/validation.md"
echo "  [+] validation.md"

# Rule 3: gsd-workflow.md — from ## Architecture + GSD cycle summary
{
    echo "---"
    echo 'description: "GSD workflow rules — architecture principles and execution cycle"'
    echo "---"
    echo ""
    extract_section "$CLAUDE_MD" "Architecture" | transform_tool_refs
    echo ""
    echo "## GSD Cycle"
    echo ""
    echo "1. **SPEC.md** (Planning Lock) — Project specification"
    echo "2. **PLAN.md** — Implementation plans with atomic tasks"
    echo "3. **EXECUTE** — Execute with atomic commits"
    echo "4. **VERIFY** — Verify with empirical evidence"
} > "$ANTIGRAVITY/.agent/rules/gsd-workflow.md"
echo "  [+] gsd-workflow.md"

# Rule 4: memory-protocol.md — from ## Memory Protocol
{
    echo "---"
    echo 'description: "File-based memory protocol — search, store, and recall patterns"'
    echo "---"
    echo ""
    extract_section "$CLAUDE_MD" "Memory Protocol" | transform_tool_refs
} > "$ANTIGRAVITY/.agent/rules/memory-protocol.md"
echo "  [+] memory-protocol.md"

RULES_COUNT=$(find "$ANTIGRAVITY/.agent/rules" -name "*.md" | wc -l | tr -d ' ')
echo "  [=] Total rules: ${RULES_COUNT}"

# ================================================================
# Phase 5: GEMINI.md Generation
# ================================================================
echo ""
echo "[Phase 5] Generating GEMINI.md..."

{
    cat << 'GEMINIHEADER'
# GEMINI.md

This file provides guidance to Antigravity IDE agents when working with code in this repository.

GEMINIHEADER

    # Project Overview (transformed)
    extract_section "$CLAUDE_MD" "Project Overview" | sed \
        -e 's/Claude Code/Antigravity/g' \
        -e 's/네이티브 Claude Code 도구(Grep, Glob, Read)/에이전트 내장 도구/g'

    echo ""

    # Architecture (transformed)
    extract_section "$CLAUDE_MD" "Architecture" | sed \
        -e 's/Claude Code/Antigravity/g' \
        -e 's/네이티브 Antigravity 도구(Grep, Glob, Read)/에이전트 내장 검색 도구/g' \
        -e 's/네이티브 Antigravity 도구만/에이전트 내장 도구만/g' \
        -e 's/\.claude\/hooks\//scripts\//g'

    echo ""

    # Repository Layout (.agent/ structure)
    cat << 'LAYOUT'
## Repository Layout

- **.agent/** — Agent configuration (Antigravity format):
  - `skills/` — Modular skill definitions (16 skills, SKILL.md format)
  - `workflows/` — Workflow commands (triggered via `/` commands)
  - `rules/` — Always-on passive rules (4 rule files)
- **.gsd/** — GSD documents and context management:
  - `SPEC.md`, `PLAN.md`, `DECISIONS.md`, `STATE.md` — Core working docs
  - `PATTERNS.md` — Distilled learnings for fresh sessions (2KB limit)
  - `memories/` — File-based agent memory (14 type directories)
  - `reports/`, `research/`, `archive/` — Secondary documents
  - `templates/` — Document templates
- **scripts/** — Utility scripts (memory system, scaffolding)

LAYOUT

    # Memory Protocol (transformed)
    extract_section "$CLAUDE_MD" "Memory Protocol" | transform_tool_refs | sed \
        -e 's/\.claude\/skills\//.agent\/skills\//g' \
        -e 's/\.claude\/hooks\//scripts\//g'

    echo ""

    # Validation
    extract_section "$CLAUDE_MD" "Validation"

    echo ""

    # Agent Boundaries (transformed)
    extract_section "$CLAUDE_MD" "Agent Boundaries" | transform_tool_refs

} > "$ANTIGRAVITY/GEMINI.md"
echo "  [+] GEMINI.md ($(wc -c < "$ANTIGRAVITY/GEMINI.md" | tr -d ' ') chars)"

# ================================================================
# Phase 6: Selective Script Copy (4 scripts only)
# ================================================================
echo ""
echo "[Phase 6] Copying utility scripts (selective)..."

# Copy only standalone-capable scripts
SCRIPT_COUNT=0
for script in md-recall-memory.sh md-store-memory.sh _json_parse.sh; do
    src="$BOILERPLATE/.claude/hooks/$script"
    if [ -f "$src" ]; then
        cp "$src" "$ANTIGRAVITY/scripts/"
        chmod +x "$ANTIGRAVITY/scripts/$script"
        echo "  [+] ${script}"
        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    else
        echo "  [WARN] ${script} not found"
    fi
done

# scaffold-gsd.sh — inline generation (same as before)
cat > "$ANTIGRAVITY/scripts/scaffold-gsd.sh" << 'SCAFFOLDEOF'
#!/usr/bin/env bash
#
# scaffold-gsd.sh - Initialize GSD document structure
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/gsd"
TARGET="${1:-.gsd}"

echo "Scaffolding GSD documents to ${TARGET}..."

mkdir -p "$TARGET"/{templates,examples,archive,reports,research,memories}

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
echo "  [+] scaffold-gsd.sh (generated)"
SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
echo "  [=] Total scripts: ${SCRIPT_COUNT}"

# ================================================================
# Phase 7: GSD Templates
# ================================================================
echo ""
echo "[Phase 7] Copying GSD templates..."

# Templates
cp "$BOILERPLATE"/.gsd/templates/*.md "$ANTIGRAVITY/templates/gsd/templates/" 2>/dev/null || true
cp "$BOILERPLATE"/.gsd/templates/*.yaml "$ANTIGRAVITY/templates/gsd/templates/" 2>/dev/null || true
TEMPLATES_COUNT=$(find "$ANTIGRAVITY/templates/gsd/templates" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  [+] ${TEMPLATES_COUNT} templates"

# Examples
cp "$BOILERPLATE"/.gsd/examples/*.md "$ANTIGRAVITY/templates/gsd/examples/" 2>/dev/null || true
EXAMPLES_COUNT=$(find "$ANTIGRAVITY/templates/gsd/examples" -type f 2>/dev/null | wc -l | tr -d ' ')
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

# ================================================================
# Phase 8: README
# ================================================================
echo ""
echo "[Phase 8] Creating README..."

cat > "$ANTIGRAVITY/README.md" << 'READMEEOF'
# Antigravity Boilerplate

AI agent development boilerplate for **Google Antigravity IDE**.

**No external dependencies** — pure bash scripts + markdown files.

## Quick Start

1. **Open in Antigravity**
   ```bash
   antigravity .
   ```

2. **Initialize GSD Documents**
   ```bash
   bash scripts/scaffold-gsd.sh
   ```

## Directory Structure

```
.agent/
├── skills/          # 16 AI skills (SKILL.md format)
│   ├── planner/     # Planning skill
│   ├── executor/    # Execution skill
│   └── ...
├── workflows/       # 14 workflow commands (from agent orchestrations)
│   ├── planner.md   # /planner command
│   ├── executor.md  # /executor command
│   └── ...
└── rules/           # 4 always-on passive rules
    ├── agent-boundaries.md
    ├── validation.md
    ├── gsd-workflow.md
    └── memory-protocol.md

templates/gsd/       # GSD document templates
scripts/             # Utility scripts (memory system)
GEMINI.md            # Project instructions for Antigravity agents
```

## Memory System (Pure Bash)

File-based memory system with no external dependencies:

```bash
# Store memory
bash scripts/md-store-memory.sh "Title" "Content" "tags" "type"

# Recall memory
bash scripts/md-recall-memory.sh "query" "." 5 compact
```

14 memory types: `architecture-decision`, `root-cause`, `session-summary`, etc.

## Skills (16)

| Skill | Description |
|-------|-------------|
| `planner` | Creates executable phase plans |
| `executor` | Executes plans with atomic commits |
| `verifier` | Verifies work with empirical evidence |
| `debugger` | Systematic debugging |
| `impact-analysis` | Change impact analysis |
| `arch-review` | Architecture review |
| `codebase-mapper` | Codebase structure mapping |
| `plan-checker` | Plan validation |
| `context-health-monitor` | Context complexity monitoring |
| `bootstrap` | Project initialization |
| `empirical-validation` | Proof-based validation |
| `memory-protocol` | Memory search/store protocol |
| `commit` | Conventional emoji commits |
| `create-pr` | Pull request creation |
| `pr-review` | Multi-persona code review |
| `clean` | Code quality tools (shellcheck) |

## Workflows (14)

Workflows in `.agent/workflows/*.md` contain orchestration logic extracted from agent definitions.

| Command | Description |
|---------|-------------|
| `/planner` | Create implementation plan |
| `/executor` | Execute planned work |
| `/verifier` | Verify completed work |
| `/debugger` | Systematic debugging |
| `/codebase-mapper` | Map codebase structure |
| `/commit` | Create conventional commit |

## Rules (4)

Rules in `.agent/rules/*.md` are always-on passive guidelines.

| Rule | Purpose |
|------|---------|
| `agent-boundaries.md` | Always/Ask First/Never behavioral rules |
| `validation.md` | Empirical evidence requirements |
| `gsd-workflow.md` | Architecture + GSD cycle |
| `memory-protocol.md` | Memory search/store protocol |

## GSD Methodology

Get Shit Done workflow:

1. **SPEC.md** — Define project specification
2. **PLAN.md** — Create implementation plans
3. **EXECUTE** — Execute with atomic commits
4. **VERIFY** — Verify with empirical evidence

## Migration from Claude Code

| Claude Code | Antigravity |
|-------------|-------------|
| `CLAUDE.md` | `GEMINI.md` + `.agent/rules/*.md` |
| `.claude/skills/` | `.agent/skills/` |
| `.claude/agents/` | `.agent/workflows/` |
| Claude Hooks | Not needed (rules replace hooks) |

## License

MIT
READMEEOF
echo "  [+] README.md"

# ================================================================
# Phase 9: Verification
# ================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Phase 9] Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

errors=0
warnings=0

# --- Structure check ---
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

# --- Counts ---
echo ""
echo "[Counts]"
skill_count=$(find "$ANTIGRAVITY/.agent/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
workflow_count=$(find "$ANTIGRAVITY/.agent/workflows" -name "*.md" | wc -l | tr -d ' ')
rules_count=$(find "$ANTIGRAVITY/.agent/rules" -name "*.md" | wc -l | tr -d ' ')

echo "  Skills:    ${skill_count} (expected: 16)"
[ "$skill_count" -ge 16 ] || { echo "    [WARN] Low skill count"; warnings=$((warnings + 1)); }

echo "  Workflows: ${workflow_count} (expected: 14)"
[ "$workflow_count" -ge 14 ] || { echo "    [WARN] Low workflow count"; warnings=$((warnings + 1)); }

echo "  Rules:     ${rules_count} (expected: 4)"
[ "$rules_count" -ge 4 ] || { echo "    [WARN] Missing rules"; warnings=$((warnings + 1)); }

# --- Frontmatter compliance (check only within --- fences) ---
echo ""
echo "[Frontmatter Compliance]"
bad_fm=0
while IFS= read -r f; do
    # Extract only frontmatter lines (between first and second ---)
    fm_content=$(awk 'NR==1 && /^---/{in_fm=1; next} in_fm && /^---/{exit} in_fm{print}' "$f")
    for field in version trigger model allowed-tools; do
        if echo "$fm_content" | grep -q "^${field}:"; then
            echo "  [FAIL] $(echo "$f" | sed "s|$ANTIGRAVITY/||") contains '${field}:' in frontmatter"
            bad_fm=$((bad_fm + 1))
        fi
    done
done < <(find "$ANTIGRAVITY/.agent/skills" -name "SKILL.md")
if [ "$bad_fm" -eq 0 ]; then
    echo "  [OK] No non-standard frontmatter fields"
else
    errors=$((errors + bad_fm))
fi

# --- <role> tag check ---
echo ""
echo "[Claude-specific Tags]"
role_tags=0
while IFS= read -r f; do
    if grep -q "<role>\|</role>" "$f" 2>/dev/null; then
        echo "  [FAIL] $(echo "$f" | sed "s|$ANTIGRAVITY/||") contains <role> tag"
        role_tags=$((role_tags + 1))
    fi
done < <(find "$ANTIGRAVITY/.agent/skills" -name "SKILL.md")
if [ "$role_tags" -eq 0 ]; then
    echo "  [OK] No <role> tags found"
else
    errors=$((errors + role_tags))
fi

# --- 12,000 char limit ---
echo ""
echo "[Character Limits]"
over_limit=0
for f in "$ANTIGRAVITY"/.agent/workflows/*.md "$ANTIGRAVITY"/.agent/rules/*.md; do
    [ -f "$f" ] || continue
    chars=$(wc -c < "$f" | tr -d ' ')
    if [ "$chars" -gt 12000 ]; then
        echo "  [FAIL] $(basename "$f"): ${chars} chars (limit: 12,000)"
        over_limit=$((over_limit + 1))
    fi
done
if [ "$over_limit" -eq 0 ]; then
    echo "  [OK] All workflows/rules within 12,000 char limit"
else
    errors=$((errors + over_limit))
fi

# --- GEMINI.md existence ---
echo ""
echo "[GEMINI.md]"
if [ -f "$ANTIGRAVITY/GEMINI.md" ]; then
    echo "  [OK] GEMINI.md exists ($(wc -c < "$ANTIGRAVITY/GEMINI.md" | tr -d ' ') chars)"
else
    echo "  [FAIL] GEMINI.md missing"
    errors=$((errors + 1))
fi

# --- No external interpreter calls in this script ---
echo ""
echo "[Pure Bash]"
# Verify no external interpreter (py/ruby/node) invocations exist
if grep -qE '^\s*(python3?|ruby|node) |[|&;]\s*(python3?|ruby|node) |\$\((python3?|ruby|node)' "$0" 2>/dev/null; then
    echo "  [FAIL] Found external interpreter invocations in build script"
    errors=$((errors + 1))
else
    echo "  [OK] Pure bash — no external interpreter calls"
fi

# --- Skill description check ---
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
if [ "$missing_desc" -eq 0 ]; then
    echo "  [OK] All skills have descriptions"
else
    warnings=$((warnings + missing_desc))
fi

# --- Workflow quality check ---
echo ""
echo "[Workflow Quality]"
wf_too_short=0
wf_no_desc=0
for wf in "$ANTIGRAVITY/.agent/workflows/"*.md; do
    [ -f "$wf" ] || continue
    wf_name=$(basename "$wf")
    char_count=$(wc -c < "$wf" | tr -d ' ')
    if [ "$char_count" -lt 100 ]; then
        echo "  [WARN] ${wf_name}: too short (${char_count} chars)"
        wf_too_short=$((wf_too_short + 1))
    fi
    if ! grep -q "^description:" "$wf" 2>/dev/null; then
        echo "  [WARN] ${wf_name}: missing description"
        wf_no_desc=$((wf_no_desc + 1))
    fi
done
if [ "$wf_too_short" -eq 0 ] && [ "$wf_no_desc" -eq 0 ]; then
    echo "  [OK] All workflows have description and substantive content"
else
    warnings=$((warnings + wf_too_short + wf_no_desc))
fi

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $errors -eq 0 ]; then
    echo "BUILD SUCCESSFUL"
    [ $warnings -gt 0 ] && echo "  (${warnings} warning(s))"
    echo ""
    echo "Antigravity workspace created at: $ANTIGRAVITY"
    echo ""
    echo "To use:"
    echo "  1. Open $ANTIGRAVITY in Antigravity IDE"
    echo "  2. Run: bash scripts/scaffold-gsd.sh"
    echo ""
    echo "Or copy to an existing project:"
    echo "  cp -r $ANTIGRAVITY/.agent /path/to/project/"
    echo "  cp $ANTIGRAVITY/GEMINI.md /path/to/project/"
else
    echo "BUILD COMPLETED WITH $errors ERROR(S), $warnings WARNING(S)"
    exit 1
fi
