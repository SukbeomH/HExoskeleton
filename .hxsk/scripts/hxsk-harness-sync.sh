#!/usr/bin/env bash
# 설치된 어댑터 파일과 .hxsk/adapters/ 원본 비교
set -euo pipefail

ADAPTER_DIR=".hxsk/adapters"
MODE="${1:---check}"

declare -A HARNESS_MAP=(
    ["cursor"]="$ADAPTER_DIR/cursor-hooks.json:.cursor/hooks.json"
    ["copilot"]="$ADAPTER_DIR/copilot-hooks.json:.copilot/hooks.json"
    ["windsurf"]="$ADAPTER_DIR/windsurf-hooks.json:.windsurf/hooks.json"
    ["codex"]="$ADAPTER_DIR/codex-hooks.json:.codex/hooks.json"
)

DRIFT=0
for harness in "${!HARNESS_MAP[@]}"; do
    IFS=: read -r src dst <<< "${HARNESS_MAP[$harness]}"
    [[ ! -f "$dst" ]] && continue
    if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        echo "[DRIFT] $harness: $dst 가 $src 와 다름"
        DRIFT=1
        if [[ "$MODE" == "--sync" ]]; then
            cp "$src" "$dst"
            echo "  → 동기화 완료"
        fi
    else
        echo "[OK]    $harness: 최신 상태"
    fi
done

if [[ "$DRIFT" -eq 0 ]]; then
    echo "모든 어댑터 최신 상태"
elif [[ "$MODE" == "--check" ]]; then
    echo "드리프트 발견 — '--sync' 옵션으로 동기화하세요"
fi
