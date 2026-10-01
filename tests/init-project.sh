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

# .hxsk/.gitignore: 훅 런타임 파일은 무시, 프로젝트 상태/메모리는 추적
git -C "$TMP" init -q
for f in .track-modifications.log .context-save-202601.log .modified-this-session.123 .session-active \
    STATE.md.pre-compact.bak runtime/session-snapshots/x/CURRENT.md .prune-lock/x CURRENT.md; do
    git -C "$TMP" check-ignore -q ".hxsk/$f" || fail ".hxsk/$f should be ignored"
done
for f in SPEC.md STATE.md VERIFICATION.md PATTERNS.md memories/general/x.md .gitignore; do
    ! git -C "$TMP" check-ignore -q ".hxsk/$f" || fail ".hxsk/$f should be trackable"
done

# HXSK 저장소 자체에 init 해도 기여자 가이드 AGENTS.md 에 블록을 붙이지 않는다
SELF="$TMP/self"
mkdir -p "$SELF" && cp -R "$ROOT/scripts" "$ROOT/templates" "$SELF/" && echo "# guide" >"$SELF/AGENTS.md"
bash "$SELF/scripts/init-project.sh" "$SELF" >/dev/null
[ "$(cat "$SELF/AGENTS.md")" = "# guide" ] || fail "init on the HXSK repo itself modified AGENTS.md"

echo "PASS: init-project idempotent"
