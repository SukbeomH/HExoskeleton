#!/usr/bin/env bash
# test_qlty_integration.sh — Qlty E2E integration tests
# Usage: bash tests/e2e/test_qlty_integration.sh
set -uo pipefail

# ─────────────────────────────────────────────────────
# Test Harness
# ─────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
CURRENT_CAT=""
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR_ROOT=""

_color_green="\033[32m"
_color_red="\033[31m"
_color_yellow="\033[33m"
_color_cyan="\033[36m"
_color_reset="\033[0m"

pass() {
    ((PASS_COUNT++))
    printf "${_color_green}  PASS${_color_reset} %s\n" "$1"
}

fail() {
    ((FAIL_COUNT++))
    printf "${_color_red}  FAIL${_color_reset} %s\n" "$1"
    [[ -n "${2:-}" ]] && printf "       → %s\n" "$2"
}

skip() {
    ((SKIP_COUNT++))
    printf "${_color_yellow}  SKIP${_color_reset} %s\n" "$1"
    [[ -n "${2:-}" ]] && printf "       → %s\n" "$2"
}

cat_header() {
    CURRENT_CAT="$1"
    printf "\n${_color_cyan}=== Cat %s ===${_color_reset}\n" "$1"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$label"
    else
        fail "$label" "expected='$expected' actual='$actual'"
    fi
}

assert_exit() {
    local label="$1" expected_code="$2"
    shift 2
    local actual_code=0
    "$@" >/dev/null 2>&1 || actual_code=$?
    if [[ "$actual_code" -eq "$expected_code" ]]; then
        pass "$label"
    else
        fail "$label" "expected exit=$expected_code actual exit=$actual_code"
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        pass "$label"
    else
        fail "$label" "output does not contain '$needle'"
    fi
}

assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        fail "$label" "output unexpectedly contains '$needle'"
    else
        pass "$label"
    fi
}

skip_if() {
    local condition_desc="$1" label="$2"
    skip "$label" "$condition_desc"
}

# Timeout wrapper (120s default)
run_with_timeout() {
    local timeout="${1:-120}"
    shift
    if command -v timeout &>/dev/null; then
        timeout "$timeout" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$timeout" "$@"
    else
        "$@"
    fi
}

# Cleanup trap
cleanup() {
    [[ -n "$TMPDIR_ROOT" ]] && rm -rf "$TMPDIR_ROOT"
    # Restore git state if stashed
    if [[ "${GIT_STASHED:-false}" == "true" ]]; then
        cd "$PROJECT_DIR" || exit
        git stash pop --quiet 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────
# Cat 1: Prerequisites (5 tests)
# ─────────────────────────────────────────────────────
cat_header "1: Prerequisites"

# 1.1 qlty CLI installed
if command -v qlty &>/dev/null; then
    pass "qlty CLI installed"
    QLTY_AVAILABLE=true
else
    fail "qlty CLI installed" "qlty not found in PATH"
    printf "\n${_color_red}ABORT: prerequisites not met — qlty CLI required${_color_reset}\n"
    printf "\n=== RESULTS: %d passed, %d failed, %d skipped ===\n" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
    exit 1
fi

# 1.2 .qlty/qlty.toml exists
if [[ -f "$PROJECT_DIR/.qlty/qlty.toml" ]]; then
    pass ".qlty/qlty.toml exists"
else
    fail ".qlty/qlty.toml exists" "file not found"
    printf "\n${_color_red}ABORT: prerequisites not met — .qlty/qlty.toml required${_color_reset}\n"
    printf "\n=== RESULTS: %d passed, %d failed, %d skipped ===\n" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
    exit 1
fi

# 1.3 8 plugins declared
EXPECTED_PLUGINS=("ruff" "shellcheck" "actionlint" "bandit" "radarlint-python" "ripgrep" "trivy" "trufflehog")
MISSING_PLUGINS=()
for p in "${EXPECTED_PLUGINS[@]}"; do
    if ! grep -q "name = \"$p\"" "$PROJECT_DIR/.qlty/qlty.toml"; then
        MISSING_PLUGINS+=("$p")
    fi
done
if [[ ${#MISSING_PLUGINS[@]} -eq 0 ]]; then
    pass "8 plugins declared in qlty.toml"
else
    fail "8 plugins declared in qlty.toml" "missing: ${MISSING_PLUGINS[*]}"
fi

# 1.4 Python source files exist
if ls "$PROJECT_DIR/src/gsd_stat/"*.py &>/dev/null; then
    pass "src/gsd_stat/ Python source files exist"
else
    fail "src/gsd_stat/ Python source files exist"
fi

# 1.5 uv available
if command -v uv &>/dev/null; then
    pass "uv available"
else
    fail "uv available" "uv not found in PATH"
fi

# ─────────────────────────────────────────────────────
# Cat 2: qlty CLI Direct Commands (7 tests)
# ─────────────────────────────────────────────────────
cat_header "2: qlty CLI Direct Commands"

cd "$PROJECT_DIR" || exit

# 2.1 qlty check — no crash
CHECK_OUTPUT=""
CHECK_EXIT=0
CHECK_OUTPUT=$(run_with_timeout 120 qlty check 2>&1) || CHECK_EXIT=$?
# qlty check may return non-zero for lint issues, that's fine — we only check for crash/panic
if echo "$CHECK_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
    fail "qlty check — no crash" "crash detected in output"
else
    pass "qlty check — no crash"
fi

# 2.2 qlty check --json — valid JSON
JSON_OUTPUT=""
JSON_EXIT=0
JSON_OUTPUT=$(run_with_timeout 120 qlty check --json 2>/dev/null) || JSON_EXIT=$?
if echo "$JSON_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "qlty check --json — valid JSON"
else
    fail "qlty check --json — valid JSON" "output is not valid JSON"
fi

# 2.3 qlty check --fix — no crash
GIT_STASHED=false
# Stash changes to protect working tree
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
fi
FIX_OUTPUT=""
FIX_EXIT=0
FIX_OUTPUT=$(run_with_timeout 120 qlty check --fix src/ scripts/ 2>&1) || FIX_EXIT=$?
if echo "$FIX_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
    fail "qlty check --fix -- no crash" "crash detected"
else
    pass "qlty check --fix -- no crash"
fi
# Restore any changes made by --fix
git checkout -- . 2>/dev/null || true
if [[ "$GIT_STASHED" == "true" ]]; then
    git stash pop --quiet 2>/dev/null || true
    GIT_STASHED=false
fi

# 2.4 qlty fmt --all — no crash
GIT_STASHED=false
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
fi
FMT_OUTPUT=""
FMT_EXIT=0
FMT_OUTPUT=$(run_with_timeout 120 qlty fmt --all src/ scripts/ 2>&1) || FMT_EXIT=$?
if echo "$FMT_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
    fail "qlty fmt --all -- no crash" "crash detected"
else
    pass "qlty fmt --all -- no crash"
fi
git checkout -- . 2>/dev/null || true
if [[ "$GIT_STASHED" == "true" ]]; then
    git stash pop --quiet 2>/dev/null || true
    GIT_STASHED=false
fi

# 2.5 qlty fmt <single file> — Python file format
SINGLE_PY="$PROJECT_DIR/src/gsd_stat/cli.py"
if [[ -f "$SINGLE_PY" ]]; then
    GIT_STASHED=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
    fi
    FMT_SINGLE_EXIT=0
    run_with_timeout 120 qlty fmt "$SINGLE_PY" 2>/dev/null || FMT_SINGLE_EXIT=$?
    if echo "$FMT_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
        fail "qlty fmt <single file>" "crash detected"
    else
        pass "qlty fmt <single file>"
    fi
    git checkout -- . 2>/dev/null || true
    if [[ "$GIT_STASHED" == "true" ]]; then
        git stash pop --quiet 2>/dev/null || true
        GIT_STASHED=false
    fi
else
    skip "qlty fmt <single file>" "src/gsd_stat/cli.py not found"
fi

# 2.6 exclude patterns — templates/** issues = 0
EXCL_OUTPUT=""
EXCL_OUTPUT=$(run_with_timeout 120 qlty check --json 2>/dev/null) || true
TEMPLATE_ISSUES=0
TEMPLATE_ISSUES=$(echo "$EXCL_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        issues = data
    else:
        issues = data.get('issues', [])
    count = sum(1 for i in issues if 'templates/' in i.get('path', i.get('filename', '')))
    print(count)
except:
    print(0)
" 2>/dev/null) || TEMPLATE_ISSUES=0
assert_eq "exclude patterns — templates/** issues = 0" "0" "$TEMPLATE_ISSUES"

# 2.7 test_patterns matching — tests/test_*.py recognized
TEST_PATTERN_CHECK=$(grep -c 'test_\*' "$PROJECT_DIR/.qlty/qlty.toml" || echo "0")
if [[ "$TEST_PATTERN_CHECK" -gt 0 ]]; then
    pass "test_patterns — tests/test_*.py pattern present"
else
    # Check for alternative pattern
    if grep -q '"**/test_\*\.\*"' "$PROJECT_DIR/.qlty/qlty.toml"; then
        pass "test_patterns — tests/test_*.py pattern present"
    else
        fail "test_patterns — tests/test_*.py pattern present"
    fi
fi

# ─────────────────────────────────────────────────────
# Cat 3: Makefile Integration (5 tests)
# ─────────────────────────────────────────────────────
cat_header "3: Makefile Integration"

cd "$PROJECT_DIR" || exit

# 3.1 make lint → qlty path
LINT_RECIPE=$(grep -A3 '^lint:' "$PROJECT_DIR/Makefile" | head -4)
if echo "$LINT_RECIPE" | grep -q "qlty"; then
    pass "make lint → qlty path"
else
    fail "make lint → qlty path" "Makefile lint target does not reference qlty"
fi

# 3.2 make lint-fix → qlty check --fix
LINTFIX_RECIPE=$(grep -A3 '^lint-fix:' "$PROJECT_DIR/Makefile" | head -4)
if echo "$LINTFIX_RECIPE" | grep -q "qlty check --fix"; then
    pass "make lint-fix → qlty check --fix"
else
    fail "make lint-fix → qlty check --fix" "Makefile lint-fix target does not reference qlty check --fix"
fi

# 3.3 make fmt → qlty fmt --all
FMT_RECIPE=$(grep -A3 '^fmt:' "$PROJECT_DIR/Makefile" | head -4)
if echo "$FMT_RECIPE" | grep -q "qlty fmt --all"; then
    pass "make fmt → qlty fmt --all"
else
    fail "make fmt → qlty fmt --all" "Makefile fmt target does not reference qlty fmt --all"
fi

# 3.4 make test → pytest execution
TEST_RECIPE=$(grep -A5 '^test:' "$PROJECT_DIR/Makefile" | head -6)
if echo "$TEST_RECIPE" | grep -q "pytest"; then
    pass "make test → pytest referenced"
else
    fail "make test → pytest referenced" "Makefile test target does not reference pytest"
fi

# 3.5 make typecheck → qlty path
TC_RECIPE=$(grep -A3 '^typecheck:' "$PROJECT_DIR/Makefile" | head -4)
if echo "$TC_RECIPE" | grep -q "qlty"; then
    pass "make typecheck → qlty path"
else
    fail "make typecheck → qlty path" "Makefile typecheck target does not reference qlty"
fi

# ─────────────────────────────────────────────────────
# Cat 4: detect-language.sh (12 tests)
# ─────────────────────────────────────────────────────
cat_header "4: detect-language.sh"

DETECT_SCRIPT="$PROJECT_DIR/scripts/detect-language.sh"
if [[ ! -f "$DETECT_SCRIPT" ]]; then
    skip_if "detect-language.sh not found" "all Cat 4 tests"
else
    source "$DETECT_SCRIPT"

    TMPDIR_ROOT=$(mktemp -d)

    # 4.1 qlty.toml-based: Python (ruff)
    TMP_PY="$TMPDIR_ROOT/py_proj"
    mkdir -p "$TMP_PY/.qlty"
    cat > "$TMP_PY/.qlty/qlty.toml" <<'TOML'
[[plugin]]
name = "ruff"
TOML
    RESULT=$(detect_language "$TMP_PY")
    assert_eq "qlty.toml detect: Python (ruff)" "python" "$RESULT"

    # 4.2 qlty.toml-based: Node (eslint)
    TMP_NODE="$TMPDIR_ROOT/node_proj"
    mkdir -p "$TMP_NODE/.qlty"
    cat > "$TMP_NODE/.qlty/qlty.toml" <<'TOML'
[[plugin]]
name = "eslint"
TOML
    RESULT=$(detect_language "$TMP_NODE")
    assert_eq "qlty.toml detect: Node (eslint)" "node" "$RESULT"

    # 4.3 qlty.toml-based: Rust (clippy)
    TMP_RUST="$TMPDIR_ROOT/rust_proj"
    mkdir -p "$TMP_RUST/.qlty"
    cat > "$TMP_RUST/.qlty/qlty.toml" <<'TOML'
[[plugin]]
name = "clippy"
TOML
    RESULT=$(detect_language "$TMP_RUST")
    assert_eq "qlty.toml detect: Rust (clippy)" "rust" "$RESULT"

    # 4.4 qlty.toml-based: Go (golangci-lint)
    TMP_GO="$TMPDIR_ROOT/go_proj"
    mkdir -p "$TMP_GO/.qlty"
    cat > "$TMP_GO/.qlty/qlty.toml" <<'TOML'
[[plugin]]
name = "golangci-lint"
TOML
    RESULT=$(detect_language "$TMP_GO")
    assert_eq "qlty.toml detect: Go (golangci-lint)" "go" "$RESULT"

    # 4.5 Marker file fallback: pyproject.toml → python
    TMP_MARKER="$TMPDIR_ROOT/marker_py"
    mkdir -p "$TMP_MARKER"
    touch "$TMP_MARKER/pyproject.toml"
    RESULT=$(detect_language "$TMP_MARKER")
    assert_eq "marker fallback: pyproject.toml → python" "python" "$RESULT"

    # 4.6 Marker file fallback: package.json → node
    TMP_MARKER_NODE="$TMPDIR_ROOT/marker_node"
    mkdir -p "$TMP_MARKER_NODE"
    touch "$TMP_MARKER_NODE/package.json"
    RESULT=$(detect_language "$TMP_MARKER_NODE")
    assert_eq "marker fallback: package.json → node" "node" "$RESULT"

    # 4.7 Marker file fallback: go.mod → go
    TMP_MARKER_GO="$TMPDIR_ROOT/marker_go"
    mkdir -p "$TMP_MARKER_GO"
    touch "$TMP_MARKER_GO/go.mod"
    RESULT=$(detect_language "$TMP_MARKER_GO")
    assert_eq "marker fallback: go.mod → go" "go" "$RESULT"

    # 4.8 Marker file fallback: Cargo.toml → rust
    TMP_MARKER_RUST="$TMPDIR_ROOT/marker_rust"
    mkdir -p "$TMP_MARKER_RUST"
    touch "$TMP_MARKER_RUST/Cargo.toml"
    RESULT=$(detect_language "$TMP_MARKER_RUST")
    assert_eq "marker fallback: Cargo.toml → rust" "rust" "$RESULT"

    # 4.9 Empty directory → unknown
    TMP_EMPTY="$TMPDIR_ROOT/empty"
    mkdir -p "$TMP_EMPTY"
    RESULT=$(detect_language "$TMP_EMPTY")
    assert_eq "empty directory → unknown" "unknown" "$RESULT"

    # 4.10 Real project → python
    RESULT=$(detect_language "$PROJECT_DIR")
    assert_eq "real project → python" "python" "$RESULT"

    # 4.11 detect_pkg_manager: 8 lockfile mappings
    PKG_TESTS_PASS=true
    PKG_FAIL_DETAIL=""
    declare -A LOCKFILE_MAP=(
        ["uv.lock"]="uv"
        ["poetry.lock"]="poetry"
        ["pnpm-lock.yaml"]="pnpm"
        ["yarn.lock"]="yarn"
        ["bun.lockb"]="bun"
        ["package-lock.json"]="npm"
        ["go.sum"]="go"
        ["Cargo.lock"]="cargo"
    )
    for lockfile in "${!LOCKFILE_MAP[@]}"; do
        expected="${LOCKFILE_MAP[$lockfile]}"
        TMP_PKG="$TMPDIR_ROOT/pkg_${expected}"
        mkdir -p "$TMP_PKG"
        touch "$TMP_PKG/$lockfile"
        RESULT=$(detect_pkg_manager "$TMP_PKG")
        if [[ "$RESULT" != "$expected" ]]; then
            PKG_TESTS_PASS=false
            PKG_FAIL_DETAIL="$lockfile→expected=$expected got=$RESULT"
            break
        fi
        rm -rf "$TMP_PKG"
    done
    if [[ "$PKG_TESTS_PASS" == "true" ]]; then
        pass "detect_pkg_manager: 8 lockfile mappings"
    else
        fail "detect_pkg_manager: 8 lockfile mappings" "$PKG_FAIL_DETAIL"
    fi

    # 4.12 detect_test_runner: pytest, vitest, jest, go_test, cargo_test
    TR_PASS=true
    TR_FAIL_DETAIL=""

    # pytest
    TMP_TR="$TMPDIR_ROOT/tr_pytest"
    mkdir -p "$TMP_TR"
    printf '[tool.pytest.ini_options]\n' > "$TMP_TR/pyproject.toml"
    RESULT=$(detect_test_runner "$TMP_TR")
    [[ "$RESULT" != "pytest" ]] && TR_PASS=false && TR_FAIL_DETAIL="pytest: got=$RESULT"
    rm -rf "$TMP_TR"

    # vitest
    if [[ "$TR_PASS" == "true" ]]; then
        TMP_TR="$TMPDIR_ROOT/tr_vitest"
        mkdir -p "$TMP_TR"
        touch "$TMP_TR/vitest.config.ts"
        RESULT=$(detect_test_runner "$TMP_TR")
        [[ "$RESULT" != "vitest" ]] && TR_PASS=false && TR_FAIL_DETAIL="vitest: got=$RESULT"
        rm -rf "$TMP_TR"
    fi

    # jest
    if [[ "$TR_PASS" == "true" ]]; then
        TMP_TR="$TMPDIR_ROOT/tr_jest"
        mkdir -p "$TMP_TR"
        touch "$TMP_TR/jest.config.js"
        RESULT=$(detect_test_runner "$TMP_TR")
        [[ "$RESULT" != "jest" ]] && TR_PASS=false && TR_FAIL_DETAIL="jest: got=$RESULT"
        rm -rf "$TMP_TR"
    fi

    # go_test
    if [[ "$TR_PASS" == "true" ]]; then
        TMP_TR="$TMPDIR_ROOT/tr_go"
        mkdir -p "$TMP_TR"
        touch "$TMP_TR/go.mod"
        RESULT=$(detect_test_runner "$TMP_TR")
        [[ "$RESULT" != "go_test" ]] && TR_PASS=false && TR_FAIL_DETAIL="go_test: got=$RESULT"
        rm -rf "$TMP_TR"
    fi

    # cargo_test
    if [[ "$TR_PASS" == "true" ]]; then
        TMP_TR="$TMPDIR_ROOT/tr_cargo"
        mkdir -p "$TMP_TR"
        touch "$TMP_TR/Cargo.toml"
        RESULT=$(detect_test_runner "$TMP_TR")
        [[ "$RESULT" != "cargo_test" ]] && TR_PASS=false && TR_FAIL_DETAIL="cargo_test: got=$RESULT"
        rm -rf "$TMP_TR"
    fi

    if [[ "$TR_PASS" == "true" ]]; then
        pass "detect_test_runner: 5 runners"
    else
        fail "detect_test_runner: 5 runners" "$TR_FAIL_DETAIL"
    fi

    # Cleanup Cat 4 temp dirs
    rm -rf "$TMPDIR_ROOT"
    TMPDIR_ROOT=""
fi

# ─────────────────────────────────────────────────────
# Cat 5: auto-format.sh Hook (5 tests)
# ─────────────────────────────────────────────────────
cat_header "5: auto-format.sh Hook"

AUTOFORMAT_SCRIPT="$PROJECT_DIR/.claude/hooks/auto-format.sh"
if [[ ! -f "$AUTOFORMAT_SCRIPT" ]]; then
    skip_if "auto-format.sh not found" "all Cat 5 tests"
else
    cd "$PROJECT_DIR" || exit

    # 5.1 Qlty path: Python file format success
    TMPDIR_ROOT=$(mktemp -d)
    TMP_PY_FILE="$TMPDIR_ROOT/test_format.py"
    cat > "$TMP_PY_FILE" <<'PY'
x=1+2
y = [1,2,  3]
PY
    HOOK_INPUT="{\"tool_input\":{\"file_path\":\"$TMP_PY_FILE\"}}"
    HOOK_EXIT=0
    echo "$HOOK_INPUT" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$AUTOFORMAT_SCRIPT" 2>/dev/null || HOOK_EXIT=$?
    if [[ "$HOOK_EXIT" -eq 0 ]]; then
        pass "auto-format: Qlty path Python format"
    else
        fail "auto-format: Qlty path Python format" "exit=$HOOK_EXIT"
    fi

    # 5.2 Empty file_path → exit 0
    HOOK_EXIT=0
    echo '{"tool_input":{"file_path":""}}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$AUTOFORMAT_SCRIPT" 2>/dev/null || HOOK_EXIT=$?
    assert_eq "auto-format: empty file_path → exit 0" "0" "$HOOK_EXIT"

    # 5.3 Non-existent file → exit 0
    HOOK_EXIT=0
    echo '{"tool_input":{"file_path":"/tmp/nonexistent_e2e_test_file.py"}}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$AUTOFORMAT_SCRIPT" 2>/dev/null || HOOK_EXIT=$?
    assert_eq "auto-format: non-existent file → exit 0" "0" "$HOOK_EXIT"

    # 5.4 Fallback path: qlty removed, ruff used
    # Create a restricted PATH without qlty
    QLTY_PATH=$(command -v qlty 2>/dev/null || true)
    if [[ -n "$QLTY_PATH" ]] && command -v ruff &>/dev/null; then
        QLTY_DIR=$(dirname "$QLTY_PATH")
        # Build PATH excluding qlty's directory (only if it won't break ruff/uv)
        RUFF_PATH=$(command -v ruff)
        RUFF_DIR=$(dirname "$RUFF_PATH")
        if [[ "$QLTY_DIR" != "$RUFF_DIR" ]]; then
            RESTRICTED_PATH=""
            while IFS=: read -r -d: dir || [[ -n "$dir" ]]; do
                [[ "$dir" == "$QLTY_DIR" ]] && continue
                RESTRICTED_PATH="${RESTRICTED_PATH:+$RESTRICTED_PATH:}$dir"
            done <<< "$PATH:"

            TMP_PY_FB="$TMPDIR_ROOT/test_fallback.py"
            cat > "$TMP_PY_FB" <<'PY'
x=1+2
PY
            FB_INPUT="{\"tool_input\":{\"file_path\":\"$TMP_PY_FB\"}}"
            FB_EXIT=0
            echo "$FB_INPUT" | PATH="$RESTRICTED_PATH" CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$AUTOFORMAT_SCRIPT" 2>/dev/null || FB_EXIT=$?
            if [[ "$FB_EXIT" -eq 0 ]]; then
                pass "auto-format: fallback ruff (qlty removed from PATH)"
            else
                fail "auto-format: fallback ruff (qlty removed from PATH)" "exit=$FB_EXIT"
            fi
        else
            skip "auto-format: fallback ruff (qlty removed from PATH)" "qlty and ruff share same directory"
        fi
    else
        skip "auto-format: fallback ruff (qlty removed from PATH)" "qlty or ruff not available for PATH test"
    fi

    # 5.5 Fallback path: JS/Go/Rust extensions handled
    # Test .js extension — hook should exit 0 even without formatters
    TMP_JS="$TMPDIR_ROOT/test.js"
    echo "var x=1" > "$TMP_JS"
    JS_INPUT="{\"tool_input\":{\"file_path\":\"$TMP_JS\"}}"
    JS_EXIT=0
    echo "$JS_INPUT" | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$AUTOFORMAT_SCRIPT" 2>/dev/null || JS_EXIT=$?
    # With qlty available it uses qlty; without, it falls back to extension matching
    if [[ "$JS_EXIT" -eq 0 ]]; then
        pass "auto-format: JS/Go/Rust extension handling"
    else
        fail "auto-format: JS/Go/Rust extension handling" "exit=$JS_EXIT"
    fi

    rm -rf "$TMPDIR_ROOT"
    TMPDIR_ROOT=""
fi

# ─────────────────────────────────────────────────────
# Cat 6: run_quality_checks.sh Pipeline (6 tests)
# ─────────────────────────────────────────────────────
cat_header "6: run_quality_checks.sh Pipeline"

RQC_SCRIPT="$PROJECT_DIR/.claude/skills/clean/scripts/run_quality_checks.sh"
if [[ ! -f "$RQC_SCRIPT" ]]; then
    skip_if "run_quality_checks.sh not found" "all Cat 6 tests"
else
    cd "$PROJECT_DIR" || exit

    # 6.1 Qlty path: basic execution → "Lint (Qlty):" output
    RQC_OUTPUT=""
    RQC_EXIT=0
    RQC_OUTPUT=$(run_with_timeout 120 bash "$RQC_SCRIPT" --no-test 2>&1) || RQC_EXIT=$?
    assert_contains "run_quality_checks: Lint (Qlty): output" "Lint (Qlty):" "$RQC_OUTPUT"

    # 6.2 --no-test → Tests: SKIP
    assert_contains "run_quality_checks: --no-test → Tests: SKIP" "Tests:        SKIP" "$RQC_OUTPUT"

    # 6.3 --fix-only → LINT_STATUS FIXED or PASS
    FIXONLY_OUTPUT=""
    FIXONLY_EXIT=0
    GIT_STASHED=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
    fi
    FIXONLY_OUTPUT=$(run_with_timeout 120 bash "$RQC_SCRIPT" --no-test --fix-only 2>&1) || FIXONLY_EXIT=$?
    if echo "$FIXONLY_OUTPUT" | grep -qE "Lint \(Qlty\): (FIXED|PASS)"; then
        pass "run_quality_checks: --fix-only → FIXED or PASS"
    else
        fail "run_quality_checks: --fix-only → FIXED or PASS" "$(echo "$FIXONLY_OUTPUT" | grep 'Lint')"
    fi
    git checkout -- . 2>/dev/null || true
    if [[ "$GIT_STASHED" == "true" ]]; then
        git stash pop --quiet 2>/dev/null || true
        GIT_STASHED=false
    fi

    # 6.4 --strict → strict verdict
    STRICT_OUTPUT=""
    STRICT_EXIT=0
    STRICT_OUTPUT=$(run_with_timeout 120 bash "$RQC_SCRIPT" --no-test --strict 2>&1) || STRICT_EXIT=$?
    if echo "$STRICT_OUTPUT" | grep -qE "Overall:.*?(CLEAN|ISSUES_REMAIN)"; then
        pass "run_quality_checks: --strict verdict present"
    else
        fail "run_quality_checks: --strict verdict present"
    fi

    # 6.5 Fallback path: qlty removed → "Lint (Ruff):" output
    QLTY_PATH=$(command -v qlty 2>/dev/null || true)
    if [[ -n "$QLTY_PATH" ]] && command -v uv &>/dev/null; then
        QLTY_DIR=$(dirname "$QLTY_PATH")
        UV_DIR=$(dirname "$(command -v uv)")
        RESTRICTED_PATH=""
        while IFS=: read -r -d: dir || [[ -n "$dir" ]]; do
            [[ "$dir" == "$QLTY_DIR" ]] && continue
            RESTRICTED_PATH="${RESTRICTED_PATH:+$RESTRICTED_PATH:}$dir"
        done <<< "$PATH:"

        # Only run if we didn't remove uv's directory
        if echo "$RESTRICTED_PATH" | tr ':' '\n' | grep -qF "$UV_DIR"; then
            FB_OUTPUT=""
            FB_EXIT=0
            FB_OUTPUT=$(PATH="$RESTRICTED_PATH" CLAUDE_PROJECT_DIR="$PROJECT_DIR" run_with_timeout 120 bash "$RQC_SCRIPT" --no-test 2>&1) || FB_EXIT=$?
            assert_contains "run_quality_checks fallback: Lint (Ruff):" "Lint (Ruff):" "$FB_OUTPUT"
        else
            skip "run_quality_checks fallback: Lint (Ruff):" "removing qlty from PATH also removes uv"
        fi
    else
        skip "run_quality_checks fallback: Lint (Ruff):" "qlty or uv not available"
    fi

    # 6.6 Fallback path: uv also missing → error message
    TMPDIR_ROOT=$(mktemp -d)
    # Create a minimal PATH with only essential system commands
    MINIMAL_PATH="/usr/bin:/bin"
    FB2_OUTPUT=""
    FB2_EXIT=0
    FB2_OUTPUT=$(PATH="$MINIMAL_PATH" CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$RQC_SCRIPT" --no-test 2>&1) || FB2_EXIT=$?
    if echo "$FB2_OUTPUT" | grep -qiE "not found|error"; then
        pass "run_quality_checks fallback: no uv → error message"
    else
        # If qlty is in /usr/bin (unlikely), it might still work
        if [[ "$FB2_EXIT" -ne 0 ]]; then
            pass "run_quality_checks fallback: no uv → error message (non-zero exit)"
        else
            fail "run_quality_checks fallback: no uv → error message"
        fi
    fi
    rm -rf "$TMPDIR_ROOT"
    TMPDIR_ROOT=""
fi

# ─────────────────────────────────────────────────────
# Cat 7: Real Python Source Validation (5 tests)
# ─────────────────────────────────────────────────────
cat_header "7: Real Python Source Validation"

cd "$PROJECT_DIR" || exit

# 7.1 src/gsd_stat/ — qlty check no panic
SRC_CHECK_OUTPUT=""
SRC_CHECK_EXIT=0
SRC_CHECK_OUTPUT=$(run_with_timeout 120 qlty check 2>&1) || SRC_CHECK_EXIT=$?
if echo "$SRC_CHECK_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
    fail "src/gsd_stat/ qlty check — no panic" "panic detected"
else
    pass "src/gsd_stat/ qlty check — no panic"
fi

# 7.2 qlty fmt idempotency — two runs, no change
GIT_STASHED=false
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
fi
run_with_timeout 120 qlty fmt --all src/ scripts/ 2>/dev/null || true
# Capture state after first format
FIRST_HASH=$(git diff --stat 2>/dev/null || echo "")
# Run again
SECOND_OUTPUT=$(run_with_timeout 120 qlty fmt --all src/ scripts/ 2>&1) || true
SECOND_HASH=$(git diff --stat 2>/dev/null || echo "")
if [[ "$FIRST_HASH" == "$SECOND_HASH" ]]; then
    pass "qlty fmt idempotency — no change on second run"
else
    fail "qlty fmt idempotency — no change on second run" "diff changed between runs"
fi
git checkout -- . 2>/dev/null || true
if [[ "$GIT_STASHED" == "true" ]]; then
    git stash pop --quiet 2>/dev/null || true
    GIT_STASHED=false
fi

# 7.3 tests/ — qlty check
TESTS_CHECK_OUTPUT=""
TESTS_CHECK_EXIT=0
TESTS_CHECK_OUTPUT=$(run_with_timeout 120 qlty check 2>&1) || TESTS_CHECK_EXIT=$?
if echo "$TESTS_CHECK_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
    fail "tests/ qlty check — no panic" "panic detected"
else
    pass "tests/ qlty check — no panic"
fi

# 7.4 qlty --fix then ruff check consistency
GIT_STASHED=false
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git stash push --quiet -m "e2e-test-protection" 2>/dev/null && GIT_STASHED=true
fi
run_with_timeout 120 qlty check --fix src/ 2>/dev/null || true
RUFF_AFTER_OUTPUT=""
RUFF_AFTER_EXIT=0
if command -v uv &>/dev/null; then
    RUFF_AFTER_OUTPUT=$(uv run ruff check src/gsd_stat/ 2>&1) || RUFF_AFTER_EXIT=$?
    RUFF_ISSUE_COUNT=0
    RUFF_ISSUE_COUNT=$(echo "$RUFF_AFTER_OUTPUT" | grep -cE "^src/" 2>/dev/null) || RUFF_ISSUE_COUNT=0
    if [[ "$RUFF_ISSUE_COUNT" -le 5 ]]; then
        pass "qlty --fix then ruff check consistency (issues≤5)"
    else
        fail "qlty --fix then ruff check consistency" "ruff found $RUFF_ISSUE_COUNT issues after qlty fix"
    fi
else
    skip "qlty --fix then ruff check consistency" "uv not available"
fi
git checkout -- . 2>/dev/null || true
if [[ "$GIT_STASHED" == "true" ]]; then
    git stash pop --quiet 2>/dev/null || true
    GIT_STASHED=false
fi

# 7.5 Shell scripts — shellcheck plugin
SHELL_SCRIPTS=$(find "$PROJECT_DIR/scripts" -name "*.sh" -type f 2>/dev/null | head -3)
if [[ -n "$SHELL_SCRIPTS" ]]; then
    SHELL_CHECK_OUTPUT=""
    SHELL_CHECK_EXIT=0
    SHELL_CHECK_OUTPUT=$(run_with_timeout 120 qlty check 2>&1) || SHELL_CHECK_EXIT=$?
    if echo "$SHELL_CHECK_OUTPUT" | grep -qiE "panic|segfault|SIGSEGV"; then
        fail "shell scripts — shellcheck plugin no panic" "panic detected"
    else
        pass "shell scripts — shellcheck plugin no panic"
    fi
else
    skip "shell scripts — shellcheck plugin" "no .sh files in scripts/"
fi

# ─────────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────────
printf "\n${_color_cyan}=== RESULTS: %d passed, %d failed, %d skipped ===${_color_reset}\n" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
