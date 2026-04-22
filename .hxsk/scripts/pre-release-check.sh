#!/usr/bin/env bash
# pre-release-check.sh — 릴리스 전 무결성 검증
# Usage: bash .hxsk/scripts/pre-release-check.sh [--dry-run]
# Output: .hxsk/logs/pre-release-check.log (상세), stdout (요약)
set -uo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOG_DIR="$PROJECT_DIR/.hxsk/logs"
LOG_FILE="$LOG_DIR/pre-release-check.log"
CACHE_DIR="$PROJECT_DIR/.hxsk/cache"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
BOOTSTRAP="$PROJECT_DIR/.hxsk/scripts/bootstrap.sh"

mkdir -p "$LOG_DIR"

TS=$(date '+%Y-%m-%d %H:%M:%S')
issues=0

log() { echo "[$TS] $*" | tee -a "$LOG_FILE"; }
fail() { log "FAIL: $*"; issues=$((issues + 1)); }
pass() { log "PASS: $*"; }

log "=== pre-release-check start (dry-run=$DRY_RUN) ==="

# ── 1. SHA256 계산 (tarball 캐시가 있는 경우) ──
if [[ -d "$CACHE_DIR" ]]; then
    TARBALLS=$(find "$CACHE_DIR" -name "setup-v*.tar.gz" 2>/dev/null || true)
    if [[ -n "$TARBALLS" ]]; then
        log "--- SHA256 checksums ---"
        while IFS= read -r tb; do
            if command -v sha256sum >/dev/null 2>&1; then
                SUM=$(sha256sum "$tb" | awk '{print $1}')
            elif command -v shasum >/dev/null 2>&1; then
                SUM=$(shasum -a 256 "$tb" | awk '{print $1}')
            else
                SUM="(sha256 tool not found)"
            fi
            log "  $SUM  $(basename "$tb")"
        done <<< "$TARBALLS"
    else
        log "INFO: No setup-v*.tar.gz found in $CACHE_DIR (skipping SHA256)"
    fi
else
    log "INFO: Cache directory $CACHE_DIR does not exist (skipping SHA256)"
fi

# ── 2. CHANGELOG 동기화 확인 ──
if [[ -f "$PROJECT_DIR/.hxsk/.bootstrap-version" ]]; then
    CURRENT_VERSION=$(grep 'version:' "$PROJECT_DIR/.hxsk/.bootstrap-version" \
        | head -1 | sed 's/version:[[:space:]]*//' | tr -d '[:space:]' || true)
    if [[ -n "$CURRENT_VERSION" && -f "$CHANGELOG" ]]; then
        if grep -q "$CURRENT_VERSION" "$CHANGELOG" 2>/dev/null; then
            pass "CHANGELOG contains version $CURRENT_VERSION"
        else
            fail "CHANGELOG does not mention version $CURRENT_VERSION"
        fi
    elif [[ ! -f "$CHANGELOG" ]]; then
        log "WARN: CHANGELOG.md not found (skipping version sync check)"
    else
        log "INFO: Could not determine current version"
    fi
else
    log "INFO: .bootstrap-version not found (skipping CHANGELOG sync check)"
fi

# ── 3. check-reliability.sh — 0 이슈 확인 ──
RELIABILITY_SCRIPT="$PROJECT_DIR/.hxsk/scripts/check-reliability.sh"
if [[ -f "$RELIABILITY_SCRIPT" ]]; then
    RELIABILITY_OUT=$(bash "$RELIABILITY_SCRIPT" 2>/dev/null || true)
    ISSUE_COUNT=$(echo "$RELIABILITY_OUT" | grep 'ISSUE COUNT:' | awk '{print $NF}' || echo "unknown")
    if [[ "$ISSUE_COUNT" == "0" ]]; then
        pass "check-reliability.sh ISSUE COUNT: 0"
    else
        fail "check-reliability.sh ISSUE COUNT: $ISSUE_COUNT"
        echo "$RELIABILITY_OUT" >> "$LOG_FILE"
    fi
else
    log "WARN: check-reliability.sh not found"
fi

# ── 4. bootstrap.sh 존재 + 실행 가능 확인 ──
if [[ -f "$BOOTSTRAP" && -x "$BOOTSTRAP" ]]; then
    pass "bootstrap.sh exists and is executable"
elif [[ -f "$BOOTSTRAP" ]]; then
    log "WARN: bootstrap.sh exists but is not executable (chmod +x recommended)"
else
    fail "bootstrap.sh not found at $BOOTSTRAP"
fi

# ── 결과 요약 ──
log "=== pre-release-check complete: ISSUE COUNT: $issues ==="

echo ""
echo "ISSUE COUNT: $issues"
echo "Log: $LOG_FILE"

exit 0
