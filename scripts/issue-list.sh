#!/usr/bin/env bash
# issue-list.sh — 이슈 목록 (MASTER/WORK/레거시 지원)
# Usage: bash scripts/issue-list.sh [master|work|all] [status]
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
MODE="${1:-all}"
STATUS_FILTER="${2:-}"

if [ ! -d "$ISSUES_DIR" ]; then
    echo "No issues directory found."
    exit 0
fi

# --- MASTER 목록 ---
list_master() {
    local has_files=false
    for f in "$ISSUES_DIR"/MASTER-*.md; do
        [ -f "$f" ] || continue
        has_files=true
        break
    done
    if ! $has_files; then
        [ "$MODE" = "master" ] && echo "No MASTER issues found."
        return
    fi

    printf "\n%-12s %-12s %-6s %s\n" "ID" "STATUS" "WORKS" "TITLE"
    printf "%-12s %-12s %-6s %s\n" "------------" "------------" "------" "----------------------------"

    for f in "$ISSUES_DIR"/MASTER-*.md; do
        [ -f "$f" ] || continue

        ID=""; STATUS=""; TITLE=""; WORKS_COUNT=0

        while IFS= read -r line; do
            case "$line" in
                id:*) ID=$(echo "$line" | sed 's/^id: *//') ;;
                status:*) STATUS=$(echo "$line" | sed 's/^status: *//') ;;
                title:*) TITLE=$(echo "$line" | sed 's/^title: *//; s/^"//; s/"$//') ;;
                "  - WORK-"*) WORKS_COUNT=$(( WORKS_COUNT + 1 )) ;;
            esac
        done < <(awk 'NR==1 && /^---/{in_fm=1; next} in_fm && /^---/{exit} in_fm{print}' "$f")

        [ -n "$STATUS_FILTER" ] && [ "$STATUS" != "$STATUS_FILTER" ] && continue

        printf "%-12s %-12s %-6s %s\n" "$ID" "$STATUS" "$WORKS_COUNT" "$TITLE"
    done
}

# --- WORK 목록 ---
list_work() {
    local has_files=false
    for f in "$ISSUES_DIR"/WORK-*.md; do
        [ -f "$f" ] || continue
        has_files=true
        break
    done
    if ! $has_files; then
        [ "$MODE" = "work" ] && echo "No WORK issues found."
        return
    fi

    printf "\n%-16s %-12s %-12s %-6s %-20s %s\n" "ID" "MASTER" "STATUS" "WAVE" "DEPENDS_ON" "TITLE"
    printf "%-16s %-12s %-12s %-6s %-20s %s\n" "----------------" "------------" "------------" "------" "--------------------" "----------------------------"

    for f in "$ISSUES_DIR"/WORK-*.md; do
        [ -f "$f" ] || continue

        ID=""; MASTER=""; STATUS=""; WAVE=""; TITLE=""; DEPENDS=""

        while IFS= read -r line; do
            case "$line" in
                id:*) ID=$(echo "$line" | sed 's/^id: *//') ;;
                master:*) MASTER=$(echo "$line" | sed 's/^master: *//') ;;
                status:*) STATUS=$(echo "$line" | sed 's/^status: *//') ;;
                wave:*) WAVE=$(echo "$line" | sed 's/^wave: *//') ;;
                title:*) TITLE=$(echo "$line" | sed 's/^title: *//; s/^"//; s/"$//') ;;
                "  - WORK-"*) DEPENDS="${DEPENDS:+$DEPENDS,}$(echo "$line" | sed 's/^  - //')" ;;
            esac
        done < <(awk 'NR==1 && /^---/{in_fm=1; next} in_fm && /^---/{exit} in_fm{print}' "$f")

        [ -n "$STATUS_FILTER" ] && [ "$STATUS" != "$STATUS_FILTER" ] && continue

        printf "%-16s %-12s %-12s %-6s %-20s %s\n" "$ID" "$MASTER" "$STATUS" "${WAVE:-—}" "${DEPENDS:-—}" "$TITLE"
    done
}

# --- 레거시 목록 ---
list_legacy() {
    local has_files=false
    for f in "$ISSUES_DIR"/[0-9]*.md; do
        [ -f "$f" ] || continue
        has_files=true
        break
    done
    if ! $has_files; then
        return
    fi

    printf "\n%-5s %-8s %-4s %-8s %-6s %s\n" "ID" "TYPE" "PRI" "STATUS" "WAVE" "TITLE"
    printf "%-5s %-8s %-4s %-8s %-6s %s\n" "-----" "--------" "----" "--------" "------" "----------------------------"

    for f in "$ISSUES_DIR"/[0-9]*.md; do
        [ -f "$f" ] || continue

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

        printf "%-5s %-8s %-4s %-8s %-6s %s\n" "$ID" "$TYPE" "$PRI" "$STATUS" "${WAVE:-—}" "$TITLE"
    done
}

# --- 실행 ---
case "$MODE" in
    master) list_master ;;
    work)   list_work ;;
    all)    list_master; list_work; list_legacy ;;
    *)
        # 하위 호환: 첫 인자가 status 필터일 수 있음 (기존 사용법)
        STATUS_FILTER="$MODE"
        MODE="all"
        list_master; list_work; list_legacy
        ;;
esac
