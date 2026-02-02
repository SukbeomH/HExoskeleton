#!/usr/bin/env bash
# Hook: Stop — 세션 컨텍스트 저장
# .gsd/.modified-this-session 플래그가 있을 때만 실행
# 1) claude -p (haiku)로 CURRENT.md 생성
# 2) mcp-memory-service JSON-RPC로 세션 메모리 저장
# 백그라운드 실행으로 hook timeout 회피

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAG_FILE="$PROJECT_DIR/.gsd/.modified-this-session"
CURRENT_MD="$PROJECT_DIR/.gsd/CURRENT.md"
LOG_FILE="$PROJECT_DIR/.gsd/.context-save.log"

# 플래그 파일 없으면 스킵
[[ -f "$FLAG_FILE" ]] || exit 0

# 플래그 즉시 삭제 (중복 실행 방지)
rm -f "$FLAG_FILE"

# 변경 정보 수집
MODIFIED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -30)
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIFF_STAT=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -5)
RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null)

# 백그라운드 실행
(
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    # ── 1. CURRENT.md 생성 (claude -p haiku) ──
    RESULT=$(claude -p "You are a session context saver. Output ONLY markdown.

Git context:
Branch: $BRANCH
Modified files:
$MODIFIED

Diff stats:
$DIFF_STAT

Recent commits:
$RECENT_COMMITS

Generate CURRENT.md with these sections:
- **Active Task**: Infer from changes
- **Branch**: $BRANCH
- **Working Files**: Modified file paths
- **Recent Changes**: 1-2 sentence summary
- **Last Updated**: $TS" \
    --model haiku \
    --system-prompt "Output only markdown. No tools. No conversation." \
    --disallowedTools "Bash,Edit,Write,Read,Glob,Grep,Task,WebFetch,WebSearch" \
    --output-format text 2>/dev/null) || true

    if [[ -n "$RESULT" ]]; then
        mkdir -p "$(dirname "$CURRENT_MD")"
        echo "$RESULT" > "$CURRENT_MD"
        echo "[$TS] CURRENT.md saved" >> "$LOG_FILE"
    else
        # fallback: claude -p 실패 시 기본 템플릿
        mkdir -p "$(dirname "$CURRENT_MD")"
        cat > "$CURRENT_MD" <<EOF
# Current Session Context

- **Branch**: $BRANCH
- **Last Updated**: $TS

## Working Files
\`\`\`
${MODIFIED:-No changes detected}
\`\`\`
EOF
        echo "[$TS] CURRENT.md saved (fallback)" >> "$LOG_FILE"
    fi

    # ── 2. mcp-memory-service 저장 (변경 파일이 1개 이상일 때) ──
    FILE_COUNT=$(echo "$MODIFIED" | grep -c '.' 2>/dev/null || echo "0")
    if [[ "$FILE_COUNT" -ge 1 ]] && command -v memory &>/dev/null; then
        # CURRENT.md가 있으면 풍부한 content 사용, 없으면 fallback
        if [[ -f "$CURRENT_MD" ]]; then
            MEMORY_CONTENT=$(head -30 "$CURRENT_MD" 2>/dev/null || true)
        else
            MEMORY_CONTENT="Branch: $BRANCH. Files changed: $FILE_COUNT. $(echo "$RECENT_COMMITS" | head -1)"
        fi
        "$HOOK_DIR/mcp-store-memory.sh" \
            "Session [$TS]: $BRANCH" \
            "$MEMORY_CONTENT" \
            "session-summary,branch:$BRANCH,auto" 2>/dev/null \
            && echo "[$TS] Memory stored" >> "$LOG_FILE" \
            || echo "[$TS] Memory store failed" >> "$LOG_FILE"
    fi
) &

exit 0
