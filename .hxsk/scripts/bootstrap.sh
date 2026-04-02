#!/usr/bin/env bash

# Idempotent bootstrap convergence engine for HExoskeleton.
# Detects fresh install / verify / update mode via .hxsk/.bootstrap-version.
# Checks required tools, environment, context structure, and reports delta.
#
# Usage: bash .hxsk/scripts/bootstrap.sh
#
# Exit 0: All required checks pass
# Exit 1: One or more required checks failed

set -o errexit
set -o nounset
set -o pipefail

# ─────────────────────────────────────────────────────
# Version & Mode Detection
# ─────────────────────────────────────────────────────

BOOTSTRAP_VERSION="5.2.0"
VERSION_FILE=".hxsk/.bootstrap-version"
HOOK_DIR=".hxsk/hooks"
MODE="fresh"
OLD_VERSION=""

if [[ -f "$VERSION_FILE" ]]; then
    # YAML format: "version: X.X.X" — grep || true로 errexit 방지
    OLD_VERSION=$(grep '^version:' "$VERSION_FILE" 2>/dev/null | sed 's/^version: *//' || true)
    # 정규화: quotes, whitespace, CR 모두 제거
    OLD_VERSION=$(echo "$OLD_VERSION" | tr -d '"[:space:]')
    if [[ -z "$OLD_VERSION" ]]; then
        # Fallback: 파일 첫 줄이 버전 번호일 수 있음 (비표준 포맷)
        OLD_VERSION=$(head -1 "$VERSION_FILE" 2>/dev/null | tr -d '"[:space:]' || true)
    fi
    if [[ "$OLD_VERSION" = "$BOOTSTRAP_VERSION" ]]; then
        MODE="verify"
    elif [[ -n "$OLD_VERSION" ]]; then
        MODE="update"
    else
        # 파싱 실패 — fresh로 취급
        MODE="fresh"
    fi
fi

# ─────────────────────────────────────────────────────
# Counters
# ─────────────────────────────────────────────────────

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
NEW_COUNT=0
UPDATED_COUNT=0
REQUIRED_FAIL=0

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

report_pass() {
    printf "  [PASS]    %-20s %s\n" "$1" "$2"
    ((PASS_COUNT++)) || true
}

report_fail() {
    printf "  [FAIL]    %-20s %s\n" "$1" "$2"
    ((FAIL_COUNT++)) || true
    ((REQUIRED_FAIL++)) || true
}

report_warn() {
    printf "  [WARN]    %-20s %s\n" "$1" "$2"
    ((WARN_COUNT++)) || true
}

report_skip() {
    printf "  [SKIP]    %-20s %s\n" "$1" "$2"
    ((SKIP_COUNT++)) || true
}

report_new() {
    printf "  [NEW]     %-20s %s\n" "$1" "$2"
    ((NEW_COUNT++)) || true
    report_context "$1"
}

report_updated() {
    printf "  [UPDATED] %-20s %s\n" "$1" "$2"
    ((UPDATED_COUNT++)) || true
    report_context "$1"
}

report_ok() {
    printf "  [OK]      %-20s %s\n" "$1" "$2"
    ((PASS_COUNT++)) || true
}

# 2-hop 컨텍스트: [NEW] 또는 [UPDATED] 항목에 관련 컴포넌트 표시
report_context() {
    local component="$1"
    if [[ -x "$HOOK_DIR/md-recall-memory.sh" ]]; then
        local related
        related=$("$HOOK_DIR/md-recall-memory.sh" "$component" "." 3 compact 2 2>/dev/null || true)
        if [[ -n "$related" ]]; then
            printf "            %-20s %s\n" "" "↳ 관련: $(echo "$related" | head -3 | tr '\n' ' ')"
        fi
    fi
}

# 컴포넌트 수 세기 (mkdir -p guard: 디렉토리 부재 시 pipefail 방지)
count_skills()   { mkdir -p .hxsk/skills;   find .hxsk/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' '; }
count_agents()   { mkdir -p .hxsk/agents;   find .hxsk/agents -name "*.md" -not -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' '; }
count_hooks()    { mkdir -p .hxsk/hooks;    find .hxsk/hooks -name "*.sh" -o -name "*.py" 2>/dev/null | wc -l | tr -d ' '; }
count_memories() { mkdir -p .hxsk/memories; find .hxsk/memories -mindepth 1 -maxdepth 1 -type d -not -name "_schema" 2>/dev/null | wc -l | tr -d ' '; }

# ─────────────────────────────────────────────────────
# Header
# ─────────────────────────────────────────────────────

echo "================================================================"
echo " BOOTSTRAP v${BOOTSTRAP_VERSION}"
case "$MODE" in
    fresh)  echo " MODE: fresh (초기 설치)" ;;
    verify) echo " MODE: verify (v${OLD_VERSION} — 구조 검증)" ;;
    update) echo " MODE: update (v${OLD_VERSION} → v${BOOTSTRAP_VERSION})" ;;
esac
echo "================================================================"

# ─────────────────────────────────────────────────────
# System Prerequisites (Required)
# ─────────────────────────────────────────────────────

echo ""
echo "--- System Prerequisites ---"

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

# uv (optional)
if command -v uv &>/dev/null; then
    UV_VER=$(uv --version 2>/dev/null | awk '{print $2}')
    report_pass "uv" "${UV_VER}"
else
    report_skip "uv" "not found — only needed for Python projects"
fi

# Python 3
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version | awk '{print $2}')
    PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
    if [[ "$PY_MINOR" -ge 11 ]]; then
        report_pass "Python" "${PY_VER}"
    else
        report_warn "Python" "${PY_VER} (>= 3.11 recommended)"
    fi
else
    report_warn "Python" "not found — security hooks unavailable"
fi

# qlty CLI
if command -v qlty &>/dev/null; then
    QLTY_VER=$(qlty --version 2>/dev/null || echo "installed")
    report_pass "qlty" "${QLTY_VER}"
else
    report_warn "qlty" "not found — optional"
fi

# gh CLI
if command -v gh &>/dev/null; then
    GH_VER=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
    report_pass "gh CLI" "v${GH_VER}"
else
    report_skip "gh CLI" "not found — brew install gh"
fi

# ─────────────────────────────────────────────────────
# Environment
# ─────────────────────────────────────────────────────

echo ""
echo "--- Environment ---"

if [[ -f .env ]]; then
    report_pass ".env" "exists"
else
    if [[ -f .env.example ]]; then
        cp .env.example .env
        report_new ".env" "created from .env.example"
    else
        report_warn ".env" "missing — no .env.example found"
    fi
fi

if [[ -d .venv ]]; then
    report_pass ".venv" "exists"
else
    report_skip ".venv" "missing — create with uv sync if needed"
fi

# ─────────────────────────────────────────────────────
# HXSK Structure
# ─────────────────────────────────────────────────────

echo ""
echo "--- HXSK Structure ---"

# Memory directories — 존재 여부와 무관하게 누락 타입 보충
MEMORY_TYPES=(architecture-decision root-cause debug-eliminated debug-blocked health-event session-handoff execution-summary deviation pattern-discovery bootstrap session-summary session-snapshot security-finding general _schema)
CREATED_MEM=0
for mtype in "${MEMORY_TYPES[@]}"; do
    if [[ ! -d ".hxsk/memories/$mtype" ]]; then
        mkdir -p ".hxsk/memories/$mtype"
        ((CREATED_MEM++)) || true
    fi
done
MEM_COUNT=$(count_memories)
if [[ "$CREATED_MEM" -gt 0 ]]; then
    report_new ".hxsk/memories/" "created ${CREATED_MEM} missing types (total: ${MEM_COUNT})"
elif [[ "$MODE" = "fresh" ]]; then
    report_new ".hxsk/memories/" "${MEM_COUNT} type directories"
else
    report_ok ".hxsk/memories/" "${MEM_COUNT} type directories"
fi

# Context directories
for dir in reports research archive issues/archive; do
    if [[ -d ".hxsk/$dir" ]]; then
        report_ok ".hxsk/$dir/" "exists"
    else
        mkdir -p ".hxsk/$dir"
        report_new ".hxsk/$dir/" "created"
    fi
done

# Context files
if [[ -f ".hxsk/PATTERNS.md" ]]; then
    PATTERNS_SIZE=$(wc -c < ".hxsk/PATTERNS.md" | tr -d ' ')
    report_ok "PATTERNS.md" "${PATTERNS_SIZE}B"
else
    if [[ -f ".hxsk/templates/patterns.md" ]]; then
        cp ".hxsk/templates/patterns.md" ".hxsk/PATTERNS.md"
        report_new "PATTERNS.md" "initialized from template"
    else
        report_warn "PATTERNS.md" "missing — no template found"
    fi
fi

if [[ -f ".hxsk/context-config.yaml" ]]; then
    report_ok "context-config.yaml" "exists"
else
    if [[ -f ".hxsk/templates/context-config.yaml" ]]; then
        cp ".hxsk/templates/context-config.yaml" ".hxsk/context-config.yaml"
        report_new "context-config.yaml" "initialized from template"
    else
        report_warn "context-config.yaml" "missing — no template found"
    fi
fi

# ─────────────────────────────────────────────────────
# Components
# ─────────────────────────────────────────────────────

echo ""
echo "--- Components ---"

SKILL_COUNT=$(count_skills)
AGENT_COUNT=$(count_agents)
HOOK_COUNT=$(count_hooks)
MEM_TYPE_COUNT=$(count_memories)

if [[ "$MODE" = "fresh" ]]; then
    report_new "Skills" "${SKILL_COUNT} installed"
    report_new "Agents" "${AGENT_COUNT} installed"
    report_new "Hooks" "${HOOK_COUNT} installed"
    report_new "Memory Types" "${MEM_TYPE_COUNT} directories"
elif [[ "$MODE" = "update" ]]; then
    # 구버전의 컴포넌트 수와 비교
    OLD_SKILLS=$(grep 'skills:' "$VERSION_FILE" 2>/dev/null | sed 's/.*skills: *//' | tr -d ' ')
    OLD_AGENTS=$(grep 'agents:' "$VERSION_FILE" 2>/dev/null | sed 's/.*agents: *//' | tr -d ' ')
    OLD_HOOKS=$(grep 'hooks:' "$VERSION_FILE" 2>/dev/null | sed 's/.*hooks: *//' | tr -d ' ')
    OLD_MEMS=$(grep 'memories:' "$VERSION_FILE" 2>/dev/null | sed 's/.*memories: *//' | tr -d ' ')

    [[ "$SKILL_COUNT" != "${OLD_SKILLS:-0}" ]] && report_updated "Skills" "${OLD_SKILLS:-0} → ${SKILL_COUNT}" || report_ok "Skills" "${SKILL_COUNT}"
    [[ "$AGENT_COUNT" != "${OLD_AGENTS:-0}" ]] && report_updated "Agents" "${OLD_AGENTS:-0} → ${AGENT_COUNT}" || report_ok "Agents" "${AGENT_COUNT}"
    [[ "$HOOK_COUNT" != "${OLD_HOOKS:-0}" ]]   && report_updated "Hooks" "${OLD_HOOKS:-0} → ${HOOK_COUNT}"   || report_ok "Hooks" "${HOOK_COUNT}"
    [[ "$MEM_TYPE_COUNT" != "${OLD_MEMS:-0}" ]] && report_updated "Memory Types" "${OLD_MEMS:-0} → ${MEM_TYPE_COUNT}" || report_ok "Memory Types" "${MEM_TYPE_COUNT}"
else
    report_ok "Skills" "${SKILL_COUNT}"
    report_ok "Agents" "${AGENT_COUNT}"
    report_ok "Hooks" "${HOOK_COUNT}"
    report_ok "Memory Types" "${MEM_TYPE_COUNT}"
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
# Write Version File
# ─────────────────────────────────────────────────────

mkdir -p "$(dirname "$VERSION_FILE")"
cat > "$VERSION_FILE" << EOF
version: ${BOOTSTRAP_VERSION}
last_run: $(date '+%Y-%m-%d')
components:
  skills: ${SKILL_COUNT}
  agents: ${AGENT_COUNT}
  hooks: ${HOOK_COUNT}
  memories: ${MEM_TYPE_COUNT}
EOF

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
case "$MODE" in
    fresh)  printf " MODE: fresh  |  " ;;
    verify) printf " MODE: verify |  " ;;
    update) printf " MODE: update (v%s → v%s)  |  " "$OLD_VERSION" "$BOOTSTRAP_VERSION" ;;
esac
printf "PASS: %d  FAIL: %d  WARN: %d  SKIP: %d  NEW: %d  UPDATED: %d\n" \
    "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT" "$NEW_COUNT" "$UPDATED_COUNT"

if [[ "$REQUIRED_FAIL" -gt 0 ]]; then
    echo " RESULT: FAILED — ${REQUIRED_FAIL} required check(s) failed"
    echo "================================================================"
    exit 1
else
    echo " RESULT: ALL REQUIRED CHECKS PASSED"
    echo "================================================================"
    exit 0
fi
