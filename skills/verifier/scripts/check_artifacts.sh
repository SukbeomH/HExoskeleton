#!/usr/bin/env bash

# Verify existence and substance of artifact files listed in a plan or spec.
# Usage: bash scripts/check_artifacts.sh <file1> [file2] ...
#        bash scripts/check_artifacts.sh --from-plan PLAN.md

set -o errexit
set -o nounset
set -o pipefail

EXIST=0
MISSING=0
EMPTY=0
RESULTS=()

check_file() {
    local file="$1"
    if [[ ! -e "$file" ]]; then
        RESULTS+=("{\"file\": \"$file\", \"status\": \"MISSING\"}")
        MISSING=$((MISSING + 1))
    elif [[ ! -s "$file" ]]; then
        RESULTS+=("{\"file\": \"$file\", \"status\": \"EMPTY\"}")
        EMPTY=$((EMPTY + 1))
    else
        local lines
        lines=$(wc -l < "$file" | tr -d ' ')
        RESULTS+=("{\"file\": \"$file\", \"status\": \"EXISTS\", \"lines\": $lines}")
        EXIST=$((EXIST + 1))
    fi
}

# Parse arguments
FILES=()
if [[ "${1:-}" == "--from-plan" ]] && [[ -n "${2:-}" ]]; then
    # Extract file paths from PLAN.md <files> tags
    while IFS= read -r line; do
        FILES+=("$line")
    done < <(grep -oP '(?<=<files>).*(?=</files>)' "$2" | tr ',' '\n' | sed 's/^ *//;s/ *$//' || true)

    if [[ ${#FILES[@]} -eq 0 ]]; then
        # Try files_modified from frontmatter
        while IFS= read -r line; do
            FILES+=("$line")
        done < <(grep -A 100 'files_modified:' "$2" | grep '^\s*-' | sed 's/^\s*- //' | head -50 || true)
    fi
else
    FILES=("$@")
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo '{"error": "No files specified. Use: scripts/check_artifacts.sh file1 file2 ... or --from-plan PLAN.md"}'
    exit 1
fi

for f in "${FILES[@]}"; do
    [[ -n "$f" ]] && check_file "$f"
done

# Output JSON
TOTAL=$((EXIST + MISSING + EMPTY))
RESULTS_JSON=$(printf '%s,' "${RESULTS[@]}")
RESULTS_JSON="[${RESULTS_JSON%,}]"

cat <<EOF
{
  "total": $TOTAL,
  "exists": $EXIST,
  "missing": $MISSING,
  "empty": $EMPTY,
  "status": "$([ "$MISSING" -eq 0 ] && [ "$EMPTY" -eq 0 ] && echo "PASS" || echo "GAPS_FOUND")",
  "files": $RESULTS_JSON
}
EOF

[[ "$MISSING" -eq 0 ]] && [[ "$EMPTY" -eq 0 ]] && exit 0 || exit 1
