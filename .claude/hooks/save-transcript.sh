#!/bin/bash
# Hook: SessionEnd — 대화 내역을 프로젝트에 저장
#
# Claude Code의 세션 transcript를 프로젝트의 .sessions/ 디렉토리에 복사합니다.
# 파일명 형식: {session-id}-{timestamp}.jsonl
#
# stdin 입력 (JSON):
#   session_id: 세션 ID
#   transcript_path: transcript 파일 경로
#   reason: 종료 이유 (exit, clear, logout 등)
#
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.sessions"

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

# JSON에서 transcript_path와 session_id 추출
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('session_id',''))" 2>/dev/null || echo "")

# transcript_path가 없으면 fallback으로 직접 탐색
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    # Fallback: Claude 프로젝트 경로에서 직접 탐색
    CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
    PROJECT_PATH_ESCAPED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    CLAUDE_PROJECT_PATH="$CLAUDE_PROJECTS_DIR/$PROJECT_PATH_ESCAPED"

    TRANSCRIPT_PATH=$(ls -t "$CLAUDE_PROJECT_PATH"/*.jsonl 2>/dev/null | head -1 || echo "")

    if [ -n "$TRANSCRIPT_PATH" ]; then
        SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)
    fi
fi

# transcript가 없으면 종료
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# 세션 디렉토리 생성
mkdir -p "$SESSION_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST_FILE="$SESSION_DIR/${SESSION_ID}-${TIMESTAMP}.jsonl"

# 이미 복사된 경우 스킵 (동일 세션 ID로 시작하는 파일 체크)
if ls "$SESSION_DIR/${SESSION_ID}"-*.jsonl 1>/dev/null 2>&1; then
    # 파일 크기 비교 - 새 버전이 더 크면 덮어쓰기
    EXISTING=$(ls -t "$SESSION_DIR/${SESSION_ID}"-*.jsonl | head -1)
    EXISTING_SIZE=$(stat -f%z "$EXISTING" 2>/dev/null || stat -c%s "$EXISTING" 2>/dev/null || echo 0)
    NEW_SIZE=$(stat -f%z "$TRANSCRIPT_PATH" 2>/dev/null || stat -c%s "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

    if [ "$NEW_SIZE" -gt "$EXISTING_SIZE" ]; then
        cp "$TRANSCRIPT_PATH" "$DEST_FILE"
        echo "[transcript] Updated: $DEST_FILE"
    fi
else
    cp "$TRANSCRIPT_PATH" "$DEST_FILE"
    echo "[transcript] Saved: $DEST_FILE"
fi

exit 0
