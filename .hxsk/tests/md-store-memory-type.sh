#!/usr/bin/env bash
# md-store-memory.sh 타입 검증 회귀 테스트: 잘못된 타입은 거부(디렉토리 미생성), 유효 타입은 저장
# Usage: bash .hxsk/tests/md-store-memory-type.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.hxsk/memories/_schema"
cp "$ROOT/.hxsk/memories/_schema/type-relations.yaml" "$TMP/.hxsk/memories/_schema/"

store() {
    CLAUDE_PROJECT_DIR="$TMP" HXSK_CONTRADICTION_CHECK=0 \
        bash "$ROOT/.hxsk/hooks/md-store-memory.sh" "t $1" "body" "test" "$1"
}

for bad in "ADR-006/007 공유 인프라 구축." "ADR-006/007" "../escape" "not-a-type" "lessons-learned/Z-nope"; do
    if store "$bad" >/dev/null 2>&1; then
        echo "FAIL: accepted invalid type '$bad'"
        exit 1
    fi
done
if [ -n "$(find "$TMP/.hxsk/memories" -mindepth 1 -maxdepth 1 ! -name _schema)" ]; then
    echo "FAIL: directory created for an invalid type"
    exit 1
fi

for good in general session-summary lessons-learned/B-test-quality; do
    out=$(store "$good" 2>/dev/null)
    if [ ! -f "$out" ]; then
        echo "FAIL: valid type '$good' not stored"
        exit 1
    fi
done

echo "PASS: md-store-memory type validation"
