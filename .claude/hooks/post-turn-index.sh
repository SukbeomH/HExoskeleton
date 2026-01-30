#!/usr/bin/env bash
# Hook: Stop — 대화 턴 종료 시 코드 변경 감지 후 code-graph-rag 인덱싱
# 코드 파일이 변경된 경우에만 백그라운드로 인덱싱 실행

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
INDEX_DIR="${PROJECT_DIR}/.code-graph-rag"
LAST_INDEXED="${INDEX_DIR}/.last-indexed-at"
LOCK_FILE="${INDEX_DIR}/.index.lock"
LOG_FILE="${INDEX_DIR}/.index.log"

# ─────────────────────────────────────────────────────
# 코드 변경 감지
# ─────────────────────────────────────────────────────

CODE_PATTERN='\.(py|ts|tsx|js|jsx|go|rs|java|sh|sql|toml|yaml|yml)$'

has_changes() {
    local dirty
    dirty=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null \
        | grep -cE "$CODE_PATTERN" || true)
    if [[ "$dirty" -gt 0 ]]; then
        return 0
    fi

    if [[ -f "$LAST_INDEXED" ]]; then
        local last_commit current_commit
        last_commit=$(cat "$LAST_INDEXED" 2>/dev/null)
        current_commit=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")
        if [[ -n "$current_commit" && "$last_commit" != "$current_commit" ]]; then
            return 0
        fi
    else
        return 0
    fi

    return 1
}

has_changes || exit 0

# ─────────────────────────────────────────────────────
# 동시 실행 방지 (lock file)
# ─────────────────────────────────────────────────────

if [[ -f "$LOCK_FILE" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    [[ "$lock_age" -lt 300 ]] && exit 0
    rm -f "$LOCK_FILE"
fi

# ─────────────────────────────────────────────────────
# 백그라운드 인덱싱 실행
# ─────────────────────────────────────────────────────

mkdir -p "$INDEX_DIR"
echo $$ > "$LOCK_FILE"

(
    npx -y @er77/code-graph-rag-mcp index "$PROJECT_DIR" > "$LOG_FILE" 2>&1
    git -C "$PROJECT_DIR" rev-parse HEAD > "$LAST_INDEXED" 2>/dev/null
    rm -f "$LOCK_FILE"
) &

exit 0
