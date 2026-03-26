#!/usr/bin/env bash
# issue-create.sh — 이슈 생성 (파일 기반)
# Usage:
#   bash scripts/issue-create.sh master <title>
#   bash scripts/issue-create.sh work <master-id> <title> <wave> [depends_on] [files] [side_effect_files]
#   bash scripts/issue-create.sh <title> <type> <priority> [description]  (레거시)
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
mkdir -p "$ISSUES_DIR"
mkdir -p "$ISSUES_DIR/archive"

MODE="${1:?Usage: issue-create.sh master|work|<title> ...}"
TIMESTAMP=$(date '+%Y-%m-%d')

# --- MASTER 모드 ---
if [ "$MODE" = "master" ]; then
    TITLE="${2:?Usage: issue-create.sh master <title>}"

    # 다음 MASTER 번호
    LAST_NUM=$(find "$ISSUES_DIR" -maxdepth 1 -name 'MASTER-*.md' 2>/dev/null \
        | sed 's|.*/MASTER-||; s|\.md$||' | sort -n | tail -1)
    NEXT_NUM=$(printf "%03d" $(( ${LAST_NUM:-0} + 1 )))

    FILENAME="MASTER-${NEXT_NUM}.md"

    cat > "$ISSUES_DIR/$FILENAME" << EOF
---
id: MASTER-${NEXT_NUM}
title: "${TITLE}"
branch: feat/master-${NEXT_NUM}
status: draft
works: []
wave_plan:
  wave-1: []
created: ${TIMESTAMP}
---

## Objective
${TITLE}

## Progress
- [ ] Wave 1 (0/0)

## Merge Log

## Notes
EOF

    echo "[CREATED] $ISSUES_DIR/$FILENAME"
    exit 0
fi

# --- WORK 모드 ---
if [ "$MODE" = "work" ]; then
    MASTER_ID="${2:?Usage: issue-create.sh work <master-id> <title> <wave> [depends_on] [files] [side_effect_files]}"
    TITLE="${3:?Usage: issue-create.sh work <master-id> <title> <wave> ...}"
    WAVE="${4:-1}"
    DEPENDS_ON="${5:-}"
    FILES="${6:-}"
    SIDE_EFFECT_FILES="${7:-}"

    # MASTER 존재 확인
    if [ ! -f "$ISSUES_DIR/MASTER-${MASTER_ID}.md" ]; then
        echo "[FAIL] MASTER-${MASTER_ID}.md not found in $ISSUES_DIR"
        exit 1
    fi

    # 다음 WORK seq 번호
    LAST_SEQ=$(find "$ISSUES_DIR" -maxdepth 1 -name "WORK-${MASTER_ID}-*.md" 2>/dev/null \
        | sed "s|.*/WORK-${MASTER_ID}-||; s|\.md$||" | sort -n | tail -1)
    NEXT_SEQ=$(( ${LAST_SEQ:-0} + 1 ))

    FILENAME="WORK-${MASTER_ID}-${NEXT_SEQ}.md"

    # depends_on 포맷: 쉼표 구분 → YAML 배열
    if [ -n "$DEPENDS_ON" ]; then
        DEPENDS_YAML=$(echo "$DEPENDS_ON" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk '{printf "  - %s\n", $0}')
        DEPENDS_BLOCK="depends_on:
${DEPENDS_YAML}"
    else
        DEPENDS_BLOCK="depends_on: []"
    fi

    # files 포맷: 쉼표 구분 → YAML 배열
    if [ -n "$FILES" ]; then
        FILES_YAML=$(echo "$FILES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk '{printf "  - %s\n", $0}')
        FILES_BLOCK="files:
${FILES_YAML}"
    else
        FILES_BLOCK="files: []"
    fi

    # side_effect_files 포맷
    if [ -n "$SIDE_EFFECT_FILES" ]; then
        SE_YAML=$(echo "$SIDE_EFFECT_FILES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk '{printf "  - %s\n", $0}')
        SE_BLOCK="side_effect_files:
${SE_YAML}"
    else
        SE_BLOCK="side_effect_files: []"
    fi

    cat > "$ISSUES_DIR/$FILENAME" << EOF
---
id: WORK-${MASTER_ID}-${NEXT_SEQ}
master: MASTER-${MASTER_ID}
title: "${TITLE}"
status: pending
wave: ${WAVE}
${DEPENDS_BLOCK}
${FILES_BLOCK}
${SE_BLOCK}
worktree: ""
worktree_branch: ""
---

## Tasks
1. [ ] <!-- Task 1 -->

## Result

## Failure Log
EOF

    echo "[CREATED] $ISSUES_DIR/$FILENAME"
    exit 0
fi

# --- 레거시 모드 ---
TITLE="$MODE"
TYPE="${2:-task}"
PRIORITY="${3:-P2}"
DESCRIPTION="${4:-}"

# 다음 이슈 번호 (레거시: MASTER/WORK 제외)
LAST_NUM=$(find "$ISSUES_DIR" -maxdepth 1 -name '[0-9]*.md' 2>/dev/null \
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
