#!/usr/bin/env bash

# Run code quality checks for shell scripts.
# Usage: bash scripts/run_quality_checks.sh [--fix-only]

set -o errexit
set -o nounset
set -o pipefail

# --- Options ---
FIX_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --fix-only) FIX_ONLY=true ;;
    esac
done

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# --- Results ---
SHELLCHECK_STATUS="SKIP"
SHELLCHECK_ISSUES=0
SHFMT_STATUS="SKIP"

# --- Step 1: ShellCheck (if available) ---
if command -v shellcheck &>/dev/null; then
    SHELL_FILES=$(find "$PROJECT_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) \
        -not -path "*/.git/*" \
        -not -path "*/.venv/*" \
        -not -path "*/node_modules/*" 2>/dev/null || true)

    if [[ -n "$SHELL_FILES" ]]; then
        SHELLCHECK_OUTPUT=$(echo "$SHELL_FILES" | xargs shellcheck -f gcc 2>&1 || true)
        SHELLCHECK_ISSUES=$(echo "$SHELLCHECK_OUTPUT" | grep -c ":" 2>/dev/null || echo "0")

        if [[ "$SHELLCHECK_ISSUES" -eq 0 ]]; then
            SHELLCHECK_STATUS="PASS"
        else
            SHELLCHECK_STATUS="FAIL"
        fi
    else
        SHELLCHECK_STATUS="SKIP"
    fi
else
    echo "Note: shellcheck not installed. Install with: brew install shellcheck"
    SHELLCHECK_STATUS="SKIP"
fi

# --- Step 2: shfmt (if available) ---
if command -v shfmt &>/dev/null; then
    SHELL_FILES=$(find "$PROJECT_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) \
        -not -path "*/.git/*" \
        -not -path "*/.venv/*" \
        -not -path "*/node_modules/*" 2>/dev/null || true)

    if [[ -n "$SHELL_FILES" ]]; then
        if [[ "$FIX_ONLY" == "true" ]]; then
            echo "$SHELL_FILES" | xargs shfmt -w -i 4 2>/dev/null || true
            SHFMT_STATUS="FIXED"
        else
            SHFMT_DIFF=$(echo "$SHELL_FILES" | xargs shfmt -d -i 4 2>&1 || true)
            if [[ -z "$SHFMT_DIFF" ]]; then
                SHFMT_STATUS="PASS"
            else
                SHFMT_STATUS="NEEDS_FORMAT"
            fi
        fi
    else
        SHFMT_STATUS="SKIP"
    fi
else
    SHFMT_STATUS="SKIP"
fi

# --- Output ---
OVERALL="CLEAN"
if [[ "$SHELLCHECK_STATUS" == "FAIL" ]]; then
    OVERALL="ISSUES_REMAIN"
fi

cat <<EOF
=== Clean Report ===
ShellCheck:   ${SHELLCHECK_STATUS} (${SHELLCHECK_ISSUES} issues)
Format:       ${SHFMT_STATUS}
===
Overall:      ${OVERALL}
EOF

if [[ "$SHELLCHECK_STATUS" == "FAIL" ]] && [[ "$FIX_ONLY" == "false" ]]; then
    echo ""
    echo "--- ShellCheck Issues ---"
    echo "$SHELLCHECK_OUTPUT" | head -20
fi

[[ "$OVERALL" == "CLEAN" ]] && exit 0 || exit 1
