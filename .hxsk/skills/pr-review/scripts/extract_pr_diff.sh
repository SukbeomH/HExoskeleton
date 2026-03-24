#!/usr/bin/env bash

# Extract PR diff and metadata for structured review.
# Usage: bash scripts/extract_pr_diff.sh [pr_number | branch_name]
#        bash scripts/extract_pr_diff.sh              # current branch vs main
#        bash scripts/extract_pr_diff.sh 123           # PR #123
#        bash scripts/extract_pr_diff.sh feat/login    # branch diff

set -o errexit
set -o nounset
set -o pipefail

TARGET="${1:-}"

# Detect base branch
BASE_BRANCH="main"
if git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    if ! git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
        BASE_BRANCH="master"
    fi
fi

echo "=== PR Diff Extraction ==="
echo ""

if [[ -n "$TARGET" ]] && [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    # PR number — use gh CLI
    if ! command -v gh &>/dev/null; then
        echo "Error: gh CLI not found. Install with: brew install gh"
        exit 1
    fi
    echo "## PR #${TARGET}"
    echo ""
    gh pr view "$TARGET" --json title,body,files,additions,deletions,changedFiles \
        --template '### {{.title}}
Files changed: {{.changedFiles}} (+{{.additions}} -{{.deletions}})

### Changed Files
{{range .files}}- {{.path}} (+{{.additions}} -{{.deletions}})
{{end}}' 2>/dev/null || echo "Error: Could not fetch PR #${TARGET}"
    echo ""
    echo "### Diff"
    gh pr diff "$TARGET" 2>/dev/null || echo "Error: Could not fetch diff"
else
    # Branch diff
    BRANCH="${TARGET:-$(git branch --show-current 2>/dev/null)}"
    echo "## Branch: ${BRANCH} (vs ${BASE_BRANCH})"
    echo ""

    # Stats
    echo "### Changed Files"
    git diff "${BASE_BRANCH}...${BRANCH}" --stat 2>/dev/null || \
        git diff "${BASE_BRANCH}..HEAD" --stat 2>/dev/null || \
        echo "Error: Could not compute diff"
    echo ""

    # Commit log
    echo "### Commits"
    git log "${BASE_BRANCH}..${BRANCH}" --oneline 2>/dev/null || \
        git log "${BASE_BRANCH}..HEAD" --oneline 2>/dev/null || \
        echo "No commits found"
    echo ""

    # Full diff
    echo "### Diff"
    git diff "${BASE_BRANCH}...${BRANCH}" 2>/dev/null || \
        git diff "${BASE_BRANCH}..HEAD" 2>/dev/null || \
        echo "Error: Could not compute diff"
fi
