#!/usr/bin/env bash
# verify.sh — 저장소 검증 단일 진입점 (로컬 = CI). 모든 단계를 실행하고 실패를 모아 보고한다.
# 단계는 서로 독립이라(각자 임시 디렉터리, 저장소는 읽기만) 동시에 돌리고, 결과는 끝에서 선언 순서대로 보고한다.
# Usage: bash scripts/verify.sh   → exit 1 if any step fails
set -uo pipefail
cd "$(dirname "$0")/.."
export CLAUDE_PROJECT_DIR="$PWD"
RES=$(mktemp -d)
trap 'rm -rf "$RES"' EXIT
NAMES=()
FAILED=()

step() { # step <name> <cmd...> — 백그라운드 실행, 출력과 종료 코드는 $RES/<순번>
    local i=${#NAMES[@]}
    NAMES+=("$1")
    shift
    { "$@" >"$RES/$i" 2>&1; echo $? >"$RES/$i.rc"; } &
}
skip() { NAMES+=("$1") && echo skip >"$RES/$((${#NAMES[@]} - 1)).rc"; }

if command -v claude >/dev/null; then
    step "plugin validate: marketplace" claude plugin validate . --strict
    step "plugin validate: plugin" claude plugin validate .claude-plugin/plugin.json --strict
    step "plugin validate: router" claude plugin validate plugins/router/.claude-plugin/plugin.json --strict
else
    skip "plugin validate (claude CLI not on PATH)"
fi
step "skills frontmatter" python3 scripts/check-skills.py
step "skills frontmatter: router" python3 scripts/check-skills.py --claude-only plugins/router/skills
step "json syntax" bash -c "git ls-files -z '*.json' | xargs -0 -n1 python3 -m json.tool >/dev/null"
step "bash -n" bash -c "git ls-files -z '*.sh' | xargs -0 -n1 bash -n"
if command -v shellcheck >/dev/null; then
    step "shellcheck -S error" bash -c "git ls-files -z '*.sh' | xargs -0 shellcheck -S error"
else
    skip "shellcheck (not installed)"
fi
for t in tests/*.sh; do step "test: $t" bash "$t"; done
for t in tests/*.py; do step "test: $t" python3 "$t"; done
for t in plugins/router/tests/*.py; do step "test: $t" python3 "$t"; done
step "skill scenarios (dry-run)" bash scripts/run-skill-test.sh --all
step "markdown links" python3 skills/doc-lint/scripts/check-links.py
wait

for i in "${!NAMES[@]}"; do
    case $(cat "$RES/$i.rc" 2>/dev/null) in
    0) echo "PASS  ${NAMES[i]}" ;;
    skip) echo "SKIP  ${NAMES[i]}" ;;
    *)
        echo "FAIL  ${NAMES[i]}"
        sed 's/^/      /' "$RES/$i"
        FAILED+=("${NAMES[i]}")
        ;;
    esac
done

if [ ${#FAILED[@]} -eq 0 ]; then
    echo "VERIFY: PASS"
else
    echo "VERIFY: FAIL (${#FAILED[@]}): ${FAILED[*]}"
    exit 1
fi
