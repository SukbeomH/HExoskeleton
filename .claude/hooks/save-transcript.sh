#!/bin/bash
# Hook: SessionEnd — 대화 내역을 프로젝트에 저장
#
# Claude Code의 세션 transcript를 프로젝트의 .sessions/ 디렉토리에 복사합니다.
# 파일명 형식: {session-id}-{timestamp}.jsonl
#
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.sessions"

# 세션 디렉토리 생성
mkdir -p "$SESSION_DIR"

# Claude 프로젝트 경로 계산 (macOS 기준)
# ~/.claude/projects/ 하위에 프로젝트 경로가 하이픈으로 변환되어 저장됨
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
PROJECT_PATH_ESCAPED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
CLAUDE_PROJECT_PATH="$CLAUDE_PROJECTS_DIR/$PROJECT_PATH_ESCAPED"

# 가장 최근 수정된 .jsonl 파일 찾기
LATEST_TRANSCRIPT=$(ls -t "$CLAUDE_PROJECT_PATH"/*.jsonl 2>/dev/null | head -1)

if [ -n "$LATEST_TRANSCRIPT" ] && [ -f "$LATEST_TRANSCRIPT" ]; then
    SESSION_ID=$(basename "$LATEST_TRANSCRIPT" .jsonl)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    DEST_FILE="$SESSION_DIR/${SESSION_ID}-${TIMESTAMP}.jsonl"

    # 이미 복사된 경우 스킵 (동일 세션 ID로 시작하는 파일 체크)
    if ls "$SESSION_DIR/${SESSION_ID}"-*.jsonl 1>/dev/null 2>&1; then
        # 파일 크기 비교 - 새 버전이 더 크면 덮어쓰기
        EXISTING=$(ls -t "$SESSION_DIR/${SESSION_ID}"-*.jsonl | head -1)
        EXISTING_SIZE=$(stat -f%z "$EXISTING" 2>/dev/null || stat -c%s "$EXISTING" 2>/dev/null || echo 0)
        NEW_SIZE=$(stat -f%z "$LATEST_TRANSCRIPT" 2>/dev/null || stat -c%s "$LATEST_TRANSCRIPT" 2>/dev/null || echo 0)

        if [ "$NEW_SIZE" -gt "$EXISTING_SIZE" ]; then
            cp "$LATEST_TRANSCRIPT" "$DEST_FILE"
            echo "[transcript] Updated: $DEST_FILE"
        fi
    else
        cp "$LATEST_TRANSCRIPT" "$DEST_FILE"
        echo "[transcript] Saved: $DEST_FILE"
    fi
fi

exit 0
