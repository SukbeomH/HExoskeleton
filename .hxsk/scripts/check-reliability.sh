#!/usr/bin/env bash
# Known-issue checker for HXSK reliability fixes
# Returns count of remaining known issues (0 = all fixed)
set -uo pipefail

issues=0

# RE-1: TYPE_DIR silent redirect to general (should warn + mkdir -p instead)
if grep -q 'TYPE_DIR=.*general' .hxsk/hooks/md-store-memory.sh 2>/dev/null; then
    echo "FAIL RE-1: md-store-memory.sh TYPE_DIR silent redirect to general"
    issues=$((issues+1))
fi

# RE-3: missing -e in md-store-memory.sh
if grep -q '^set -uo pipefail' .hxsk/hooks/md-store-memory.sh 2>/dev/null && \
   ! grep -q '^set -euo pipefail' .hxsk/hooks/md-store-memory.sh 2>/dev/null; then
    echo "FAIL RE-3a: md-store-memory.sh missing -e in set flags"
    issues=$((issues+1))
fi

# RE-3: missing -e in md-recall-memory.sh
if grep -q '^set -uo pipefail' .hxsk/hooks/md-recall-memory.sh 2>/dev/null && \
   ! grep -q '^set -euo pipefail' .hxsk/hooks/md-recall-memory.sh 2>/dev/null; then
    echo "FAIL RE-3b: md-recall-memory.sh missing -e in set flags"
    issues=$((issues+1))
fi

# DA-4: recall fallback without [NO_MATCH] marker
if ! grep -q 'NO_MATCH' .hxsk/hooks/md-recall-memory.sh 2>/dev/null; then
    echo "FAIL DA-4: md-recall-memory.sh no [NO_MATCH] marker on fallback"
    issues=$((issues+1))
fi

# RE-6: head-100 hard cap (should use variable)
if grep -q 'head -100' .hxsk/hooks/md-recall-memory.sh 2>/dev/null; then
    echo "FAIL RE-6: md-recall-memory.sh hard-coded head -100"
    issues=$((issues+1))
fi

# RE-5: md-store-memory.sh YAML injection via title/tags (yaml_safe must be applied)
if ! grep -q 'yaml_safe' .hxsk/hooks/md-store-memory.sh 2>/dev/null; then
    echo "FAIL RE-5: md-store-memory.sh missing yaml_safe() for YAML injection prevention"
    issues=$((issues+1))
fi

# H-05: setup.md U2 SHA256 verification snippet missing
if ! grep -q 'sha256sum\|SHA256' .hxsk/prompts/setup.md 2>/dev/null; then
    echo "FAIL H-05: setup.md U2 missing SHA256 verification snippet"
    issues=$((issues+1))
fi

# SA-7: stop-context-save.sh flag race condition (should use atomic mv)
if ! grep -qiE 'CLAIMED_FLAG|mv.*CLAIMED|claimed' .hxsk/hooks/stop-context-save.sh 2>/dev/null; then
    echo "FAIL SA-7: stop-context-save.sh missing atomic mv pattern for flag claim"
    issues=$((issues+1))
fi

# SA-8: stale lock detection missing in prune-tick.sh
if ! grep -qE 'stale|lock_age|mtime.*300' .hxsk/scripts/prune-tick.sh 2>/dev/null; then
    echo "FAIL SA-8: prune-tick.sh no stale lock detection"
    issues=$((issues+1))
fi

# C1: CORRUPTED branch missing in setup.md
if ! grep -q 'CORRUPTED' .hxsk/prompts/setup.md 2>/dev/null; then
    echo "FAIL C1: setup.md missing CORRUPTED branch in Step 0"
    issues=$((issues+1))
fi

# C3: git add -A in setup.md U6
if grep -q 'git add -A' .hxsk/prompts/setup.md 2>/dev/null; then
    echo "FAIL C3: setup.md U6 uses git add -A (secrets risk)"
    issues=$((issues+1))
fi

# DA-3: CLAUDE_PROJECT_DIR without .hxsk validation
for f in .hxsk/hooks/md-store-memory.sh .hxsk/hooks/md-recall-memory.sh .hxsk/scripts/prune-tick.sh; do
    if grep -qE 'CLAUDE_PROJECT_DIR|PROJECT_DIR' "$f" 2>/dev/null && \
       ! grep -qE '\.hxsk.*not found|! -d.*\.hxsk|if.*\.hxsk' "$f" 2>/dev/null; then
        echo "FAIL DA-3: $f uses CLAUDE_PROJECT_DIR without .hxsk/ existence check"
        issues=$((issues+1))
    fi
done

echo ""
echo "ISSUE COUNT: $issues"
exit 0
