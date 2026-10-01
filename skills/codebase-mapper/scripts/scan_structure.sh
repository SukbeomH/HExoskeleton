#!/usr/bin/env bash

# Scan project structure and output directory tree with statistics.
# Usage: bash scripts/scan_structure.sh [project_root]

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT="${1:-.}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
    printf '{"error": "Directory not found: %s"}\n' "$PROJECT_ROOT"
    exit 1
fi

echo "=== Project Structure: $(basename "$(cd "$PROJECT_ROOT" && pwd)") ==="
echo ""

# --- Directory tree (max 3 levels, excluding hidden/common noise) ---
echo "## Directory Tree"
find "$PROJECT_ROOT" -maxdepth 3 -type d \
    ! -path '*/.git/*' ! -path '*/.git' \
    ! -path '*/node_modules/*' ! -path '*/__pycache__/*' \
    ! -path '*/.venv/*' ! -path '*/.mypy_cache/*' \
    ! -path '*/.ruff_cache/*' ! -path '*/.pytest_cache/*' \
    ! -path '*/.tox/*' ! -path '*/dist/*' ! -path '*/build/*' \
    | sort | sed "s|^$PROJECT_ROOT|.|" | head -80
echo ""

# --- File counts by extension ---
echo "## File Statistics"
echo ""
echo "| Extension | Count |"
echo "|-----------|-------|"
find "$PROJECT_ROOT" -type f \
    ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/__pycache__/*' \
    ! -path '*/.venv/*' ! -path '*/.mypy_cache/*' \
    | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20 \
    | while read -r count ext; do
        printf "| .%-8s | %5d |\n" "$ext" "$count"
    done
echo ""

# --- Key files detection ---
echo "## Key Files"
KEY_FILES=(
    "pyproject.toml" "package.json" "Cargo.toml" "go.mod"
    "Makefile" "Dockerfile" "docker-compose.yml"
    ".env.example" ".gitignore" "README.md"
)
for kf in "${KEY_FILES[@]}"; do
    if [[ -f "$PROJECT_ROOT/$kf" ]]; then
        echo "  [x] $kf"
    fi
done
echo ""

# --- Source code lines ---
echo "## Lines of Code (approximate)"
TOTAL_LINES=0
for ext in py ts tsx js jsx rs go java; do
    count=$(find "$PROJECT_ROOT" -name "*.$ext" -type f \
        ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/__pycache__/*' \
        ! -path '*/.venv/*' \
        -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -gt 0 ]]; then
        printf "  %-6s %6d lines\n" ".$ext" "$count"
        TOTAL_LINES=$((TOTAL_LINES + count))
    fi
done
printf "  %-6s %6d lines\n" "TOTAL" "$TOTAL_LINES"
