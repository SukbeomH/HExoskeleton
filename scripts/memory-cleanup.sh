#!/usr/bin/env bash
# memory-cleanup.sh — 메모리 파일 정리/압축/아카이브
# Usage: bash scripts/memory-cleanup.sh [--dry-run]
#
# Actions:
# 1. session-summary: 30일 이상 된 파일 아카이브, 최대 30개 유지
# 2. session-snapshot: 14일 이상 된 파일 삭제
# 3. execution-summary: 60일 이상 된 파일 아카이브
# 4. 빈 타입 디렉토리 보고
# 5. 전체 통계 출력
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN] No files will be modified"
fi

HXSK_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk"
MEMORIES_DIR="$HXSK_DIR/memories"
ARCHIVE_DIR="$MEMORIES_DIR/_archive"
TODAY=$(date '+%Y-%m-%d')
YEAR_MONTH=$(date '+%Y-%m')

if [[ ! -d "$MEMORIES_DIR" ]]; then
    echo "[SKIP] .hxsk/memories/ not found"
    exit 0
fi

mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true

# 카운터
ARCHIVED=0
DELETED=0
KEPT=0

echo "================================================================"
echo " Memory Cleanup — $TODAY"
echo "================================================================"

# ─────────────────────────────────────────────────────
# Helper: 날짜 파싱 (파일명에서 YYYY-MM-DD 추출)
# ─────────────────────────────────────────────────────

file_age_days() {
    local filename
    filename=$(basename "$1")
    # 파일명 형식: YYYY-MM-DD_slug.md
    local file_date
    file_date=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")
    if [[ -z "$file_date" ]]; then
        echo "0"
        return
    fi
    local file_epoch today_epoch
    file_epoch=$(date -j -f "%Y-%m-%d" "$file_date" "+%s" 2>/dev/null || date -d "$file_date" "+%s" 2>/dev/null || echo "0")
    today_epoch=$(date "+%s")
    if [[ "$file_epoch" -eq 0 ]]; then
        echo "0"
        return
    fi
    echo $(( (today_epoch - file_epoch) / 86400 ))
}

# ─────────────────────────────────────────────────────
# 1. session-summary 정리 (30일, 최대 30개)
# ─────────────────────────────────────────────────────

echo ""
echo "--- session-summary ---"
SS_DIR="$MEMORIES_DIR/session-summary"
if [[ -d "$SS_DIR" ]]; then
    SS_COUNT=$(find "$SS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total: $SS_COUNT files"

    # 30일 이상 된 파일 아카이브
    OLD_COUNT=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        age=$(file_age_days "$f")
        if [[ "$age" -gt 30 ]]; then
            ((OLD_COUNT++)) || true
            if [[ "$DRY_RUN" == false ]]; then
                mv "$f" "$ARCHIVE_DIR/" 2>/dev/null || true
                ((ARCHIVED++)) || true
            fi
        else
            ((KEPT++)) || true
        fi
    done < <(find "$SS_DIR" -name "*.md" -type f 2>/dev/null | sort)

    echo "  Archived (>30d): $OLD_COUNT"

    # 최대 30개 유지 (오래된 것부터 삭제)
    REMAINING=$(find "$SS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$REMAINING" -gt 30 ]]; then
        EXCESS=$((REMAINING - 30))
        echo "  Excess (>30 files): $EXCESS → archive"
        if [[ "$DRY_RUN" == false ]]; then
            find "$SS_DIR" -name "*.md" -type f 2>/dev/null | sort | head -n "$EXCESS" | while read -r f; do
                mv "$f" "$ARCHIVE_DIR/" 2>/dev/null || true
                ((ARCHIVED++)) || true
            done
        fi
    fi
else
    echo "  [SKIP] Directory not found"
fi

# ─────────────────────────────────────────────────────
# 2. session-snapshot 정리 (14일 후 삭제)
# ─────────────────────────────────────────────────────

echo ""
echo "--- session-snapshot ---"
SNAP_DIR="$MEMORIES_DIR/session-snapshot"
if [[ -d "$SNAP_DIR" ]]; then
    SNAP_COUNT=$(find "$SNAP_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total: $SNAP_COUNT files"

    OLD_SNAPS=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        age=$(file_age_days "$f")
        if [[ "$age" -gt 14 ]]; then
            ((OLD_SNAPS++)) || true
            if [[ "$DRY_RUN" == false ]]; then
                rm "$f" 2>/dev/null || true
                ((DELETED++)) || true
            fi
        else
            ((KEPT++)) || true
        fi
    done < <(find "$SNAP_DIR" -name "*.md" -type f 2>/dev/null | sort)

    echo "  Deleted (>14d): $OLD_SNAPS"
else
    echo "  [SKIP] Directory not found"
fi

# ─────────────────────────────────────────────────────
# 3. execution-summary 정리 (60일 후 아카이브)
# ─────────────────────────────────────────────────────

echo ""
echo "--- execution-summary ---"
ES_DIR="$MEMORIES_DIR/execution-summary"
if [[ -d "$ES_DIR" ]]; then
    ES_COUNT=$(find "$ES_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total: $ES_COUNT files"

    OLD_ES=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        age=$(file_age_days "$f")
        if [[ "$age" -gt 60 ]]; then
            ((OLD_ES++)) || true
            if [[ "$DRY_RUN" == false ]]; then
                mv "$f" "$ARCHIVE_DIR/" 2>/dev/null || true
                ((ARCHIVED++)) || true
            fi
        else
            ((KEPT++)) || true
        fi
    done < <(find "$ES_DIR" -name "*.md" -type f 2>/dev/null | sort)

    echo "  Archived (>60d): $OLD_ES"
else
    echo "  [SKIP] Directory not found"
fi

# ─────────────────────────────────────────────────────
# 4. 전체 메모리 통계
# ─────────────────────────────────────────────────────

echo ""
echo "--- Memory Statistics ---"
TOTAL_FILES=$(find "$MEMORIES_DIR" -name "*.md" -not -path "*/_archive/*" -not -path "*/_schema/*" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SIZE=$(find "$MEMORIES_DIR" -name "*.md" -not -path "*/_archive/*" -not -path "*/_schema/*" 2>/dev/null -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
ARCHIVE_FILES=$(find "$ARCHIVE_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

echo "  Active files: $TOTAL_FILES"
echo "  Active size: $((TOTAL_SIZE / 1024))KB"
echo "  Archived files: $ARCHIVE_FILES"

# 빈 타입 보고
echo ""
echo "--- Empty Types ---"
for dir in "$MEMORIES_DIR"/*/; do
    [[ ! -d "$dir" ]] && continue
    dirname=$(basename "$dir")
    [[ "$dirname" == "_schema" || "$dirname" == "_archive" ]] && continue
    count=$(find "$dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -eq 0 ]]; then
        echo "  [EMPTY] $dirname/"
    fi
done

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
printf " Archived: %d  |  Deleted: %d  |  Kept: %d\n" "$ARCHIVED" "$DELETED" "$KEPT"
echo "================================================================"

if [[ "$DRY_RUN" == true ]]; then
    echo "Run without --dry-run to apply changes"
fi
