#!/usr/bin/env bash
# local-verify.sh — 로컬 우선 검증 번들
# Usage: bash .hxsk/scripts/local-verify.sh
#
# GitHub Actions와 로컬 pre-push hook이 같은 검증 진입점을 사용한다.
# 네트워크 의존 검사는 기본 비활성화하고, 구조/문서/스킬 검증을 로컬에서 먼저 실패시킨다.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
export HXSK_SKIP_GITHUB="${HXSK_SKIP_GITHUB:-1}"

cd "$PROJECT_DIR"

run_step() {
  local label="$1"
  shift
  echo ""
  echo "================================================================"
  echo " LOCAL VERIFY: $label"
  echo "================================================================"
  "$@"
}

run_step "doc-lint" bash .hxsk/scripts/doc-lint.sh
run_step "consistency" bash .hxsk/hooks/check-consistency.sh

if [[ -d ".hxsk/tests/scenarios" ]]; then
  run_step "skill test dry-run" bash .hxsk/scripts/run-skill-test.sh --all
else
  echo "[SKIP] .hxsk/tests/scenarios not found"
fi

run_step "pre-pr" bash .hxsk/hooks/pre-pr-check.sh

echo ""
echo "================================================================"
echo " LOCAL VERIFY: PASS"
echo "================================================================"
