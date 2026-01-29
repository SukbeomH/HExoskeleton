#!/bin/bash
# Hook: PostToolUse (Edit|Write|Bash) — 수정 플래그 설정
# CURRENT.md 업데이트가 필요한지 추적

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
FLAG_FILE="$PROJECT_DIR/.gsd/.modified-this-session"

# 플래그 파일 생성 (수정 발생 표시)
mkdir -p "$PROJECT_DIR/.gsd" 2>/dev/null || true
touch "$FLAG_FILE"

exit 0
