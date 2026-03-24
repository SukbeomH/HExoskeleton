#!/usr/bin/env bash
# issue-create.sh — 이슈 생성 (파일 기반)
# Usage: bash scripts/issue-create.sh <title> <type> <priority> [description]
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
mkdir -p "$ISSUES_DIR"

TITLE="${1:?Usage: issue-create.sh <title> <type> <priority> [description]}"
TYPE="${2:-task}"
PRIORITY="${3:-P2}"
DESCRIPTION="${4:-}"
TIMESTAMP=$(date '+%Y-%m-%d')

# 다음 이슈 번호
LAST_NUM=$(find "$ISSUES_DIR" -maxdepth 1 -name '*.md' 2>/dev/null \
    | sed 's|.*/||; s|-.*||' | sort -n | tail -1)
NEXT_NUM=$(printf "%03d" $(( ${LAST_NUM:-0} + 1 )))

# slug
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40)
FILENAME="${NEXT_NUM}-${SLUG}.md"

cat > "$ISSUES_DIR/$FILENAME" << EOF
---
id: ${NEXT_NUM}
title: "${TITLE}"
type: ${TYPE}
priority: ${PRIORITY}
status: open
wave: null
created: ${TIMESTAMP}
assignee: null
files: []
---

# ${TITLE}

${DESCRIPTION:-<!-- 이슈 설명 -->}

## Acceptance Criteria

- [ ] <!-- 완료 기준 -->
EOF

echo "[CREATED] $ISSUES_DIR/$FILENAME"
