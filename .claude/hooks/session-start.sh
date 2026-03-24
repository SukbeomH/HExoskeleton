#!/bin/bash
# Hook: SessionStart — HXSK 상태 자동 로드
# 세션 시작 시 .hxsk/STATE.md와 git status를 additionalContext로 주입

main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    HXSK_DIR="$PROJECT_DIR/.hxsk"
    HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
    CONTEXT_PARTS=()

    # JSON 파싱 추상화 로드
    source "$HOOK_DIR/_json_parse.sh"

    # 1. CURRENT.md 로드 (현재 세션 컨텍스트)
    CURRENT_FILE="$HXSK_DIR/CURRENT.md"
    if [ -f "$CURRENT_FILE" ]; then
        CURRENT_CONTENT=$(head -15 "$CURRENT_FILE" 2>/dev/null || true)
        if [ -n "$CURRENT_CONTENT" ] && ! grep -q "^<!-- Current task ID" "$CURRENT_FILE"; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## Current Session Context (from .hxsk/CURRENT.md)")
            CONTEXT_PARTS+=("$CURRENT_CONTENT")
        fi
    fi

    # 2. STATE.md 로드 (상위 30줄)
    STATE_FILE="$HXSK_DIR/STATE.md"
    if [ -f "$STATE_FILE" ]; then
        STATE_CONTENT=$(head -30 "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$STATE_CONTENT" ]; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## HXSK State (from .hxsk/STATE.md)")
            CONTEXT_PARTS+=("$STATE_CONTENT")
        fi
    fi

    # 3. Git 미커밋 변경사항 요약
    GIT_STATUS=$(git -C "$PROJECT_DIR" status --short 2>/dev/null || true)
    if [ -n "$GIT_STATUS" ]; then
        FILE_COUNT=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')
        CONTEXT_PARTS+=("")
        CONTEXT_PARTS+=("## Uncommitted Changes ($FILE_COUNT files)")
        CONTEXT_PARTS+=("$GIT_STATUS")
    fi

    # 4. 최근 커밋 3개
    RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null || true)
    if [ -n "$RECENT_COMMITS" ]; then
        CONTEXT_PARTS+=("")
        CONTEXT_PARTS+=("## Recent Commits")
        CONTEXT_PARTS+=("$RECENT_COMMITS")
    fi

    # 5. Memory Recall (파일 기반 메모리에서 최근 프로젝트 메모리)
    MEMORY_OUTPUT=$("$HOOK_DIR/md-recall-memory.sh" "project context" "$PROJECT_DIR" 3 2>/dev/null || true)
    if [ -n "$MEMORY_OUTPUT" ]; then
        CONTEXT_PARTS+=("")
        CONTEXT_PARTS+=("## Recent Memory Context")
        CONTEXT_PARTS+=("$MEMORY_OUTPUT")
    fi

    # 컨텍스트가 있으면 JSON으로 출력
    if [ ${#CONTEXT_PARTS[@]} -gt 0 ]; then
        COMBINED=""
        for part in "${CONTEXT_PARTS[@]}"; do
            COMBINED="${COMBINED}${part}
"
        done
        # JSON escape 처리
        CTX_JSON=$(json_dumps "$COMBINED")
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":${CTX_JSON}}}"
    fi
}

# 메인 실행 및 에러 캡처
ERROR_OUTPUT=$(main 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$ERROR_OUTPUT" | grep -qiE '(error|permission denied|no such file)'; then
    HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$HOOK_DIR/_json_parse.sh"
    ERROR_MSG=$(echo "$ERROR_OUTPUT" | head -3 | tr '\n' ' ' | cut -c1-200)
    ERROR_JSON=$(json_dumps "$ERROR_MSG")
    echo "{\"status\":\"error\",\"message\":${ERROR_JSON}}"
else
    echo "$ERROR_OUTPUT"
fi

exit 0
