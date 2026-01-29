#!/bin/bash
# Hook: PreCompact — STATE.md 자동 백업
# 컨텍스트 압축 전 GSD 상태 문서를 백업하여 컨텍스트 손실 방지
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.gsd/STATE.md"
JOURNAL_FILE="$PROJECT_DIR/.gsd/JOURNAL.md"
PATTERNS_FILE="$PROJECT_DIR/.gsd/PATTERNS.md"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# STATE.md 백업
if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "${STATE_FILE}.pre-compact.bak"
fi

# JOURNAL.md 백업
if [ -f "$JOURNAL_FILE" ]; then
    cp "$JOURNAL_FILE" "${JOURNAL_FILE}.pre-compact.bak"
fi

# PATTERNS.md 백업 (핵심 패턴 보존)
if [ -f "$PATTERNS_FILE" ]; then
    cp "$PATTERNS_FILE" "${PATTERNS_FILE}.pre-compact.bak"
fi

# 백업이 하나라도 수행되었으면 additionalContext로 상태 요약 주입
if [ -f "${STATE_FILE}.pre-compact.bak" ]; then
    # STATE.md 상위 내용을 컨텍스트에 보존
    STATE_SUMMARY=$(head -40 "$STATE_FILE" 2>/dev/null || true)
    if [ -n "$STATE_SUMMARY" ]; then
        python3 -c "
import json, sys
ctx = sys.stdin.read().strip()
if ctx:
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreCompact',
            'additionalContext': '## Pre-Compact State Snapshot\n' + ctx
        }
    }))
" <<< "$STATE_SUMMARY"
    fi
fi

exit 0
