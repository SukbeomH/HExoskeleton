#!/usr/bin/env bash

# Compact context files to maintain size limits
# Usage: bash .hxsk/hooks/compact-context.sh [--dry-run]
#
# Actions:
# 1. Prune PATTERNS.md to 20 items / 2KB
# 2. Archive old JOURNAL.md entries (keep last 5 sessions)
# 3. Archive old CHANGELOG.md entries (keep last 5)
# 4. Move completed prd items to prd-done.json

set -o errexit
set -o nounset
set -o pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN] No files will be modified"
fi

HXSK_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk"
ARCHIVE_DIR="$HXSK_DIR/archive"
YEAR_MONTH=$(date +%Y-%m)

# Check if .hxsk directory exists
if [[ ! -d "$HXSK_DIR" ]]; then
    echo "[SKIP] .hxsk/ directory not found at $HXSK_DIR"
    echo "Run /hxsk:init to initialize HExoskeleton documents."
    exit 0
fi

# Ensure archive directory exists
mkdir -p "$ARCHIVE_DIR" 2>/dev/null || {
    echo "[ERROR] Cannot create archive directory: $ARCHIVE_DIR"
    exit 1
}

echo "================================================================"
echo " Context Compaction"
echo "================================================================"

# ─────────────────────────────────────────────────────
# 1. PATTERNS.md size check
# ─────────────────────────────────────────────────────

PATTERNS_FILE="$HXSK_DIR/PATTERNS.md"
if [[ -f "$PATTERNS_FILE" ]]; then
    PATTERNS_SIZE=$(wc -c < "$PATTERNS_FILE" | tr -d ' ')
    PATTERNS_ITEMS=$(grep -c "^- " "$PATTERNS_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)

    echo ""
    echo "--- PATTERNS.md ---"
    echo "  Size: ${PATTERNS_SIZE}B (limit: 2048B)"
    echo "  Items: ${PATTERNS_ITEMS} (limit: 20)"

    if [[ "$PATTERNS_SIZE" -gt 2048 ]] || [[ "$PATTERNS_ITEMS" -gt 20 ]]; then
        echo "  [WARN] Exceeds limits - manual pruning recommended"
        echo "  Tip: Remove oldest or least-referenced patterns"
    else
        echo "  [OK] Within limits"
    fi
else
    echo ""
    echo "--- PATTERNS.md ---"
    echo "  [SKIP] File not found"
fi

# ─────────────────────────────────────────────────────
# 2. JOURNAL.md archiving
# ─────────────────────────────────────────────────────

JOURNAL_FILE="$HXSK_DIR/JOURNAL.md"
if [[ -f "$JOURNAL_FILE" ]]; then
    # Count sessions (headers starting with ### [Session or ## Session)
    SESSION_COUNT=$(grep -c "^##.* Session" "$JOURNAL_FILE" 2>/dev/null || echo 0)

    echo ""
    echo "--- JOURNAL.md ---"
    echo "  Sessions: ${SESSION_COUNT} (keep: 5)"

    if [[ "$SESSION_COUNT" -gt 5 ]]; then
        ARCHIVE_FILE="$ARCHIVE_DIR/journal-${YEAR_MONTH}.md"
        echo "  [ACTION] Would archive $(($SESSION_COUNT - 5)) old sessions to $ARCHIVE_FILE"

        if [[ "$DRY_RUN" == false ]]; then
            # Archive old sessions
            # Get line numbers of session headers
            SESSION_LINES=$(grep -n "^##.* Session" "$JOURNAL_FILE" | cut -d: -f1)
            SESSION_ARRAY=($SESSION_LINES)
            KEEP_FROM_IDX=$((${#SESSION_ARRAY[@]} - 5))

            if [[ $KEEP_FROM_IDX -gt 0 ]]; then
                KEEP_FROM_LINE=${SESSION_ARRAY[$KEEP_FROM_IDX]}

                # Extract header (before first session)
                HEADER_END=$((${SESSION_ARRAY[0]} - 1))
                if [[ $HEADER_END -gt 0 ]]; then
                    head -n "$HEADER_END" "$JOURNAL_FILE" > "$JOURNAL_FILE.tmp"
                else
                    echo "" > "$JOURNAL_FILE.tmp"
                fi

                # Archive old sessions (append to archive file)
                if [[ ! -f "$ARCHIVE_FILE" ]]; then
                    echo "# Journal Archive - ${YEAR_MONTH}" > "$ARCHIVE_FILE"
                    echo "" >> "$ARCHIVE_FILE"
                fi
                sed -n "${SESSION_ARRAY[0]},$((KEEP_FROM_LINE - 1))p" "$JOURNAL_FILE" >> "$ARCHIVE_FILE"

                # Keep recent sessions
                tail -n "+$KEEP_FROM_LINE" "$JOURNAL_FILE" >> "$JOURNAL_FILE.tmp"
                mv "$JOURNAL_FILE.tmp" "$JOURNAL_FILE"

                echo "  [DONE] Archived $(($SESSION_COUNT - 5)) sessions to $ARCHIVE_FILE"
            fi
        fi
    else
        echo "  [OK] Within limits"
    fi
else
    echo ""
    echo "--- JOURNAL.md ---"
    echo "  [SKIP] File not found"
fi

# ─────────────────────────────────────────────────────
# 3. CHANGELOG.md archiving
# ─────────────────────────────────────────────────────

CHANGELOG_FILE="$HXSK_DIR/CHANGELOG.md"
if [[ -f "$CHANGELOG_FILE" ]]; then
    ENTRY_COUNT=$(grep -c "^## \[" "$CHANGELOG_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)

    echo ""
    echo "--- CHANGELOG.md ---"
    echo "  Entries: ${ENTRY_COUNT} (keep: 20)"

    if [[ "$ENTRY_COUNT" -gt 20 ]]; then
        ARCHIVE_FILE="$ARCHIVE_DIR/changelog-${YEAR_MONTH}.md"
        echo "  [ACTION] Would archive $(($ENTRY_COUNT - 20)) old entries to $ARCHIVE_FILE"

        if [[ "$DRY_RUN" == false ]]; then
            # Archive old entries
            ENTRY_LINES=$(grep -n "^## \[" "$CHANGELOG_FILE" | cut -d: -f1)
            ENTRY_ARRAY=($ENTRY_LINES)
            KEEP_FROM_IDX=$((${#ENTRY_ARRAY[@]} - 20))

            if [[ $KEEP_FROM_IDX -gt 0 ]]; then
                KEEP_FROM_LINE=${ENTRY_ARRAY[$KEEP_FROM_IDX]}

                # Extract header (before first entry)
                HEADER_END=$((${ENTRY_ARRAY[0]} - 1))
                if [[ $HEADER_END -gt 0 ]]; then
                    head -n "$HEADER_END" "$CHANGELOG_FILE" > "$CHANGELOG_FILE.tmp"
                else
                    echo "# Changelog" > "$CHANGELOG_FILE.tmp"
                    echo "" >> "$CHANGELOG_FILE.tmp"
                fi

                # Archive old entries
                if [[ ! -f "$ARCHIVE_FILE" ]]; then
                    echo "# Changelog Archive - ${YEAR_MONTH}" > "$ARCHIVE_FILE"
                    echo "" >> "$ARCHIVE_FILE"
                fi
                sed -n "${ENTRY_ARRAY[0]},$((KEEP_FROM_LINE - 1))p" "$CHANGELOG_FILE" >> "$ARCHIVE_FILE"

                # Keep recent entries
                tail -n "+$KEEP_FROM_LINE" "$CHANGELOG_FILE" >> "$CHANGELOG_FILE.tmp"
                mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"

                echo "  [DONE] Archived $(($ENTRY_COUNT - 5)) entries to $ARCHIVE_FILE"
            fi
        fi
    else
        echo "  [OK] Within limits"
    fi
else
    echo ""
    echo "--- CHANGELOG.md ---"
    echo "  [SKIP] File not found"
fi

# ─────────────────────────────────────────────────────
# 4. prd-active.json cleanup
# ─────────────────────────────────────────────────────

PRD_ACTIVE="$HXSK_DIR/prd-active.json"
PRD_DONE="$HXSK_DIR/prd-done.json"
if [[ -f "$PRD_ACTIVE" ]]; then
    PENDING_COUNT=$(jq '.tasks | length' "$PRD_ACTIVE" 2>/dev/null || echo 0)
    PRD_SIZE=$(wc -c < "$PRD_ACTIVE" | tr -d ' ')

    echo ""
    echo "--- prd-active.json ---"
    echo "  Pending tasks: ${PENDING_COUNT}"
    echo "  Size: ${PRD_SIZE}B (limit: 3072B)"

    if [[ "$PRD_SIZE" -gt 3072 ]]; then
        echo "  [WARN] Exceeds size limit - consider splitting into phases"
    else
        echo "  [OK] Within limits"
    fi
else
    echo ""
    echo "--- prd-active.json ---"
    echo "  [SKIP] File not found"
fi

# ─────────────────────────────────────────────────────
# 5. Memory cleanup (session-summary, snapshot, execution-summary)
# ─────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORY_CLEANUP="$PROJECT_DIR/.hxsk/scripts/memory-cleanup.sh"

if [[ -x "$MEMORY_CLEANUP" ]]; then
    echo ""
    echo "--- Memory Cleanup ---"
    if [[ "$DRY_RUN" == true ]]; then
        bash "$MEMORY_CLEANUP" --dry-run 2>/dev/null | grep -E '^\s*(Archived|Deleted|Kept|Total|Active|\[EMPTY\])' || true
    else
        bash "$MEMORY_CLEANUP" 2>/dev/null | grep -E '^\s*(Archived|Deleted|Kept|Total|Active|\[EMPTY\])' || true
    fi
else
    echo ""
    echo "--- Memory Cleanup ---"
    echo "  [SKIP] scripts/memory-cleanup.sh not found"
fi

# ─────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo " Compaction Complete"
echo "================================================================"

if [[ "$DRY_RUN" == true ]]; then
    echo "Run without --dry-run to apply changes"
fi
