#!/usr/bin/env bash
#
# verify-self-configure.sh — Self-Configure 배포 모델 검증
# Usage: bash scripts/verify-self-configure.sh [--layer1|--layer2|--all]
#
# Layer 1: 정적 검증 (링크, 경로, 인덱스 일관성)
# Layer 2: 시뮬레이션 (빈 프로젝트에 setup 적용 후 구조 검증)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { printf "  [PASS] %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  [FAIL] %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf "  [WARN] %s\n" "$1"; WARN=$((WARN + 1)); }

# ═══════════════════════════════════════════════════════
# Layer 1: 정적 검증
# ═══════════════════════════════════════════════════════
layer1() {
    echo "═══════════════════════════════════════════════════"
    echo " Layer 1: Static Validation"
    echo "═══════════════════════════════════════════════════"
    echo ""

    # 1.1 Core files existence
    echo "--- 1.1 Core Files ---"
    for f in llms.txt AGENTS.md GEMINI.md CLAUDE.md .hxsk/prompts/setup.md; do
        if [ -f "$REPO_ROOT/$f" ]; then
            pass "$f exists"
        else
            fail "$f MISSING"
        fi
    done

    # 1.2 INDEX files
    echo ""
    echo "--- 1.2 INDEX Files ---"
    for f in .hxsk/skills/INDEX.md .hxsk/hooks/INDEX.md .hxsk/agents/INDEX.md; do
        if [ -f "$REPO_ROOT/$f" ]; then
            pass "$f exists"
        else
            fail "$f MISSING"
        fi
    done

    # 1.3 llms.txt link validity
    echo ""
    echo "--- 1.3 llms.txt Links ---"
    # Extract markdown links: [text](path)
    while read -r link; do
        # Skip non-path entries (descriptions, Korean text, spaces)
        [[ "$link" == *" "* ]] && continue
        [[ "$link" == http* ]] && continue
        # Skip entries without / or . (likely description fragments)
        [[ "$link" != *"/"* && "$link" != *"."* ]] && continue
        if [ -e "$REPO_ROOT/$link" ]; then
            pass "llms.txt → $link"
        else
            fail "llms.txt → $link NOT FOUND"
        fi
    done < <(grep -oE '\([^)]+\)' "$REPO_ROOT/llms.txt" | tr -d '()')

    # 1.4 Skills INDEX vs actual files
    echo ""
    echo "--- 1.4 Skills INDEX Consistency ---"
    SKILL_DIRS=$(find "$REPO_ROOT/.hxsk/skills" -mindepth 1 -maxdepth 1 -type d ! -name '_*' | sort)
    SKILL_COUNT=$(echo "$SKILL_DIRS" | grep -c '.' 2>/dev/null || echo "0")
    INDEX_SKILLS=$(grep -oE '`skills/[^`]+`' "$REPO_ROOT/.hxsk/skills/INDEX.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$SKILL_COUNT" -eq "$INDEX_SKILLS" ]; then
        pass "Skills: $SKILL_COUNT dirs = $INDEX_SKILLS INDEX entries"
    else
        fail "Skills mismatch: $SKILL_COUNT dirs vs $INDEX_SKILLS INDEX entries"
    fi

    # Check each skill dir has a SKILL.md
    for d in $SKILL_DIRS; do
        name=$(basename "$d")
        if [ -f "$d/SKILL.md" ]; then
            pass "skills/$name/SKILL.md exists"
        else
            fail "skills/$name/SKILL.md MISSING"
        fi
    done

    # 1.5 Agents INDEX vs actual files
    echo ""
    echo "--- 1.5 Agents INDEX Consistency ---"
    AGENT_FILES=$(find "$REPO_ROOT/.hxsk/agents" -name '*.md' ! -name 'INDEX.md' | sort)
    AGENT_COUNT=$(echo "$AGENT_FILES" | grep -c '.' 2>/dev/null || echo "0")
    INDEX_AGENTS=$(grep -oE '`agents/[^`]+`' "$REPO_ROOT/.hxsk/agents/INDEX.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$AGENT_COUNT" -eq "$INDEX_AGENTS" ]; then
        pass "Agents: $AGENT_COUNT files = $INDEX_AGENTS INDEX entries"
    else
        fail "Agents mismatch: $AGENT_COUNT files vs $INDEX_AGENTS INDEX entries"
    fi

    # 1.6 Hooks INDEX vs actual files
    echo ""
    echo "--- 1.6 Hooks INDEX Consistency ---"
    HOOK_FILES=$(find "$REPO_ROOT/.hxsk/hooks" -type f \( -name '*.sh' -o -name '*.py' \) | sort)
    HOOK_COUNT=$(echo "$HOOK_FILES" | grep -c '.' 2>/dev/null || echo "0")
    INDEX_HOOKS=$(grep -oE '`hooks/[^`]+`' "$REPO_ROOT/.hxsk/hooks/INDEX.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$HOOK_COUNT" -eq "$INDEX_HOOKS" ]; then
        pass "Hooks: $HOOK_COUNT files = $INDEX_HOOKS INDEX entries"
    else
        fail "Hooks mismatch: $HOOK_COUNT files vs $INDEX_HOOKS INDEX entries"
    fi

    # 1.7 settings.json hook paths
    echo ""
    echo "--- 1.7 settings.json Hook Paths ---"
    if [ -f "$REPO_ROOT/.claude/settings.json" ]; then
        STALE_PATHS=$(grep -c '\.claude/hooks/' "$REPO_ROOT/.claude/settings.json" 2>/dev/null | tr -d '[:space:]' || echo "0")
        HXSK_PATHS=$(grep -c '\.hxsk/hooks/' "$REPO_ROOT/.claude/settings.json" 2>/dev/null || echo "0")

        if [ "$STALE_PATHS" -eq 0 ]; then
            pass "No stale .claude/hooks/ paths in settings.json"
        else
            fail "$STALE_PATHS stale .claude/hooks/ paths in settings.json"
        fi

        if [ "$HXSK_PATHS" -gt 0 ]; then
            pass "$HXSK_PATHS .hxsk/hooks/ paths in settings.json"
        else
            fail "No .hxsk/hooks/ paths in settings.json"
        fi

        # Check each referenced hook file exists
        while read -r hookpath; do
            if [ -f "$REPO_ROOT/$hookpath" ]; then
                pass "settings.json → $hookpath"
            else
                fail "settings.json → $hookpath NOT FOUND"
            fi
        done < <(grep -oE '\.hxsk/hooks/[^"]+' "$REPO_ROOT/.claude/settings.json" | sort -u)
    else
        fail ".claude/settings.json not found"
    fi

    # 1.8 CLAUDE.md imports AGENTS.md
    echo ""
    echo "--- 1.8 CLAUDE.md Structure ---"
    if grep -q '@AGENTS.md' "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
        pass "CLAUDE.md imports @AGENTS.md"
    else
        fail "CLAUDE.md does not import @AGENTS.md"
    fi

    CLAUDE_LINES=$(wc -l < "$REPO_ROOT/CLAUDE.md" | tr -d ' ')
    if [ "$CLAUDE_LINES" -le 120 ]; then
        pass "CLAUDE.md: $CLAUDE_LINES lines (≤120)"
    else
        fail "CLAUDE.md: $CLAUDE_LINES lines (>120)"
    fi

    # 1.9 No build scripts remaining
    echo ""
    echo "--- 1.9 Build Artifacts Removed ---"
    for f in scripts/build-plugin.sh scripts/build-antigravity.sh scripts/build-opencode.sh scripts/build-common.sh; do
        if [ -f "$REPO_ROOT/$f" ]; then
            fail "$f still exists"
        else
            pass "$f removed"
        fi
    done

    for f in release-please-config.json .release-please-manifest.json .github/workflows/release-plugin.yml; do
        if [ -f "$REPO_ROOT/$f" ]; then
            fail "$f still exists"
        else
            pass "$f removed"
        fi
    done
}

# ═══════════════════════════════════════════════════════
# Layer 2: 시뮬레이션
# ═══════════════════════════════════════════════════════
layer2() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo " Layer 2: Simulation (setup.md dry-run)"
    echo "═══════════════════════════════════════════════════"
    echo ""

    # Create temp project
    SIM_DIR=$(mktemp -d)
    trap 'rm -rf "$SIM_DIR"' EXIT
    echo "  Temp project: $SIM_DIR"
    echo ""

    # Simulate setup.md steps manually
    echo "--- 2.1 Step 2: Agent Instruction File ---"
    cp "$REPO_ROOT/CLAUDE.md" "$SIM_DIR/CLAUDE.md"
    if [ -f "$SIM_DIR/CLAUDE.md" ]; then
        pass "CLAUDE.md copied to project"
    else
        fail "CLAUDE.md copy failed"
    fi

    echo ""
    echo "--- 2.2 Step 3: HXSK Document Structure ---"
    mkdir -p "$SIM_DIR/.hxsk"
    # Create minimal working docs
    echo "# SPEC" > "$SIM_DIR/.hxsk/SPEC.md"
    echo "# STATE" > "$SIM_DIR/.hxsk/STATE.md"
    echo "# PATTERNS" > "$SIM_DIR/.hxsk/PATTERNS.md"

    for doc in SPEC.md STATE.md PATTERNS.md; do
        if [ -f "$SIM_DIR/.hxsk/$doc" ]; then
            pass ".hxsk/$doc created"
        else
            fail ".hxsk/$doc creation failed"
        fi
    done

    # Copy templates
    if [ -d "$REPO_ROOT/.hxsk/templates" ]; then
        cp -r "$REPO_ROOT/.hxsk/templates" "$SIM_DIR/.hxsk/templates"
        T_COUNT=$(find "$SIM_DIR/.hxsk/templates" -name '*.md' | wc -l | tr -d ' ')
        pass "Templates copied: $T_COUNT files"
    else
        fail "Source templates not found"
    fi

    echo ""
    echo "--- 2.3 Step 4: Skill Installation ---"
    # Install 4 recommended skills
    for skill in planner executor verifier memory-protocol; do
        mkdir -p "$SIM_DIR/.claude/skills/$skill"
        if [ -f "$REPO_ROOT/.hxsk/skills/$skill/SKILL.md" ]; then
            cp "$REPO_ROOT/.hxsk/skills/$skill/SKILL.md" "$SIM_DIR/.claude/skills/$skill/SKILL.md"
            pass "Skill installed: $skill"
        else
            fail "Skill source missing: $skill"
        fi
    done

    echo ""
    echo "--- 2.4 Step 5: Hook Installation (Claude Code) ---"
    mkdir -p "$SIM_DIR/.hxsk/hooks"
    # Copy essential hooks
    for hook in session-start.sh file-protect.py bash-guard.py stop-context-save.sh _json_parse.sh; do
        if [ -f "$REPO_ROOT/.hxsk/hooks/$hook" ]; then
            cp "$REPO_ROOT/.hxsk/hooks/$hook" "$SIM_DIR/.hxsk/hooks/$hook"
            pass "Hook installed: $hook"
        else
            fail "Hook source missing: $hook"
        fi
    done

    # Create settings.json with hook references
    mkdir -p "$SIM_DIR/.claude"
    cat > "$SIM_DIR/.claude/settings.json" << 'SETTINGSEOF'
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|resume", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/session-start.sh", "timeout": 10}]}],
    "PreToolUse": [
      {"matcher": "Edit|Write|Read", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/file-protect.py", "timeout": 5}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/bash-guard.py", "timeout": 5}]}
    ]
  }
}
SETTINGSEOF
    pass "settings.json created with hook references"

    echo ""
    echo "--- 2.5 Final Structure Check ---"
    # Verify final project structure
    EXPECTED_DIRS=".claude .hxsk .hxsk/hooks .hxsk/templates .claude/skills"
    for d in $EXPECTED_DIRS; do
        if [ -d "$SIM_DIR/$d" ]; then
            pass "Dir: $d/"
        else
            fail "Dir MISSING: $d/"
        fi
    done

    EXPECTED_FILES="CLAUDE.md .claude/settings.json .hxsk/SPEC.md .hxsk/STATE.md .hxsk/PATTERNS.md"
    for f in $EXPECTED_FILES; do
        if [ -f "$SIM_DIR/$f" ]; then
            pass "File: $f"
        else
            fail "File MISSING: $f"
        fi
    done

    # Verify hook paths in settings.json point to real files
    echo ""
    echo "--- 2.6 Hook Path Resolution ---"
    while read -r hookpath; do
        if [ -f "$SIM_DIR/$hookpath" ]; then
            pass "Hook resolves: $hookpath"
        else
            fail "Hook NOT FOUND: $hookpath"
        fi
    done < <(grep -oE '\.hxsk/hooks/[^"]+' "$SIM_DIR/.claude/settings.json")

    # Cleanup (also handled by EXIT trap)
    rm -rf "$SIM_DIR"
    echo ""
    echo "  Temp project cleaned up."
}

# ═══════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════
summary() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    printf " PASS: %d  |  FAIL: %d  |  WARN: %d\n" "$PASS" "$FAIL" "$WARN"

    if [ "$FAIL" -eq 0 ]; then
        echo " RESULT: ALL CHECKS PASSED"
    else
        echo " RESULT: $FAIL FAILURE(S) — review above"
    fi
    echo "═══════════════════════════════════════════════════"

    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

# ═══════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════
cd "$REPO_ROOT"
MODE="${1:---all}"

case "$MODE" in
    --layer1) layer1; summary ;;
    --layer2) layer2; summary ;;
    --all)    layer1; layer2; summary ;;
    *)        echo "Usage: $0 [--layer1|--layer2|--all]"; exit 1 ;;
esac
