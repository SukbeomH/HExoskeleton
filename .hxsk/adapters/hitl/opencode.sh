#!/usr/bin/env bash
# OpenCode HITL 어댑터
# stdout 프롬프트 출력 + stdin 대기
# exit 0: 응답 수신, exit 1: skip/empty, exit 2: timeout

set -euo pipefail

TERM="${HXSK_HITL_TERM:-}"
QUESTION="${HXSK_HITL_QUESTION:-}"
OPTIONS="${HXSK_HITL_OPTIONS:-}"
TIMEOUT="${HXSK_HITL_TIMEOUT:-60}"

if [[ -z "$QUESTION" ]]; then
  echo "[HITL:opencode] QUESTION 미설정" >&2
  exit 2
fi

echo ""
echo "❓ HITL: ${TERM:+[$TERM] }${QUESTION}"
[[ -n "$OPTIONS" ]] && echo "   옵션: $(echo "$OPTIONS" | tr '|' ' / ')"
printf "선택 > "

# timeout으로 대기
if read -r -t "$TIMEOUT" answer; then
  if [[ -z "$answer" ]] || [[ "$answer" == "Skip" ]] || [[ "$answer" == "skip" ]]; then
    exit 1
  fi
  echo "$answer"
  exit 0
else
  echo "[HITL:opencode] timeout (${TIMEOUT}s)" >&2
  exit 2
fi
