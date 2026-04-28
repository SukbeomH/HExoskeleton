#!/usr/bin/env bash
# Claude Code HITL 어댑터
# bash 훅에서 동기적 사용자 응답 불가 → pending 파일 방식
# Claude가 다음 턴에 .hxsk/.hitl-pending.json 읽어 AskUserQuestion 처리
# exit 0: pending 기록 성공 (Claude가 다음 턴 처리)
# exit 1: skip
# exit 2: 오류

set -euo pipefail

TERM="${HXSK_HITL_TERM:-}"
QUESTION="${HXSK_HITL_QUESTION:-}"
OPTIONS="${HXSK_HITL_OPTIONS:-}"
PENDING_FILE="${HXSK_PROJECT_DIR:-.}/.hxsk/.hitl-pending.json"

# JSON-safe 이스케이핑 (백슬래시 → \\, 쌍따옴표 → \")
json_safe() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TERM_SAFE=$(json_safe "$TERM")
QUESTION_SAFE=$(json_safe "$QUESTION")
OPTIONS_SAFE=$(json_safe "$OPTIONS")

if [[ -z "$QUESTION" ]]; then
  echo "[HITL:claude-code] QUESTION 미설정" >&2
  exit 2
fi

# pending 파일에 질문 기록
cat > "$PENDING_FILE" <<JSON
{
  "harness": "claude-code",
  "term": "${TERM_SAFE}",
  "question": "${QUESTION_SAFE}",
  "options": "${OPTIONS_SAFE}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "pending"
}
JSON

echo "pending"
exit 0
