#!/usr/bin/env bash
# HITL 하네스 자동 감지
# stdout: claude-code | opencode | antigravity
# 감지 순서: 환경변수 → 하네스 시그니처 → 기본값

set -euo pipefail

# 1. 환경변수 명시 오버라이드
if [[ -n "${HXSK_HARNESS:-}" ]]; then
  echo "$HXSK_HARNESS"
  exit 0
fi

# 2. Claude Desktop / Claude Code 시그니처
if [[ -n "${CLAUDE_DESKTOP_APP:-}" ]] || [[ -n "${ANTHROPIC_API_KEY:-}" && -n "${CLAUDE_CODE:-}" ]]; then
  echo "claude-code"
  exit 0
fi

# 3. OpenCode 시그니처
if [[ -n "${OPENCODE_SESSION:-}" ]] || [[ -f "$(pwd)/.opencode" ]] || [[ -n "${OPENCODE:-}" ]]; then
  echo "opencode"
  exit 0
fi

# 4. Antigravity 시그니처
if [[ -n "${ANTIGRAVITY_SESSION:-}" ]] || [[ -n "${ANTIGRAVITY:-}" ]]; then
  echo "antigravity"
  exit 0
fi

# 5. 기본값: claude-code
echo "claude-code"
