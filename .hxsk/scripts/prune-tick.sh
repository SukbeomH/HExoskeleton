#!/usr/bin/env bash
# prune-tick.sh — 하네스 독립 opportunistic prune 트리거
#
# 목적:
#   Claude Code 외 하네스(Cursor/Gemini CLI/OpenCode/Aider/Continue 등)에서도
#   HXSK 메모리 툴(md-store-memory.sh, md-recall-memory.sh, bootstrap.sh)이
#   호출될 때마다 자연스럽게 prune이 발화하도록 하는 얇은 어댑터.
#
# 설계:
#   - sentinel mtime 기반 cooldown — 지정된 초 이내 재실행 skip
#   - mkdir atomic lock — 동시 실행 방지 (BashFAQ/045)
#   - 백그라운드 실행 — 호출자 블로킹 없음
#   - 실패해도 조용히 종료 — 호출자 동작에 영향 없음
#
# 호출자 스니펫 (md-store-memory.sh 등 말미):
#   bash "$PROJECT_DIR/.hxsk/scripts/prune-tick.sh" >/dev/null 2>&1 &
#
# 설정: .hxsk/.prune-config (shell-sourceable, 선택)
#   PRUNE_TICK_COOLDOWN=60          # 재실행 쿨다운(초)
#   PRUNE_DEFAULT_CAP=5             # tier별 기본 cap
#   PRUNE_CAP_bootstrap=1           # tier별 개별 오버라이드

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
if [ ! -d "$HXSK_DIR" ]; then
    echo "[ERROR] prune-tick: .hxsk/ not found at '$PROJECT_DIR'. Set CLAUDE_PROJECT_DIR." >&2
    exit 1
fi
TICK_FILE="$HXSK_DIR/.last-prune-ts"
LOCK_DIR="$HXSK_DIR/.prune-lock"
PRUNE_SCRIPT="$HXSK_DIR/scripts/prune-memories.sh"
LOG_FILE="$HXSK_DIR/.context-save.log"

# 기본 cooldown (60초). 설정으로 오버라이드 가능.
PRUNE_TICK_COOLDOWN=60
PRUNE_CFG="$HXSK_DIR/.prune-config"
if [[ -f "$PRUNE_CFG" ]]; then
    _MODE=$(stat -f '%A' "$PRUNE_CFG" 2>/dev/null || stat -c '%a' "$PRUNE_CFG" 2>/dev/null || echo "600")
    if [[ -O "$PRUNE_CFG" ]] && (( ! (8#$_MODE & 8#022) )); then
        # shellcheck disable=SC1090
        source "$PRUNE_CFG"
    else
        echo "[WARN] prune-tick: skipping .prune-config (not owner-only writable, mode=$_MODE)" >&2
    fi
fi

# 설정 값 정규화: 비정상 값(빈/음수/문자열)이면 기본값 폴백.
# 산술 비교 시 "integer expression expected" 또는 부호 혼동 방지.
if [[ ! "$PRUNE_TICK_COOLDOWN" =~ ^[0-9]+$ ]]; then
    PRUNE_TICK_COOLDOWN=60
fi

# ── 선행 체크 ──
[[ -f "$PRUNE_SCRIPT" ]] || exit 0
[[ -d "$HXSK_DIR/memories" ]] || exit 0

# ── Cooldown 체크: 마지막 실행으로부터 충분한 시간이 흘렀는가? ──
if [[ -f "$TICK_FILE" ]]; then
    LAST=$(stat -f '%m' "$TICK_FILE" 2>/dev/null || stat -c '%Y' "$TICK_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if [[ $((NOW - LAST)) -lt "$PRUNE_TICK_COOLDOWN" ]]; then
        exit 0
    fi
fi

# ── Atomic lock: 동시 실행 방지 ──
# mkdir은 POSIX 원자적 연산. 이미 존재하면 실패 → 다른 tick이 진행 중.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # stale lock 감지: SIGKILL 등으로 trap이 실행되지 않아 lock이 잔존할 수 있음
    if [ -d "$LOCK_DIR" ]; then
        lock_ctime=$(stat -f '%m' "$LOCK_DIR" 2>/dev/null || stat -c '%Y' "$LOCK_DIR" 2>/dev/null || echo 0)
        now=$(date +%s)
        lock_age=$(( now - lock_ctime ))
        if [ "$lock_age" -gt 300 ]; then
            echo "[WARN] prune-tick: Removing stale lock (age: ${lock_age}s)" >&2
            rmdir "$LOCK_DIR" 2>/dev/null || true
            mkdir "$LOCK_DIR" 2>/dev/null || exit 0
        else
            exit 0
        fi
    else
        exit 0
    fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# 타임스탬프 선갱신 — prune이 실패해도 재시도 폭주 방지
touch "$TICK_FILE"

# ── 실제 prune 실행 ──
# --auto 모드: 설정 기반 tier별 cap 적용.
# stderr은 로그로, stdout도 로그로 (호출자에 노출 X).
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] prune-tick fired (cooldown=${PRUNE_TICK_COOLDOWN}s)"
    bash "$PRUNE_SCRIPT" --auto 2>&1
} >> "$LOG_FILE" 2>&1 || true

exit 0
