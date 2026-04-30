#!/usr/bin/env bash
# Pre-commit hook: bootstrap.sh 버전과 .bootstrap-version 파일 동기화 검증
# 둘 중 하나라도 스테이징에 포함되면 버전 일치 여부 확인

set -euo pipefail

HXSK_DIR=".hxsk"
VERSION_FILE="$HXSK_DIR/.bootstrap-version"
BOOTSTRAP_SH="$HXSK_DIR/scripts/bootstrap.sh"

# 스테이징된 파일 중 버전 관련 파일이 있는지 확인
STAGED=$(git diff --cached --name-only 2>/dev/null || true)

if echo "$STAGED" | grep -qE "(bootstrap\.sh|\.bootstrap-version)"; then
    VER_SH=$(grep '^BOOTSTRAP_VERSION=' "$BOOTSTRAP_SH" 2>/dev/null | head -1 | sed 's/.*="//' | sed 's/"//')
    VER_FILE=$(grep '^version:' "$VERSION_FILE" 2>/dev/null | sed 's/^version: *//' | tr -d '"[:space:]')

    if [[ -n "$VER_SH" && -n "$VER_FILE" && "$VER_SH" != "$VER_FILE" ]]; then
        echo "❌ 버전 불일치: bootstrap.sh=$VER_SH, .bootstrap-version=$VER_FILE"
        echo "   두 파일의 버전을 맞춘 뒤 다시 커밋하세요."
        exit 1
    fi
fi
