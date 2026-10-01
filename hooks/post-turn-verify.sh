#!/usr/bin/env bash
# Hook: Stop — 대화 턴 종료 시 코드 품질 게이트
# Qlty 우선 → ruff fallback (하위 호환)
# 수정된 소스 파일이 있으면 lint 결과를 경고로 출력

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TRACK_LOG="$PROJECT_DIR/.hxsk/.track-modifications.log"

# stdin(Stop hook input, last_assistant_message 포함)과 이번 턴의 Bash 실행 기록을 먼저 읽는다.
# Stop 훅은 병렬 실행되고 stop-context-save 가 로그를 지우므로, 느린 lint 전에 읽어야 한다.
AGENT_OUTPUT=""
if [ ! -t 0 ]; then
    AGENT_OUTPUT=$(cat 2>/dev/null || true)
fi
RAN_BASH=0
grep -q $'\tBash\t' "$TRACK_LOG" 2>/dev/null && RAN_BASH=1

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
            # -i.bak: GNU/BSD sed 공통 문법, 파일 권한(실행 비트) 유지
            sed -i.bak $'s/\r$//' "$filepath" && rm -f "$filepath.bak"
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

# 완료 키워드 탐지 (최종 완료 패턴만 — 중간 보고 제외)
# 코드 변경이 있는데 이번 턴에 Bash(test/build) 실행 기록이 없으면 경고.
# 기록은 track-modifications 가 .hxsk/ 있는 프로젝트에서만 남기므로 그 경우에만 판단한다.
COMPLETION_KEYWORDS="(완료했습니다|완료됐습니다|모두 완료|all done|all tests pass|successfully completed)"
if [[ -d "$PROJECT_DIR/.hxsk" && "$RAN_BASH" -eq 0 ]] && echo "$AGENT_OUTPUT" | grep -qiE "$COMPLETION_KEYWORDS"; then
    echo "⚠️ 완료를 선언했으나 검증 명령(test/build) 실행 증거가 없습니다." >&2
    echo "   Iron Law: NO COMPLETION WITHOUT VERIFICATION" >&2
fi

exit 0
