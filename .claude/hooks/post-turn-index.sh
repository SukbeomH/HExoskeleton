#!/usr/bin/env bash
# Hook: Stop — 대화 턴 종료 시 코드 변경 감지 후 code-graph-rag 인덱싱
# 코드 파일이 변경된 경우에만 백그라운드로 인덱싱 실행
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
INDEX_DIR="${PROJECT_DIR}/.code-graph-rag"
LAST_INDEXED="${INDEX_DIR}/.last-indexed-at"
LOCK_FILE="${INDEX_DIR}/.index.lock"
LOG_FILE="${INDEX_DIR}/.index.log"

# stdin에서 JSON 읽기
INPUT=$(cat)

# stop_hook_active 확인 — 무한 루프 방지
IS_ACTIVE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('stop_hook_active', False))
except:
    print('False')
" 2>/dev/null)

if [[ "$IS_ACTIVE" == "True" ]]; then
    echo '{"status":"skipped","reason":"stop_hook_active"}'
    exit 0
fi

# ─────────────────────────────────────────────────────
# 코드 변경 감지
# ─────────────────────────────────────────────────────

CODE_PATTERN='\.(py|ts|tsx|js|jsx|go|rs|java|sh|sql|toml|yaml|yml)$'

has_changes() {
    # 1. 커밋되지 않은 코드 파일 변경 (수정 + 스테이징 + 신규)
    local dirty
    dirty=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null \
        | grep -cE "$CODE_PATTERN" || true)
    if [[ "$dirty" -gt 0 ]]; then
        return 0
    fi

    # 2. 마지막 인덱싱 이후 새 커밋 존재
    if [[ -f "$LAST_INDEXED" ]]; then
        local last_commit current_commit
        last_commit=$(cat "$LAST_INDEXED" 2>/dev/null)
        current_commit=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")
        if [[ -n "$current_commit" && "$last_commit" != "$current_commit" ]]; then
            return 0
        fi
    else
        # 인덱싱 기록 없음 — 최초 실행
        return 0
    fi

    return 1
}

if ! has_changes; then
    echo '{"status":"skipped","reason":"no_code_changes"}'
    exit 0
fi

# ─────────────────────────────────────────────────────
# 동시 실행 방지 (lock file)
# ─────────────────────────────────────────────────────

if [[ -f "$LOCK_FILE" ]]; then
    # 5분 이상 된 lock은 stale로 간주
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [[ "$lock_age" -lt 300 ]]; then
        echo '{"status":"skipped","reason":"indexing_in_progress"}'
        exit 0
    fi
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

echo '{"status":"success","action":"indexing_started"}'
exit 0
