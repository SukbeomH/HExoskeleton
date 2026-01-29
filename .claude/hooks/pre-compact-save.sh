#!/bin/bash
# Hook: PreCompact — STATE.md 자동 백업
# 컨텍스트 압축 전 GSD 상태 문서를 백업하여 컨텍스트 손실 방지

main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    GSD_DIR="$PROJECT_DIR/.gsd"
    STATE_FILE="$GSD_DIR/STATE.md"
    JOURNAL_FILE="$GSD_DIR/JOURNAL.md"
    PATTERNS_FILE="$GSD_DIR/PATTERNS.md"
    CURRENT_FILE="$GSD_DIR/CURRENT.md"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    # Skip if .gsd/ doesn't exist
    if [ ! -d "$GSD_DIR" ]; then
        exit 0
    fi

    # Clean old backup files (keep only latest)
    rm -f "$GSD_DIR"/*.pre-compact.bak 2>/dev/null || true

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

    # CURRENT.md 백업 (현재 세션 컨텍스트)
    if [ -f "$CURRENT_FILE" ]; then
        cp "$CURRENT_FILE" "${CURRENT_FILE}.pre-compact.bak"
    fi

    # compact-context.sh 실행 (자동 아카이빙)
    COMPACT_SCRIPT="$PROJECT_DIR/scripts/compact-context.sh"
    if [ -f "$COMPACT_SCRIPT" ]; then
        bash "$COMPACT_SCRIPT" 2>/dev/null || true
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
}

# 메인 실행 및 에러 캡처
ERROR_OUTPUT=$(main 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$ERROR_OUTPUT" | grep -qiE '(error|permission denied|no such file)'; then
    python3 -c "
import json, sys
msg = sys.stdin.read().strip()
msg = ' '.join(msg[:200].split())
print(json.dumps({'status': 'error', 'message': msg}))
" <<< "$ERROR_OUTPUT"
else
    echo "$ERROR_OUTPUT"
fi

exit 0
