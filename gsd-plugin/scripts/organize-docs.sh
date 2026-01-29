#!/usr/bin/env bash

# Organize .gsd documents into appropriate folders
# Usage: bash scripts/organize-docs.sh [--dry-run]
#
# Actions:
# 1. Move REPORT-*.md to reports/
# 2. Move RESEARCH-*.md to research/

set -o errexit
set -o nounset
set -o pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN] No files will be moved"
fi

GSD_DIR="${CLAUDE_PROJECT_DIR:-.}/.gsd"
REPORTS_DIR="$GSD_DIR/reports"
RESEARCH_DIR="$GSD_DIR/research"

# Ensure directories exist
mkdir -p "$REPORTS_DIR" "$RESEARCH_DIR"

echo "================================================================"
echo " Document Organization"
echo "================================================================"

MOVED_COUNT=0

# ─────────────────────────────────────────────────────
# Move REPORT-*.md to reports/
# ─────────────────────────────────────────────────────

echo ""
echo "--- Reports ---"

for file in "$GSD_DIR"/REPORT-*.md; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        if [[ "$DRY_RUN" == true ]]; then
            echo "  [WOULD MOVE] $filename -> reports/"
        else
            mv "$file" "$REPORTS_DIR/"
            echo "  [MOVED] $filename -> reports/"
        fi
        ((MOVED_COUNT++)) || true
    fi
done

if [[ "$MOVED_COUNT" -eq 0 ]]; then
    echo "  No REPORT-*.md files in .gsd/ root"
fi

# ─────────────────────────────────────────────────────
# Move RESEARCH-*.md to research/
# ─────────────────────────────────────────────────────

echo ""
echo "--- Research ---"

RESEARCH_MOVED=0
for file in "$GSD_DIR"/RESEARCH-*.md; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        if [[ "$DRY_RUN" == true ]]; then
            echo "  [WOULD MOVE] $filename -> research/"
        else
            mv "$file" "$RESEARCH_DIR/"
            echo "  [MOVED] $filename -> research/"
        fi
        ((RESEARCH_MOVED++)) || true
        ((MOVED_COUNT++)) || true
    fi
done

if [[ "$RESEARCH_MOVED" -eq 0 ]]; then
    echo "  No RESEARCH-*.md files in .gsd/ root"
fi

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo " Organization Complete"
echo "================================================================"
echo "  Files processed: $MOVED_COUNT"

if [[ "$DRY_RUN" == true ]]; then
    echo "  Run without --dry-run to apply changes"
fi

# Show current folder contents
echo ""
echo "--- Current Structure ---"
echo "  reports/: $(ls -1 "$REPORTS_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  research/: $(ls -1 "$RESEARCH_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
