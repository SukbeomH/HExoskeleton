#!/usr/bin/env bash
# skills/doc-lint/scripts/check-links.py 회귀 테스트: 깨진 상대 링크만 잡고 URL/앵커/코드블록은 무시
# Usage: bash tests/check-links.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/sub" && touch "$TMP/sub/ok.md" "$TMP/a b.md"
cat >"$TMP/doc.md" <<'EOF'
[ok](sub/ok.md) [anchor ok](sub/ok.md#x) [only anchor](#top) [web](https://example.com/x.md)
[mail](mailto:a@b.c) [tpl](${CLAUDE_PLUGIN_ROOT}/x.md) [space](a%20b.md) [titled](sub/ok.md "t")
`[inline code](nope-inline.md)`
```
[fenced](nope-fenced.md)
```
[broken](missing.md) ![img](sub/missing.png)
EOF

set +e
out=$(cd "$TMP" && python3 "$ROOT/skills/doc-lint/scripts/check-links.py" doc.md)
code=$?
set -e
fail() { echo "FAIL: $1"; echo "$out"; exit 1; }
[ "$code" = 1 ] || fail "exit $code, want 1"
grep -qx 'doc.md:7: missing.md' <<<"$out" || fail "missing.md not reported"
grep -qx 'doc.md:7: sub/missing.png' <<<"$out" || fail "image link not reported"
[ "$(grep -c '^doc.md:' <<<"$out")" = 2 ] || fail "false positives"

(cd "$TMP" && python3 "$ROOT/skills/doc-lint/scripts/check-links.py" sub/ok.md >/dev/null) || fail "clean file should pass"
echo "PASS: check-links"
