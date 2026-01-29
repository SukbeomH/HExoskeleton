#!/usr/bin/env bash
# Hook: Stop — 대화 턴 종료 시 코드 품질 게이트
# 수정된 Python 파일이 있으면 ruff check 결과를 경고로 출력

main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

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
    # 변경된 Python 파일 감지
    # ─────────────────────────────────────────────────────

    # 삭제된 파일 제외 (D 상태), 존재하는 .py 파일만 수집
    PY_CHANGES=""
    while IFS= read -r line; do
        status="${line:0:2}"
        file="${line:3}"
        # D(삭제) 상태 제외
        if [[ "$status" == *D* ]]; then
            continue
        fi
        if [[ "$file" == *.py ]] && [[ -f "$PROJECT_DIR/$file" ]]; then
            PY_CHANGES="${PY_CHANGES} ${file}"
        fi
    done < <(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)

    PY_CHANGES=$(echo "$PY_CHANGES" | xargs)

    if [[ -z "$PY_CHANGES" ]]; then
        echo '{"status":"skipped","reason":"no_python_changes"}'
        exit 0
    fi

    # ─────────────────────────────────────────────────────
    # ruff check 실행 (자동 수정 불가능한 이슈만 리포트)
    # ─────────────────────────────────────────────────────

    RUFF_OUTPUT=$(cd "$PROJECT_DIR" && uv run ruff check --no-fix $PY_CHANGES 2>/dev/null || true)

    if [[ -n "$RUFF_OUTPUT" ]]; then
        # ruff 출력에서 "Found X errors" 패턴으로 이슈 개수 추출
        ISSUE_COUNT=$(echo "$RUFF_OUTPUT" | grep -oE 'Found [0-9]+ errors?' | grep -oE '[0-9]+' || echo "0")
        if [[ "$ISSUE_COUNT" -gt 0 ]]; then
            # JSON 출력 (python json.dumps로 안전하게 이스케이프)
            ISSUES_PREVIEW=$(echo "$RUFF_OUTPUT" | head -10 | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))")
            echo "{\"status\":\"warning\",\"lint_issues\":${ISSUE_COUNT},\"preview\":${ISSUES_PREVIEW}}"
            exit 0
        fi
    fi

    echo '{"status":"success","lint_issues":0}'
}

# 메인 실행 및 에러 캡처
ERROR_OUTPUT=$(main 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$ERROR_OUTPUT" | grep -qiE '(error|permission denied|no such file)'; then
    python3 -c "
import json, sys
msg = sys.stdin.read().strip()
msg = ' '.join(msg[:200].split())
print(json.dumps({'status': 'error', 'message': msg}))
" <<< "$ERROR_OUTPUT"
else
    echo "$ERROR_OUTPUT"
fi

exit 0
