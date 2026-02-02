#!/bin/bash
# Hook: SessionEnd — 세션 변경사항을 CHANGELOG.md에 기록
#
# Git 변경사항을 감지하여 .gsd/CHANGELOG.md에 추가합니다.
# 변경사항이 없으면 기록하지 않습니다.
#
# stdin 입력 (JSON):
#   session_id: 세션 ID
#   reason: 종료 이유 (exit, clear, logout 등)
#

# 메인 로직을 함수로 분리
main() {
    set -uo pipefail

    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    CHANGELOG="$PROJECT_DIR/.gsd/CHANGELOG.md"
    HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"

    # JSON 파싱 추상화 로드
    source "$HOOK_DIR/_json_parse.sh"

    # stdin에서 JSON 입력 읽기
    INPUT=$(cat)

    # JSON에서 session_id 추출
    SESSION_ID=$(json_get "$INPUT" '.session_id // empty')
    [[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

    # CHANGELOG 파일이 없으면 종료
    if [ ! -f "$CHANGELOG" ]; then
        exit 0
    fi

    cd "$PROJECT_DIR"

    # Git 변경사항 확인 (staged + unstaged + untracked)
    STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
    UNSTAGED_FILES=$(git diff --name-only 2>/dev/null || echo "")
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")

    # 모든 변경된 파일 병합 (중복 제거), .gsd/ 내부 파일 제외 (자기참조 방지)
    ALL_CHANGED=$(echo -e "$STAGED_FILES\n$UNSTAGED_FILES\n$UNTRACKED_FILES" | sort -u | grep -v '^$' | grep -v '^\.gsd/' || echo "")

    # .gsd/ 외부에 의미있는 변경이 없으면 종료
    if [ -z "$ALL_CHANGED" ]; then
        exit 0
    fi

    # 중복 방지: 마지막 엔트리의 파일 목록과 비교
    LAST_ENTRY_FILES=$(sed -n '/^### \[/,/^---$/{ /^- /p; }' "$CHANGELOG" | head -30 | sort)
    CURRENT_FILES=$(echo "$ALL_CHANGED" | sed 's/^/- /' | sort)
    if [ -n "$LAST_ENTRY_FILES" ] && [ "$LAST_ENTRY_FILES" = "$CURRENT_FILES" ]; then
        echo "[changelog] Skipped duplicate entry for session ${SESSION_ID:0:8}"
        exit 0
    fi

    # 통계 계산
    FILE_COUNT=$(echo "$ALL_CHANGED" | wc -l | tr -d ' ')
    DIFF_STAT=$(git diff --stat 2>/dev/null | tail -1 || echo "")

    # insertions/deletions 추출
    INSERTIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    DELETIONS=$(echo "$DIFF_STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

    # 파일 분류 (.gsd/ 내부 파일 제외)
    MODIFIED_FILES=$(git diff --name-only 2>/dev/null | grep -v '^\.gsd/' || echo "")
    NEW_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v '^\.gsd/' || echo "")
    DELETED_FILES=$(git diff --name-only --diff-filter=D 2>/dev/null | grep -v '^\.gsd/' || echo "")

    # 타임스탬프
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    # CHANGELOG 엔트리 생성
    ENTRY="### [$TIMESTAMP] Session: ${SESSION_ID:0:8}

**변경 파일**: ${FILE_COUNT}개
**추가/삭제**: +${INSERTIONS:-0} / -${DELETIONS:-0}
"

    # 수정된 파일 목록
    if [ -n "$MODIFIED_FILES" ]; then
        ENTRY="$ENTRY
#### 수정된 파일
$(echo "$MODIFIED_FILES" | sed 's/^/- /')
"
    fi

    # 새 파일 목록
    if [ -n "$NEW_FILES" ]; then
        ENTRY="$ENTRY
#### 새 파일
$(echo "$NEW_FILES" | sed 's/^/- /')
"
    fi

    # 삭제된 파일 목록
    if [ -n "$DELETED_FILES" ]; then
        ENTRY="$ENTRY
#### 삭제된 파일
$(echo "$DELETED_FILES" | sed 's/^/- /')
"
    fi

    ENTRY="$ENTRY
---
"

    # CHANGELOG에 추가 (마커 바로 아래에 삽입)
    MARKER="<!-- 아래에 세션별 변경사항이 자동으로 추가됩니다 -->"

    if grep -q "$MARKER" "$CHANGELOG"; then
        # 마커 아래에 삽입
        python3 << EOF
import re
with open("$CHANGELOG", "r") as f:
    content = f.read()
marker = "$MARKER"
entry = '''
$ENTRY'''
content = content.replace(marker, marker + entry)
with open("$CHANGELOG", "w") as f:
    f.write(content)
EOF
        echo "[changelog] Recorded changes for session ${SESSION_ID:0:8}"
    else
        # 마커가 없으면 파일 끝에 추가
        echo "" >> "$CHANGELOG"
        echo "$ENTRY" >> "$CHANGELOG"
        echo "[changelog] Appended changes for session ${SESSION_ID:0:8}"
    fi

    # compact-context.sh 호출 (아카이빙 트리거)
    if [ -f "$HOOK_DIR/compact-context.sh" ]; then
        bash "$HOOK_DIR/compact-context.sh" 2>/dev/null || true
    fi
}

# 메인 실행 및 에러 캡처
ERROR_OUTPUT=$(main 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$ERROR_OUTPUT" | grep -qiE '(error|permission denied|no such file)'; then
    HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$HOOK_DIR/_json_parse.sh"
    ERROR_MSG=$(echo "$ERROR_OUTPUT" | head -3 | tr '\n' ' ' | cut -c1-200)
    ERROR_JSON=$(json_dumps "$ERROR_MSG")
    echo "{\"status\":\"error\",\"message\":${ERROR_JSON}}"
else
    echo "$ERROR_OUTPUT"
fi

exit 0
