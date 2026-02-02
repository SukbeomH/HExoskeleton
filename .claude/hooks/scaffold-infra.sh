#!/usr/bin/env bash
#
# scaffold-infra.sh - Compare project files against reference configurations
#
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
REF_DIR="$PROJECT_DIR/.claude/references"

echo "Comparing infrastructure files..."
echo "  References: ${REF_DIR}"
echo "  Project: ${PROJECT_DIR}"
echo ""

# Check if references directory exists
if [ ! -d "$REF_DIR" ]; then
    echo "[SKIP] References directory not found: $REF_DIR"
    exit 0
fi

# Define mappings: reference_file -> project_path
declare -A MAP=(
    ["pyproject.toml"]="pyproject.toml"
    ["Makefile"]="Makefile"
    ["gitignore.txt"]=".gitignore"
    ["ci.yml"]=".github/workflows/ci.yml"
    ["CLAUDE.md"]="CLAUDE.md"
    ["vscode-settings.json"]=".vscode/settings.json"
    ["vscode-extensions.json"]=".vscode/extensions.json"
    ["github-agent.md"]=".github/agents/agent.md"
    ["env.example"]=".env.example"
)

has_diff=0

for ref in "${!MAP[@]}"; do
    ref_path="$REF_DIR/$ref"
    proj_path="$PROJECT_DIR/${MAP[$ref]}"

    if [ ! -f "$ref_path" ]; then
        continue
    fi

    if [ ! -f "$proj_path" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[MISSING] ${MAP[$ref]}"
        echo "  Reference available at: $ref_path"
        echo ""
        has_diff=1
    else
        if ! diff -q "$proj_path" "$ref_path" > /dev/null 2>&1; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "[DIFFERS] ${MAP[$ref]}"
            echo ""
            diff -u "$proj_path" "$ref_path" | head -50 || true
            echo ""
            has_diff=1
        fi
    fi
done

echo ""
if [ $has_diff -eq 0 ]; then
    echo "All infrastructure files match references!"
else
    echo "Review the differences above."
    echo "Reference files are in: $REF_DIR/"
fi
