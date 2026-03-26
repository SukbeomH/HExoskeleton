#!/bin/bash
# Hook: SessionStart — HXSK 상태 자동 로드
# source 필드 기반 분기: startup(풀) / resume(최소) / compact(핵심)
# source 미제공 시 .session-active 마커로 fallback 판별

main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    HXSK_DIR="$PROJECT_DIR/.hxsk"
    HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
    CONTEXT_PARTS=()

    # JSON 파싱 추상화 로드
    source "$HOOK_DIR/_json_parse.sh"

    # ─── Source 감지 ───
    # stdin에서 JSON을 읽어 source 필드 파싱 시도
    local INPUT=""
    if [ -t 0 ]; then
        INPUT="{}"
    else
        INPUT=$(cat 2>/dev/null || echo "{}")
    fi

    local SOURCE=""
    SOURCE=$(echo "$INPUT" | json_get "source" 2>/dev/null || true)

    # source가 없으면 .session-active 마커로 fallback
    if [ -z "$SOURCE" ]; then
        if [ -f "$HXSK_DIR/.session-active" ]; then
            SOURCE="resume"
        else
            SOURCE="startup"
        fi
    fi

    # ─── startup: 풀 컨텍스트 로드 ───
    if [ "$SOURCE" = "startup" ]; then
        # .session-active 마커 생성
        touch "$HXSK_DIR/.session-active" 2>/dev/null || true

        # 1. CURRENT.md 로드
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

        # 5. Memory Recall (2-hop)
        MEMORY_OUTPUT=$("$HOOK_DIR/md-recall-memory.sh" "project context" "$PROJECT_DIR" 3 2>/dev/null || true)
        if [ -n "$MEMORY_OUTPUT" ]; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## Recent Memory Context")
            CONTEXT_PARTS+=("$MEMORY_OUTPUT")
        fi

    # ─── resume: 최소 컨텍스트 ───
    elif [ "$SOURCE" = "resume" ]; then
        # CURRENT.md만
        CURRENT_FILE="$HXSK_DIR/CURRENT.md"
        if [ -f "$CURRENT_FILE" ]; then
            CURRENT_CONTENT=$(head -15 "$CURRENT_FILE" 2>/dev/null || true)
            if [ -n "$CURRENT_CONTENT" ] && ! grep -q "^<!-- Current task ID" "$CURRENT_FILE"; then
                CONTEXT_PARTS+=("")
                CONTEXT_PARTS+=("## Current Session Context (from .hxsk/CURRENT.md)")
                CONTEXT_PARTS+=("$CURRENT_CONTENT")
            fi
        fi

        # Git 미커밋만
        GIT_STATUS=$(git -C "$PROJECT_DIR" status --short 2>/dev/null || true)
        if [ -n "$GIT_STATUS" ]; then
            FILE_COUNT=$(echo "$GIT_STATUS" | wc -l | tr -d ' ')
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## Uncommitted Changes ($FILE_COUNT files)")
            CONTEXT_PARTS+=("$GIT_STATUS")
        fi

    # ─── compact: 핵심 상태만 ───
    elif [ "$SOURCE" = "compact" ]; then
        # STATE.md 첫 15줄만
        STATE_FILE="$HXSK_DIR/STATE.md"
        if [ -f "$STATE_FILE" ]; then
            STATE_CONTENT=$(head -15 "$STATE_FILE" 2>/dev/null || true)
            if [ -n "$STATE_CONTENT" ]; then
                CONTEXT_PARTS+=("")
                CONTEXT_PARTS+=("## HXSK State (from .hxsk/STATE.md)")
                CONTEXT_PARTS+=("$STATE_CONTENT")
            fi
        fi
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
