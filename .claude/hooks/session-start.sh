#!/bin/bash
# Hook: SessionStart — GSD 상태 자동 로드
# 세션 시작 시 .gsd/STATE.md와 git status를 additionalContext로 주입

main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    GSD_DIR="$PROJECT_DIR/.gsd"
    CONTEXT_PARTS=()

    # 1. PATTERNS.md 로드 (핵심 패턴, 2KB 제한)
    PATTERNS_FILE="$GSD_DIR/PATTERNS.md"
    if [ -f "$PATTERNS_FILE" ]; then
        PATTERNS_CONTENT=$(head -60 "$PATTERNS_FILE" 2>/dev/null || true)
        if [ -n "$PATTERNS_CONTENT" ]; then
            CONTEXT_PARTS+=("## Codebase Patterns (from .gsd/PATTERNS.md)")
            CONTEXT_PARTS+=("$PATTERNS_CONTENT")
        fi
    fi

    # 2. CURRENT.md 로드 (현재 세션 컨텍스트)
    CURRENT_FILE="$GSD_DIR/CURRENT.md"
    if [ -f "$CURRENT_FILE" ]; then
        CURRENT_CONTENT=$(cat "$CURRENT_FILE" 2>/dev/null || true)
        if [ -n "$CURRENT_CONTENT" ] && ! grep -q "^<!-- Current task ID" "$CURRENT_FILE"; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## Current Session Context (from .gsd/CURRENT.md)")
            CONTEXT_PARTS+=("$CURRENT_CONTENT")
        fi
    fi

    # 3. STATE.md 로드 (상위 80줄)
    STATE_FILE="$GSD_DIR/STATE.md"
    if [ -f "$STATE_FILE" ]; then
        STATE_CONTENT=$(head -80 "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$STATE_CONTENT" ]; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## GSD State (from .gsd/STATE.md)")
            CONTEXT_PARTS+=("$STATE_CONTENT")
        fi
    fi

    # 4. Git 미커밋 변경사항 요약
    GIT_STATUS=$(git -C "$PROJECT_DIR" status --short 2>/dev/null || true)
    if [ -n "$GIT_STATUS" ]; then
        FILE_COUNT=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')
        CONTEXT_PARTS+=("")
        CONTEXT_PARTS+=("## Uncommitted Changes ($FILE_COUNT files)")
        CONTEXT_PARTS+=("$GIT_STATUS")
    fi

    # 5. 최근 커밋 3개
    RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null || true)
    if [ -n "$RECENT_COMMITS" ]; then
        CONTEXT_PARTS+=("")
        CONTEXT_PARTS+=("## Recent Commits")
        CONTEXT_PARTS+=("$RECENT_COMMITS")
    fi

    # 컨텍스트가 있으면 JSON으로 출력
    if [ ${#CONTEXT_PARTS[@]} -gt 0 ]; then
        COMBINED=""
        for part in "${CONTEXT_PARTS[@]}"; do
            COMBINED="${COMBINED}${part}
"
        done
        # Python으로 JSON escape 처리
        python3 -c "
import json, sys
ctx = sys.stdin.read().strip()
if ctx:
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'SessionStart',
            'additionalContext': ctx
        }
    }))
" <<< "$COMBINED"
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
