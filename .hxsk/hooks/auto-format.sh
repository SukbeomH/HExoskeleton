#!/bin/bash
# Hook: PostToolUse (Edit|Write) — 소스 파일 자동 포맷
# Qlty 우선 → 확장자별 fallback (하위 호환)
set -uo pipefail

# JSON 파싱 추상화 로드
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/_json_parse.sh"

# stdin에서 JSON 읽기
INPUT=$(cat)

# file_path 추출
FILE_PATH=$(json_get "$INPUT" '.tool_input.file_path // empty')

# 파일 경로가 없거나 파일이 없으면 종료
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Qlty 우선: 설치되어 있으면 qlty fmt 사용
if command -v qlty &>/dev/null && [[ -f "${CLAUDE_PROJECT_DIR:-.}/.qlty/qlty.toml" ]]; then
    qlty fmt "$FILE_PATH" 2>/dev/null || true
    exit 0
fi

# Fallback: 확장자별 언어 감지
case "$FILE_PATH" in
    *.py)
        uv run ruff format "$FILE_PATH" 2>/dev/null || true
        uv run ruff check --fix "$FILE_PATH" 2>/dev/null || true
        ;;
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs)
        if command -v prettier &>/dev/null; then
            prettier --write "$FILE_PATH" 2>/dev/null || true
        elif command -v npx &>/dev/null; then
            npx prettier --write "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    *.go)
        if command -v gofmt &>/dev/null; then
            gofmt -w "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    *.rs)
        if command -v rustfmt &>/dev/null; then
            rustfmt "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
esac

exit 0
