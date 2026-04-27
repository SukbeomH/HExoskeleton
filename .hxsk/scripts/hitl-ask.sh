#!/usr/bin/env bash
# HITL 어댑터 라우터
# Usage: bash .hxsk/scripts/hitl-ask.sh "term=X" "question=Y?" "options=A|B|Skip"
# stdout: 사용자 선택값 (또는 "pending")
# exit:   0=응답, 1=skip, 2=timeout/오류
#
# 환경변수 오버라이드:
#   HXSK_HARNESS          - 하네스 강제 지정 (claude-code|opencode|antigravity)
#   HXSK_HITL_TIMEOUT     - stdin 대기 타임아웃 (초, 기본 60)
#   HXSK_PROJECT_DIR      - 프로젝트 루트 (pending 파일 위치, 기본 현재 디렉토리)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_DIR="${SCRIPT_DIR}/../adapters/hitl"

# 인자 파싱 (key=value 형식)
TERM=""
QUESTION=""
OPTIONS=""

for arg in "$@"; do
  case "$arg" in
    term=*)     TERM="${arg#term=}" ;;
    question=*) QUESTION="${arg#question=}" ;;
    options=*)  OPTIONS="${arg#options=}" ;;
    --help|-h)
      echo "Usage: hitl-ask.sh \"term=X\" \"question=Y?\" \"options=A|B|Skip\""
      echo "exit: 0=answered, 1=skip, 2=timeout/error"
      exit 0
      ;;
  esac
done

if [[ -z "$QUESTION" ]]; then
  echo "[hitl-ask] 'question=' 인자 필수" >&2
  exit 2
fi

# 하네스 감지
HARNESS="$(bash "${ADAPTER_DIR}/_detect.sh")"

# 어댑터 실행 (환경변수로 전달)
export HXSK_HITL_TERM="$TERM"
export HXSK_HITL_QUESTION="$QUESTION"
export HXSK_HITL_OPTIONS="$OPTIONS"

ADAPTER="${ADAPTER_DIR}/${HARNESS}.sh"
if [[ ! -f "$ADAPTER" ]]; then
  echo "[hitl-ask] 어댑터 미발견: $ADAPTER (fallback: claude-code)" >&2
  ADAPTER="${ADAPTER_DIR}/claude-code.sh"
fi

bash "$ADAPTER"
