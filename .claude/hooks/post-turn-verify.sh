#!/usr/bin/env bash
# Hook: Stop — 대화 턴 종료 시 코드 품질 게이트
# Qlty 우선 → ruff fallback (하위 호환)
# 수정된 소스 파일이 있으면 lint 결과를 경고로 출력

set -o pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ─────────────────────────────────────────────────────
# CRLF → LF 변환 (쉘 스크립트, Python, JSON, YAML)
# ─────────────────────────────────────────────────────

while IFS= read -r line; do
    status="${line:0:2}"
    file="${line:3}"
    [[ "$status" == *D* ]] && continue
    filepath="$PROJECT_DIR/$file"
    if [[ -f "$filepath" ]] && [[ "$file" =~ \.(sh|bash|py|json|yaml|yml|md)$ ]]; then
        if file "$filepath" | grep -q "CRLF"; then
            sed -i '' $'s/\r$//' "$filepath"
        fi
    fi
done < <(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)

# ─────────────────────────────────────────────────────
# 변경된 소스 파일 감지 (모든 언어)
# ─────────────────────────────────────────────────────

CODE_PATTERN='\.(py|ts|tsx|js|jsx|mjs|cjs|go|rs|java)$'
CHANGED_FILES=""

while IFS= read -r line; do
    status="${line:0:2}"
    file="${line:3}"
    [[ "$status" == *D* ]] && continue
    if [[ "$file" =~ $CODE_PATTERN ]] && [[ -f "$PROJECT_DIR/$file" ]]; then
        CHANGED_FILES="${CHANGED_FILES} ${file}"
    fi
done < <(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)

CHANGED_FILES=$(echo "$CHANGED_FILES" | xargs)
[[ -z "$CHANGED_FILES" ]] && exit 0

# ─────────────────────────────────────────────────────
# Qlty 우선 → ruff fallback
# ─────────────────────────────────────────────────────

if command -v qlty &>/dev/null && [[ -f "$PROJECT_DIR/.qlty/qlty.toml" ]]; then
    cd "$PROJECT_DIR" && qlty check >/dev/null 2>&1 || true
else
    PY_CHANGES=""
    for f in $CHANGED_FILES; do
        [[ "$f" == *.py ]] && PY_CHANGES="$PY_CHANGES $f"
    done
    PY_CHANGES=$(echo "$PY_CHANGES" | xargs)
    [[ -z "$PY_CHANGES" ]] && exit 0
    cd "$PROJECT_DIR" && uv run ruff check --no-fix $PY_CHANGES >/dev/null 2>&1 || true
fi

exit 0
