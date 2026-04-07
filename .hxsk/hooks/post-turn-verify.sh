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
    [[ -n "$PY_CHANGES" ]] && cd "$PROJECT_DIR" && uv run ruff check --no-fix $PY_CHANGES >/dev/null 2>&1 || true
fi

# ─────────────────────────────────────────────────────
# 완료 검증 게이트 — 코드 변경 시 검증 명령 실행 여부 확인
# Iron Law: NO COMPLETION WITHOUT VERIFICATION
# ─────────────────────────────────────────────────────

HXSK_DIR="$PROJECT_DIR/.hxsk"
TRACK_LOG="$HXSK_DIR/.track-modifications.log"

# stdin에서 에이전트 출력 읽기 (Stop 훅은 stop_hook_result 수신)
AGENT_OUTPUT=""
if [ ! -t 0 ]; then
    AGENT_OUTPUT=$(cat 2>/dev/null || true)
fi

# 완료 키워드 탐지 (최종 완료 패턴만 — 중간 보고 제외)
COMPLETION_KEYWORDS="(완료했습니다|완료됐습니다|모두 완료|all done|all tests pass|successfully completed)"
if echo "$AGENT_OUTPUT" | grep -qiE "$COMPLETION_KEYWORDS"; then
    # 코드 변경이 있는데 Bash(test/build) 실행 이력이 없으면 경고
    BASH_RUNS=$(grep -c "Bash" "$TRACK_LOG" 2>/dev/null || echo "0")
    if [[ "$BASH_RUNS" -eq 0 && -n "$CHANGED_FILES" ]]; then
        echo "⚠️ 완료를 선언했으나 검증 명령(test/build) 실행 증거가 없습니다." >&2
        echo "   Iron Law: NO COMPLETION WITHOUT VERIFICATION" >&2
    fi
fi

exit 0
