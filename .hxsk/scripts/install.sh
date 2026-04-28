#!/usr/bin/env bash
# HXSK Harness Installer — 순수 bash, 외부 의존성 없음
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_DIR="$SCRIPT_DIR/../adapters"
HARNESS=""
FORCE=0

usage() {
  echo "Usage: $0 --harness <name> [--force]"
  echo "Harnesses: claude-code cursor copilot gemini windsurf opencode codex git-hook"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "[WARN] 알 수 없는 옵션: $1" >&2; shift ;;
  esac
done

[[ -z "$HARNESS" ]] && { usage; exit 1; }

safe_copy() {
  local src="$1" dst="$2"
  if [[ -f "$dst" && "$FORCE" -eq 0 ]]; then
    echo "[WARN] $dst 이미 존재 — 덮어쓰려면 --force 사용"
    return 0
  fi
  cp "$src" "$dst"
}

install_harness() {
  local harness="$1"
  case "$harness" in
    claude-code)
      bash "$SCRIPT_DIR/install-hooks.sh" --merge
      echo "[OK] Claude Code: settings.json 훅 등록 완료" ;;
    cursor)
      mkdir -p .cursor
      safe_copy "$ADAPTER_DIR/cursor-hooks.json" ".cursor/hooks.json"
      echo "[OK] Cursor: .cursor/hooks.json 설치 완료" ;;
    copilot)
      mkdir -p .copilot
      safe_copy "$ADAPTER_DIR/copilot-hooks.json" ".copilot/hooks.json"
      echo "[OK] GitHub Copilot CLI: .copilot/hooks.json 설치 완료" ;;
    gemini)
      echo "[INFO] Gemini CLI: ~/.gemini/settings.json 또는 .gemini/settings.json 에 병합 필요"
      echo "       어댑터 위치: $ADAPTER_DIR/gemini-settings.json"
      echo "       수동 병합: cat $ADAPTER_DIR/gemini-settings.json" ;;
    windsurf)
      mkdir -p .windsurf
      safe_copy "$ADAPTER_DIR/windsurf-hooks.json" ".windsurf/hooks.json"
      echo "[OK] Windsurf: .windsurf/hooks.json 설치 완료" ;;
    opencode)
      echo "[INFO] OpenCode: JS 래퍼 필요 — $ADAPTER_DIR/opencode-plugin.ts 참조" ;;
    codex)
      mkdir -p .codex
      safe_copy "$ADAPTER_DIR/codex-hooks.json" ".codex/hooks.json"
      git config core.hooksPath .hxsk/githooks
      echo "[OK] OpenAI Codex CLI: .codex/hooks.json 설치 완료"
      echo "[OK] git 훅 폴백: core.hooksPath .hxsk/githooks 설정 완료"
      echo "[INFO] Codex hooks require codex_hooks=true in Codex config." ;;
    git-hook)
      git config core.hooksPath .hxsk/githooks
      echo "[OK] git 훅 폴백: core.hooksPath .hxsk/githooks 설정 완료" ;;
    *) echo "[FAIL] 알 수 없는 하네스: $harness"; usage; exit 1 ;;
  esac
}

install_harness "$HARNESS"
