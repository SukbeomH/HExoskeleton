#!/usr/bin/env bash
# merge-worktrees.sh — Subagent worktree 결과를 현재 브랜치에 merge
# Usage: bash scripts/merge-worktrees.sh <worktree-path> [branch-name]
set -euo pipefail

WORKTREE_PATH="${1:?Usage: merge-worktrees.sh <worktree-path> [branch-name]}"
BRANCH="${2:-}"

if [ -z "$BRANCH" ]; then
    BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null || true)
fi

if [ -z "$BRANCH" ]; then
    echo "[FAIL] Cannot determine branch for worktree: $WORKTREE_PATH"
    exit 1
fi

echo "=== Merging worktree ==="
echo "  Worktree: $WORKTREE_PATH"
echo "  Branch:   $BRANCH"

# 커밋 확인
CURRENT=$(git rev-parse HEAD)
MERGE_BASE=$(git merge-base HEAD "$BRANCH" 2>/dev/null || echo "")

if [ -z "$MERGE_BASE" ]; then
    echo "  [SKIP] No common ancestor with $BRANCH"
    exit 0
fi

COMMITS=$(git log --oneline "${MERGE_BASE}..${BRANCH}" 2>/dev/null || true)

if [ -z "$COMMITS" ]; then
    echo "  [SKIP] No new commits on $BRANCH"
    exit 0
fi

echo ""
echo "[Commits]"
echo "$COMMITS"
echo ""

# Merge 시도
if git merge --no-ff "$BRANCH" -m "merge: $BRANCH (subagent worktree)"; then
    echo ""
    echo "[OK] Merged $BRANCH successfully"

    # Worktree 정리
    git worktree remove "$WORKTREE_PATH" 2>/dev/null || true
    echo "[OK] Cleaned up worktree"
else
    echo ""
    echo "[CONFLICT] Merge conflict detected"
    echo ""
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U 2>/dev/null || true
    echo ""
    echo "Options:"
    echo "  1. Resolve manually and: git merge --continue"
    echo "  2. Abort merge: git merge --abort"
    echo "  3. Create issue: bash scripts/issue-create.sh 'Merge conflict: $BRANCH' bug P1"
    exit 2
fi
