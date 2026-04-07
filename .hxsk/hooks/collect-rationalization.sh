#!/usr/bin/env bash
# Hook: Stop — 합리화 패턴 수집
# 에이전트 출력에서 Iron Law 위반 시그널을 감지하여 기록
# 수집된 패턴은 합리화 테이블 갱신 시 참조

set -o pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
RATIONALIZATION_LOG="$HXSK_DIR/.rationalization-patterns.log"

# stdin에서 에이전트 출력 읽기
AGENT_OUTPUT=""
if [ ! -t 0 ]; then
    AGENT_OUTPUT=$(cat 2>/dev/null || true)
fi

[ -z "$AGENT_OUTPUT" ] && exit 0

# 합리화 시그널 패턴 (에이전트가 규칙을 우회할 때 사용하는 표현)
RATIONALIZATION_PATTERNS=(
    "이미 알고 있"
    "단순한 변경"
    "방금 읽었"
    "빠르게 하기 위해"
    "시간 절약"
    "확신합니다"
    "잘 돌아갈"
    "통과할 것"
    "명확한 변경"
    "should work"
    "I'm confident"
    "simple change"
    "already know"
    "just read"
    "to save time"
)

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
FOUND=0

for pattern in "${RATIONALIZATION_PATTERNS[@]}"; do
    if echo "$AGENT_OUTPUT" | grep -qi "$pattern"; then
        echo "[$TIMESTAMP] DETECTED: \"$pattern\"" >> "$RATIONALIZATION_LOG" 2>/dev/null || true
        FOUND=1
    fi
done

# Iron Law 위반 시그널: read-before-edit 훅 경고가 있었는지 확인
if [ -f "$HXSK_DIR/.read-history.log" ]; then
    READ_COUNT=$(wc -l < "$HXSK_DIR/.read-history.log" 2>/dev/null | tr -d ' ')
    if [ "$READ_COUNT" -eq 0 ] 2>/dev/null; then
        # Read 이력 0건인데 Edit이 있었다면 위반
        EDIT_COUNT=$(grep -c "Edit" "$HXSK_DIR/.track-modifications.log" 2>/dev/null || echo "0")
        if [ "$EDIT_COUNT" -gt 0 ] 2>/dev/null; then
            echo "[$TIMESTAMP] VIOLATION: Edit without Read (0 reads, $EDIT_COUNT edits)" >> "$RATIONALIZATION_LOG" 2>/dev/null || true
            FOUND=1
        fi
    fi
fi

exit 0
