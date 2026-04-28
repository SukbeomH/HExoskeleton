#!/usr/bin/env bash
# Antigravity HITL 어댑터
# opencode.sh와 동일 패턴 (stdout + stdin 대기)
# 하네스별 특수 동작은 HXSK_ANTIGRAVITY_HITL_CMD 환경변수로 오버라이드 가능

set -euo pipefail

TERM="${HXSK_HITL_TERM:-}"
QUESTION="${HXSK_HITL_QUESTION:-}"
OPTIONS="${HXSK_HITL_OPTIONS:-}"
TIMEOUT="${HXSK_HITL_TIMEOUT:-60}"

# 커스텀 HITL 커맨드 오버라이드
if [[ -n "${HXSK_ANTIGRAVITY_HITL_CMD:-}" ]]; then
  HXSK_HITL_TERM="$TERM" HXSK_HITL_QUESTION="$QUESTION" \
  HXSK_HITL_OPTIONS="$OPTIONS" exec "$HXSK_ANTIGRAVITY_HITL_CMD"
fi

if [[ -z "$QUESTION" ]]; then
  echo "[HITL:antigravity] QUESTION 미설정" >&2
  exit 2
fi

echo ""
echo "❓ HITL: ${TERM:+[$TERM] }${QUESTION}"
[[ -n "$OPTIONS" ]] && echo "   옵션: $(echo "$OPTIONS" | tr '|' ' / ')"
printf "선택 > "

if read -r -t "$TIMEOUT" answer; then
  if [[ -z "$answer" ]] || [[ "$answer" == "Skip" ]] || [[ "$answer" == "skip" ]]; then
    exit 1
  fi
  echo "$answer"
  exit 0
else
  echo "[HITL:antigravity] timeout (${TIMEOUT}s)" >&2
  exit 2
fi
