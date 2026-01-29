#!/usr/bin/env bash

# Verify system prerequisites for the boilerplate project.
# Checks required tools, MCP dependencies, environment files, and optional extras.
# Usage: bash scripts/bootstrap.sh
#
# Exit 0: All required checks pass
# Exit 1: One or more required checks failed

set -o errexit
set -o nounset
set -o pipefail

# ─────────────────────────────────────────────────────
# Counters
# ─────────────────────────────────────────────────────

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
REQUIRED_FAIL=0

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

report_pass() {
    printf "  [PASS] %-20s %s\n" "$1" "$2"
    ((PASS_COUNT++)) || true
}

report_fail() {
    printf "  [FAIL] %-20s %s\n" "$1" "$2"
    ((FAIL_COUNT++)) || true
    ((REQUIRED_FAIL++)) || true
}

report_warn() {
    printf "  [WARN] %-20s %s\n" "$1" "$2"
    ((WARN_COUNT++)) || true
}

report_skip() {
    printf "  [SKIP] %-20s %s\n" "$1" "$2"
    ((SKIP_COUNT++)) || true
}

# ─────────────────────────────────────────────────────
# System Prerequisites (Required)
# ─────────────────────────────────────────────────────

echo "================================================================"
echo " BOOTSTRAP: System Prerequisites Check"
echo "================================================================"
echo ""
echo "--- Required ---"

# Node.js >= 18
if command -v node &>/dev/null; then
    NODE_VER=$(node --version | sed 's/^v//')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
    if [[ "$NODE_MAJOR" -ge 18 ]]; then
        report_pass "Node.js" "v${NODE_VER}"
    else
        report_fail "Node.js" "v${NODE_VER} (>= 18 required)"
    fi
else
    report_fail "Node.js" "not found — https://nodejs.org/"
fi

# npm
if command -v npm &>/dev/null; then
    NPM_VER=$(npm --version)
    report_pass "npm" "v${NPM_VER}"
else
    report_fail "npm" "not found — https://nodejs.org/"
fi

# uv
if command -v uv &>/dev/null; then
    UV_VER=$(uv --version 2>/dev/null | awk '{print $2}')
    report_pass "uv" "${UV_VER}"
else
    report_fail "uv" "not found — curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# pipx
if command -v pipx &>/dev/null; then
    PIPX_VER=$(pipx --version 2>/dev/null)
    report_pass "pipx" "${PIPX_VER}"
else
    report_fail "pipx" "not found — brew install pipx && pipx ensurepath"
fi

# Python >= 3.11
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version | awk '{print $2}')
    PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
    if [[ "$PY_MINOR" -ge 11 ]]; then
        report_pass "Python" "${PY_VER}"
    else
        report_fail "Python" "${PY_VER} (>= 3.11 required)"
    fi
else
    report_fail "Python" "not found — https://www.python.org/"
fi

# memorygraph binary
if command -v memorygraph &>/dev/null; then
    MG_VER=$(memorygraph --version 2>/dev/null || echo "installed")
    report_pass "memorygraph" "${MG_VER}"
else
    report_fail "memorygraph" "not found — pipx install memorygraphMCP"
fi

# npx (for code-graph-rag)
if command -v npx &>/dev/null; then
    report_pass "npx" "available"
else
    report_fail "npx" "not found — install Node.js"
fi

# ─────────────────────────────────────────────────────
# Environment (Warn)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Environment ---"

if [[ -f .env ]]; then
    report_pass ".env" "exists"
else
    report_warn ".env" "missing — will be created from .env.example"
fi

if [[ -d .venv ]]; then
    report_pass ".venv" "exists"
else
    report_warn ".venv" "missing — will be created by uv sync"
fi

# ─────────────────────────────────────────────────────
# Context Structure (Auto-create)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Context Structure ---"

# Required .gsd folders
for dir in reports research archive; do
    if [[ -d ".gsd/$dir" ]]; then
        report_pass ".gsd/$dir/" "exists"
    else
        mkdir -p ".gsd/$dir"
        report_pass ".gsd/$dir/" "created"
    fi
done

# Context management files
if [[ -f ".gsd/PATTERNS.md" ]]; then
    PATTERNS_SIZE=$(wc -c < ".gsd/PATTERNS.md" | tr -d ' ')
    report_pass "PATTERNS.md" "${PATTERNS_SIZE}B"
else
    if [[ -f ".gsd/templates/patterns.md" ]]; then
        cp ".gsd/templates/patterns.md" ".gsd/PATTERNS.md"
        report_pass "PATTERNS.md" "initialized from template"
    else
        report_warn "PATTERNS.md" "missing — no template found"
    fi
fi

if [[ -f ".gsd/context-config.yaml" ]]; then
    report_pass "context-config.yaml" "exists"
else
    if [[ -f ".gsd/templates/context-config.yaml" ]]; then
        cp ".gsd/templates/context-config.yaml" ".gsd/context-config.yaml"
        report_pass "context-config.yaml" "initialized from template"
    else
        report_warn "context-config.yaml" "missing — no template found"
    fi
fi

# ─────────────────────────────────────────────────────
# Prompt Patch (Optional)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Prompt Patch ---"

if command -v claude &>/dev/null; then
    CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
    report_pass "claude CLI" "v${CLAUDE_VER}"

    if [[ -d "claude-code-tips/system-prompt/${CLAUDE_VER}" ]]; then
        report_pass "patch files" "claude-code-tips/system-prompt/${CLAUDE_VER}/"
        if [[ -d .patch-workspace ]]; then
            report_pass ".patch-workspace" "patched CLI installed"
        else
            report_warn ".patch-workspace" "not found — run: make patch-prompt"
        fi
    else
        report_skip "patch files" "no patches for v${CLAUDE_VER}"
    fi
else
    report_skip "claude CLI" "not found — prompt patching unavailable"
fi

# ─────────────────────────────────────────────────────
# Index (Warn)
# ─────────────────────────────────────────────────────

echo ""
echo "--- Index ---"

if [[ -d .code-graph-rag ]]; then
    report_pass ".code-graph-rag/" "exists"
else
    report_warn ".code-graph-rag/" "missing — will be created by indexing"
fi

# ─────────────────────────────────────────────────────
# Optional
# ─────────────────────────────────────────────────────

echo ""
echo "--- Optional ---"

if command -v gh &>/dev/null; then
    GH_VER=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
    report_pass "gh CLI" "v${GH_VER}"
else
    report_skip "gh CLI" "not found — brew install gh"
fi

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
printf " PASS: %d  |  FAIL: %d  |  WARN: %d  |  SKIP: %d\n" \
    "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"

if [[ "$REQUIRED_FAIL" -gt 0 ]]; then
    echo " RESULT: FAILED — ${REQUIRED_FAIL} required check(s) failed"
    echo "================================================================"
    exit 1
else
    echo " RESULT: ALL REQUIRED CHECKS PASSED"
    echo "================================================================"
    exit 0
fi
