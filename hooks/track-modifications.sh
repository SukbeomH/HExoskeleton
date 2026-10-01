#!/bin/bash
# Hook: PostToolUse (Edit|Write|Bash) — 수정 플래그 설정 + 변경 파일 로그
# CURRENT.md 업데이트가 필요한지 추적하고 변경 파일 경로를 누적 기록

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
FLAG_FILE="$PROJECT_DIR/.hxsk/.modified-this-session"
TRACK_LOG="$PROJECT_DIR/.hxsk/.track-modifications.log"

# opt-in: .hxsk/ 가 있는(초기화된) 프로젝트에서만 기록
[[ -d "$PROJECT_DIR/.hxsk" ]] || exit 0

# 플래그 파일 생성 (수정 발생 표시)
touch "$FLAG_FILE"

# stdin hook input JSON → "시각<TAB>도구<TAB>file_path 또는 command(한 줄, 200자)" 누적
[[ -t 0 ]] && exit 0
source "$(dirname "$0")/_json_parse.sh"
INPUT=$(cat)
TOOL_NAME=$(json_get "$INPUT" '.tool_name // empty')
TARGET=$(json_get "$INPUT" '.tool_input.file_path // empty')
[[ -n "$TARGET" ]] || TARGET=$(json_get "$INPUT" '.tool_input.command // empty')
TARGET="${TARGET//$'\n'/ }"
TARGET="${TARGET//$'\t'/ }"
printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${TOOL_NAME:-unknown}" "${TARGET:0:200}" >> "$TRACK_LOG"

exit 0
