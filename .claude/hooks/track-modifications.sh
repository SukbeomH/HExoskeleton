#!/bin/bash
# Hook: PostToolUse (Edit|Write|Bash) — 수정 플래그 설정 + 변경 파일 로그
# CURRENT.md 업데이트가 필요한지 추적하고 변경 파일 경로를 누적 기록

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
FLAG_FILE="$PROJECT_DIR/.hxsk/.modified-this-session"
TRACK_LOG="$PROJECT_DIR/.hxsk/.track-modifications.log"

# 디렉토리 확보
mkdir -p "$PROJECT_DIR/.hxsk" 2>/dev/null || true

# 플래그 파일 생성 (수정 발생 표시)
touch "$FLAG_FILE"

# 변경 파일 경로를 로그에 누적 기록
# stdin으로 전달되는 hook input에서 tool_input.file_path 추출
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"
if [[ -n "${CLAUDE_TOOL_INPUT_FILE_PATH:-}" ]]; then
    FILE_PATH="$CLAUDE_TOOL_INPUT_FILE_PATH"
elif [[ -n "${CLAUDE_TOOL_INPUT_FILENAME:-}" ]]; then
    FILE_PATH="$CLAUDE_TOOL_INPUT_FILENAME"
else
    FILE_PATH=""
fi

if [[ -n "$FILE_PATH" ]]; then
    TS=$(date '+%Y-%m-%dT%H:%M:%S')
    printf '%s\t%s\t%s\n' "$TS" "$TOOL_NAME" "$FILE_PATH" >> "$TRACK_LOG"
fi

exit 0
