#!/usr/bin/env bash
# verify.sh — 저장소 검증 단일 진입점 (로컬 = CI). 모든 단계를 실행하고 실패를 모아 보고한다.
# Usage: bash scripts/verify.sh   → exit 1 if any step fails
set -uo pipefail
cd "$(dirname "$0")/.."
export CLAUDE_PROJECT_DIR="$PWD"
FAILED=()

step() { # step <name> <cmd...> — 통과 시 한 줄, 실패 시 출력 전체
    local name=$1 out
    shift
    if out=$("$@" 2>&1); then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        sed 's/^/      /' <<<"$out"
        FAILED+=("$name")
    fi
}

if command -v claude >/dev/null; then
    step "plugin validate: marketplace" claude plugin validate . --strict
    step "plugin validate: plugin" claude plugin validate .claude-plugin/plugin.json --strict
    step "plugin validate: router" claude plugin validate plugins/router/.claude-plugin/plugin.json --strict
else
    echo "SKIP  plugin validate (claude CLI not on PATH)"
fi
step "skills frontmatter" python3 scripts/check-skills.py
step "skills frontmatter: router" python3 scripts/check-skills.py plugins/router/skills
step "json syntax" bash -c "git ls-files -z '*.json' | xargs -0 -n1 python3 -m json.tool >/dev/null"
step "bash -n" bash -c "git ls-files -z '*.sh' | xargs -0 -n1 bash -n"
if command -v shellcheck >/dev/null; then
    step "shellcheck -S error" bash -c "git ls-files -z '*.sh' | xargs -0 shellcheck -S error"
else
    echo "SKIP  shellcheck (not installed)"
fi
for t in tests/*.sh; do step "test: $t" bash "$t"; done
for t in plugins/router/tests/*.py; do step "test: $t" python3 "$t"; done
step "skill scenarios (dry-run)" bash scripts/run-skill-test.sh --all
step "markdown links" python3 skills/doc-lint/scripts/check-links.py

if [ ${#FAILED[@]} -eq 0 ]; then
    echo "VERIFY: PASS"
else
    echo "VERIFY: FAIL (${#FAILED[@]}): ${FAILED[*]}"
    exit 1
fi
