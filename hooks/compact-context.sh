#!/usr/bin/env bash

# Compact context files to maintain size limits
# Usage: bash hooks/compact-context.sh [--dry-run]
#
# Actions:
# 1. Check PATTERNS.md against 20 items / 2KB (warn only)
# 2. Prune local-tier memories (prune-memories.sh --auto)

set -o errexit
set -o nounset
set -o pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN] No files will be modified"
fi

HXSK_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk"

# Check if .hxsk directory exists
if [[ ! -d "$HXSK_DIR" ]]; then
    echo "[SKIP] .hxsk/ directory not found at $HXSK_DIR"
    echo "Run the hxsk-init skill (scripts/init-project.sh) to initialize HExoskeleton."
    exit 0
fi

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
# 2. Memory cleanup — --auto 모드 (설정 기반 전 tier 통합)
#    .hxsk/.prune-config의 PRUNE_DEFAULT_CAP / PRUNE_CAP_<tier> 참조.
#    shared-tier(execution-summary, root-cause 등)는 git 관리이므로 자동 정리 제외.
# ─────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PRUNE_SCRIPT="$SCRIPT_DIR/../skills/memory-protocol/scripts/prune-memories.sh"

if [[ -f "$PRUNE_SCRIPT" ]]; then
    echo ""
    echo "--- Memory Cleanup ---"
    dry_flag=()
    [[ "$DRY_RUN" == true ]] && dry_flag=(--dry-run)
    bash "$PRUNE_SCRIPT" --auto "${dry_flag[@]}" 2>/dev/null || true
else
    echo ""
    echo "--- Memory Cleanup ---"
    echo "  [SKIP] scripts/prune-memories.sh not found"
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
