#!/usr/bin/env bash
# issue-list.sh — 이슈 목록 (L0: frontmatter만)
# Usage: bash scripts/issue-list.sh [status] [priority]
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
STATUS_FILTER="${1:-}"
PRIORITY_FILTER="${2:-}"

if [ ! -d "$ISSUES_DIR" ] || [ -z "$(find "$ISSUES_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)" ]; then
    echo "No issues found."
    exit 0
fi

printf "%-5s %-8s %-4s %-8s %-6s %s\n" "ID" "TYPE" "PRI" "STATUS" "WAVE" "TITLE"
printf "%-5s %-8s %-4s %-8s %-6s %s\n" "-----" "--------" "----" "--------" "------" "----------------------------"

for f in "$ISSUES_DIR"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    ID=""; TYPE=""; PRI=""; STATUS=""; WAVE=""; TITLE=""

    while IFS= read -r line; do
        case "$line" in
            id:*) ID=$(echo "$line" | sed 's/^id: *//') ;;
            type:*) TYPE=$(echo "$line" | sed 's/^type: *//') ;;
            priority:*) PRI=$(echo "$line" | sed 's/^priority: *//') ;;
            status:*) STATUS=$(echo "$line" | sed 's/^status: *//') ;;
            wave:*) WAVE=$(echo "$line" | sed 's/^wave: *//') ;;
            title:*) TITLE=$(echo "$line" | sed 's/^title: *//; s/^"//; s/"$//') ;;
        esac
    done < <(awk 'NR==1 && /^---/{in_fm=1; next} in_fm && /^---/{exit} in_fm{print}' "$f")

    [ -n "$STATUS_FILTER" ] && [ "$STATUS" != "$STATUS_FILTER" ] && continue
    [ -n "$PRIORITY_FILTER" ] && [ "$PRI" != "$PRIORITY_FILTER" ] && continue

    printf "%-5s %-8s %-4s %-8s %-6s %s\n" "$ID" "$TYPE" "$PRI" "$STATUS" "${WAVE:-—}" "$TITLE"
done
