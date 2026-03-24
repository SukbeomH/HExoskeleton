#!/usr/bin/env bash
#
# build-common.sh — Shared functions for build-plugin/antigravity/opencode
#
# Usage: source "$(cd "$(dirname "$0")" && pwd)/build-common.sh"
#

# --- Build Script Initialization ---
# init_build <title> <source_dir> <target_dir>
init_build() {
    local title="$1"
    local source_dir="$2"
    local target_dir="$3"

    echo "=== ${title} ==="
    echo "Source: ${source_dir}"
    echo "Target: ${target_dir}"
    echo ""
}

# --- Phase Header ---
# phase_header <phase_num> <description>
phase_header() {
    local num="$1"
    local desc="$2"
    echo "[Phase ${num}] ${desc}"
}

# --- Verification Phase ---
# verify_header <phase_num>
verify_header() {
    local num="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[Phase ${num}] Verification"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# verify_dirs <target_dir> <dir1> <dir2> ...
# Returns number of errors via global BUILD_ERRORS
verify_dirs() {
    local target="$1"; shift
    echo ""
    echo "[Structure]"
    for dir in "$@"; do
        if [ -d "$target/$dir" ]; then
            echo "  [OK] $dir/"
        else
            echo "  [FAIL] $dir/ missing"
            BUILD_ERRORS=$((BUILD_ERRORS + 1))
        fi
    done
}

# verify_count <label> <actual> <expected>
# Prints count and warns if below expected
verify_count() {
    local label="$1"
    local actual="$2"
    local expected="$3"

    printf "  %-12s %s (expected: %s)\n" "${label}:" "$actual" "$expected"
    if [ "$actual" -lt "$expected" ]; then
        echo "    [WARN] Expected ${expected} ${label}"
        BUILD_WARNINGS=$((BUILD_WARNINGS + 1))
    fi
}

# verify_json <json_path>
# Validates JSON file and increments BUILD_ERRORS on failure
# Pure bash: non-empty check + first-char check + jq/awk bracket balance
verify_json() {
    local json_path="$1"
    local label
    label="$(basename "$json_path")"

    # Check file is non-empty
    if [ ! -s "$json_path" ]; then
        echo "  [FAIL] ${label} empty or missing"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
        return
    fi

    # Check first non-whitespace character is { or [
    local first_char
    first_char="$(sed 's/^[[:space:]]*//' "$json_path" | head -c1)"
    if [[ "$first_char" != "{" && "$first_char" != "[" ]]; then
        echo "  [FAIL] ${label} invalid (bad start character)"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
        return
    fi

    # Deep validation: prefer jq, fallback to awk bracket balance
    if command -v jq &>/dev/null; then
        if jq empty "$json_path" 2>/dev/null; then
            echo "  [OK] ${label}"
        else
            echo "  [FAIL] ${label} invalid"
            BUILD_ERRORS=$((BUILD_ERRORS + 1))
        fi
    else
        # awk bracket balance check (outside strings)
        local balanced
        balanced="$(awk '
        BEGIN { depth=0; in_str=0 }
        {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (in_str) {
                    if (c == "\\" ) { i++; continue }
                    if (c == "\"") in_str=0
                    continue
                }
                if (c == "\"") { in_str=1; continue }
                if (c == "{" || c == "[") depth++
                if (c == "}" || c == "]") depth--
            }
        }
        END { print depth }
        ' "$json_path")"
        if [ "$balanced" -eq 0 ]; then
            echo "  [OK] ${label}"
        else
            echo "  [FAIL] ${label} invalid (unbalanced brackets)"
            BUILD_ERRORS=$((BUILD_ERRORS + 1))
        fi
    fi
}

# verify_json_optional <json_path>
# Like verify_json but only if file exists
verify_json_optional() {
    local json_path="$1"
    if [ -f "$json_path" ]; then
        verify_json "$json_path"
    fi
}

# --- Build Result ---
# print_build_result <target_dir> <usage_lines...>
# Checks BUILD_ERRORS and BUILD_WARNINGS, prints summary
print_build_result() {
    local target="$1"; shift
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "${BUILD_ERRORS:-0}" -eq 0 ]; then
        echo "BUILD SUCCESSFUL"
        if [ "${BUILD_WARNINGS:-0}" -gt 0 ]; then
            echo "  (${BUILD_WARNINGS} warning(s))"
        fi
        echo ""
        echo "Output: ${target}"
        echo ""
        # Print usage lines passed as arguments
        for line in "$@"; do
            echo "$line"
        done
    else
        echo "BUILD COMPLETED WITH ${BUILD_ERRORS} ERROR(S)"
        if [ "${BUILD_WARNINGS:-0}" -gt 0 ]; then
            echo "  (${BUILD_WARNINGS} warning(s))"
        fi
        exit 1
    fi
}

# --- Global error/warning counters ---
BUILD_ERRORS=0
BUILD_WARNINGS=0

# extract_frontmatter_field <file> <field>
extract_frontmatter_field() {
    local file="$1"
    local field="$2"
    awk -v fld="$field" '
        BEGIN { in_fm=0 }
        NR==1 && /^---/ { in_fm=1; next }
        in_fm && /^---/ { exit }
        in_fm && $0 ~ "^" fld ":" {
            sub("^" fld ":[ ]*", "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$file"
}
