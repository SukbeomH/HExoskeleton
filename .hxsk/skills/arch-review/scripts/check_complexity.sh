#!/usr/bin/env bash

# Check code complexity metrics using ruff.
# Reports functions exceeding complexity thresholds (McCabe ≤ 10, max-args ≤ 6).
# Usage: bash scripts/check_complexity.sh [target_path]

set -o errexit
set -o nounset
set -o pipefail

TARGET="${1:-.}"

if ! command -v uv &>/dev/null; then
    echo '{"error": "uv not found in PATH"}'
    exit 1
fi

echo "=== Complexity Report ==="
echo ""

# --- McCabe Complexity ---
echo "## McCabe Complexity (threshold: 10)"
C90_OUTPUT=$(uv run ruff check "$TARGET" --select C90 --output-format=json 2>/dev/null || true)
C90_COUNT=$(echo "$C90_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$C90_COUNT" -gt 0 ]]; then
    echo "  VIOLATIONS: $C90_COUNT"
    echo "$C90_OUTPUT" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    loc = item.get('location', {})
    print(f\"  {item['filename']}:{loc.get('row','')}: {item['message']}\")
" 2>/dev/null || true
else
    echo "  PASS: No complexity violations"
fi
echo ""

# --- Too Many Arguments ---
echo "## Function Arguments (threshold: 6)"
PLR_OUTPUT=$(uv run ruff check "$TARGET" --select PLR0913 --output-format=json 2>/dev/null || true)
PLR_COUNT=$(echo "$PLR_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$PLR_COUNT" -gt 0 ]]; then
    echo "  VIOLATIONS: $PLR_COUNT"
    echo "$PLR_OUTPUT" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    loc = item.get('location', {})
    print(f\"  {item['filename']}:{loc.get('row','')}: {item['message']}\")
" 2>/dev/null || true
else
    echo "  PASS: No argument count violations"
fi
echo ""

# --- Naming Conventions ---
echo "## Naming Conventions"
N_OUTPUT=$(uv run ruff check "$TARGET" --select N --output-format=json 2>/dev/null || true)
N_COUNT=$(echo "$N_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$N_COUNT" -gt 0 ]]; then
    echo "  VIOLATIONS: $N_COUNT"
    echo "$N_OUTPUT" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    loc = item.get('location', {})
    print(f\"  {item['filename']}:{loc.get('row','')}: {item['code']} {item['message']}\")
" 2>/dev/null || true
else
    echo "  PASS: No naming violations"
fi
echo ""

# --- Summary ---
TOTAL=$((C90_COUNT + PLR_COUNT + N_COUNT))
echo "=== Summary ==="
printf "  McCabe:    %s (%d violations)\n" "$([ "$C90_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")" "$C90_COUNT"
printf "  Arguments: %s (%d violations)\n" "$([ "$PLR_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")" "$PLR_COUNT"
printf "  Naming:    %s (%d violations)\n" "$([ "$N_COUNT" -eq 0 ] && echo "PASS" || echo "FAIL")" "$N_COUNT"
printf "  Overall:   %s (%d total)\n" "$([ "$TOTAL" -eq 0 ] && echo "CLEAN" || echo "ISSUES_FOUND")" "$TOTAL"

[[ "$TOTAL" -eq 0 ]] && exit 0 || exit 1
