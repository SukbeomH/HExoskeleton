#!/usr/bin/env bash
# init-project.sh 멱등성 테스트: 두 번 실행해도 트리가 같고, 기존 파일은 보존된다.
# Usage: bash tests/init-project.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.hxsk"
echo "# my spec" >"$TMP/.hxsk/SPEC.md"
echo "# Agents" >"$TMP/AGENTS.md"

snapshot() { (cd "$TMP" && find . -type f | sort | xargs shasum); }
fail() { echo "FAIL: $1"; exit 1; }

bash "$ROOT/scripts/init-project.sh" --skills "$TMP" >/dev/null
first=$(snapshot)
out=$(bash "$ROOT/scripts/init-project.sh" --skills "$TMP")
[ "$first" = "$(snapshot)" ] || fail "second run changed the tree"
! grep -q '^\[NEW\]' <<<"$out" || fail "second run created files: $out"

[ "$(cat "$TMP/.hxsk/SPEC.md")" = "# my spec" ] || fail "existing SPEC.md overwritten"
[ "$(grep -c '<!-- hxsk -->' "$TMP/AGENTS.md")" = 1 ] || fail "AGENTS.md block missing or duplicated"
head -1 "$TMP/AGENTS.md" | grep -qx '# Agents' || fail "AGENTS.md original content lost"
for f in STATE CURRENT SESSION_HANDOFF VERIFICATION PATTERNS; do
    [ -s "$TMP/.hxsk/$f.md" ] || fail ".hxsk/$f.md not created"
done
[ -d "$TMP/.hxsk/memories" ] || fail ".hxsk/memories not created"
[ -f "$TMP/.agents/skills/memory-protocol/scripts/md-store-memory.sh" ] || fail "--skills did not copy skills"

echo "PASS: init-project idempotent"
