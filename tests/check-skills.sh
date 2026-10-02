#!/usr/bin/env bash
# scripts/check-skills.py 회귀 테스트: disable-model-invocation은 --claude-only에서만, 다른 비스펙 키는 항상 거부
# Usage: bash tests/check-skills.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/s/x" "$TMP/m/y"
printf -- '---\nname: x\ndescription: "d"\ndisable-model-invocation: true\n---\n' >"$TMP/s/x/SKILL.md"
printf -- '---\nname: y\ndescription: "d"\nmodel: haiku\n---\n' >"$TMP/m/y/SKILL.md"
fail() { echo "FAIL: $1"; exit 1; }
chk() { python3 "$ROOT/scripts/check-skills.py" "$@" >/dev/null; }

chk "$TMP/s" && fail "disable-model-invocation passed without --claude-only"
chk --claude-only "$TMP/s" || fail "--claude-only should admit disable-model-invocation"
chk --claude-only "$TMP/m" && fail "--claude-only must not admit other keys (model)"
chk --claude-only "$ROOT/plugins/router/skills" || fail "router skills"
chk "$ROOT/plugins/router/skills" && fail "router skills need --claude-only (front is user-typed only)"
echo "PASS: check-skills"
