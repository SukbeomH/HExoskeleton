#!/usr/bin/env bash

# Collect system and project diagnostic information for debugging.
# Usage: bash scripts/collect_diagnostics.sh [project_root]

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT="${1:-.}"

echo "=== Diagnostic Report ==="
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# --- System Info ---
echo "## System"
printf "  OS:       %s\n" "$(uname -s) $(uname -r)"
printf "  Arch:     %s\n" "$(uname -m)"
printf "  Shell:    %s\n" "${SHELL:-unknown}"
printf "  User:     %s\n" "$(whoami)"
echo ""

# --- Runtime Versions ---
echo "## Runtimes"
for cmd in python3 python node uv pip npm cargo go java docker git; do
    if command -v "$cmd" &>/dev/null; then
        version=$("$cmd" --version 2>&1 | head -1 || echo "installed")
        printf "  %-10s %s\n" "$cmd:" "$version"
    fi
done
echo ""

# --- Git Status ---
echo "## Git"
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    printf "  Branch:   %s\n" "$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null)"
    printf "  Commit:   %s\n" "$(git -C "$PROJECT_ROOT" log --oneline -1 2>/dev/null)"
    printf "  Status:   %s modified, %s staged\n" \
        "$(git -C "$PROJECT_ROOT" diff --name-only 2>/dev/null | wc -l | tr -d ' ')" \
        "$(git -C "$PROJECT_ROOT" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
    echo ""
    echo "  Recent commits:"
    git -C "$PROJECT_ROOT" log --oneline -5 2>/dev/null | sed 's/^/    /'
else
    echo "  Not a git repository"
fi
echo ""

# --- Project Dependencies ---
echo "## Dependencies"
if [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
    echo "  Python project (pyproject.toml)"
    if command -v uv &>/dev/null; then
        printf "  uv lock status: "
        uv lock --check 2>/dev/null && echo "synced" || echo "outdated"
    fi
fi
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
    echo "  Node project (package.json)"
fi
echo ""

# --- Disk / Environment ---
echo "## Environment"
printf "  PWD:      %s\n" "$(pwd)"
printf "  Project:  %s\n" "$(cd "$PROJECT_ROOT" && pwd)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    env_count=$(grep -c -v '^\s*#\|^\s*$' "$PROJECT_ROOT/.env" 2>/dev/null || echo "0")
    printf "  .env:     %s variables defined\n" "$env_count"
fi
echo ""

# --- Docker ---
if command -v docker &>/dev/null; then
    echo "## Docker"
    RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')
    printf "  Running containers: %s\n" "$RUNNING"
    if [[ "$RUNNING" -gt 0 ]]; then
        docker ps --format '    {{.Names}} ({{.Image}})' 2>/dev/null | head -10
    fi
fi

echo ""
echo "=== End Diagnostic Report ==="
