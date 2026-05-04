#!/usr/bin/env bash
# Hook: Stop — 세션 컨텍스트 저장 (외부 종속성 없음)
# strict-mode-exempt: background/cleanup-heavy hook; top-level errexit would break best-effort save/prune flow
# .hxsk/.modified-this-session 플래그가 있을 때만 실행
# 1) 순수 bash 템플릿으로 CURRENT.md 생성 (Nemori 서사 형태)
# 2) 파일 기반 메모리로 세션 메모리 저장 (A-Mem 확장)
# 백그라운드 실행으로 hook timeout 회피

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAG_FILE="$PROJECT_DIR/.hxsk/.modified-this-session"
CURRENT_MD="$PROJECT_DIR/.hxsk/CURRENT.md"
LOG_FILE="$PROJECT_DIR/.hxsk/.context-save.log"
TRACK_LOG="$PROJECT_DIR/.hxsk/.track-modifications.log"

# Atomic claim: mv은 같은 파일시스템 내에서 POSIX 원자적 연산.
# 두 프로세스가 동시 실행될 때 정확히 하나만 성공, 나머지는 exit 0.
CLAIMED_FLAG="${FLAG_FILE}.$$"
mv "$FLAG_FILE" "$CLAIMED_FLAG" 2>/dev/null || exit 0

# 변경 정보 수집
MODIFIED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -30)
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIFF_STAT=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -5)
RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null)

# 백그라운드 실행
(
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    # ── 1. Canonical active-state latest snapshot 갱신 ──
    ACTIVE_STATE_SCRIPT="$PROJECT_DIR/.hxsk/scripts/active-state.sh"
    if [[ -f "$ACTIVE_STATE_SCRIPT" ]]; then
        ACTIVE_STATE_TS="$TS" \
        ACTIVE_STATE_BRANCH="$BRANCH" \
        ACTIVE_STATE_MODIFIED="$MODIFIED" \
        ACTIVE_STATE_DIFF_STAT="$DIFF_STAT" \
        ACTIVE_STATE_RECENT_COMMITS="$RECENT_COMMITS" \
            bash "$ACTIVE_STATE_SCRIPT" stop >> "$LOG_FILE" 2>&1 || true
        echo "[$TS] active-state snapshot saved" >> "$LOG_FILE"
    fi

    # ── 2. 파일 기반 메모리 저장 (변경 파일이 1개 이상일 때) ──
    # Nemori + A-Mem: 서사 형태 + 확장 필드로 저장
    FILE_COUNT=$(echo "$MODIFIED" | grep -c '.' 2>/dev/null || echo "0")

    # track-modifications.log에서 수정 횟수 집계
    MODIFICATIONS_COUNT=0
    if [[ -f "$TRACK_LOG" ]]; then
        MODIFICATIONS_COUNT=$(wc -l < "$TRACK_LOG" | tr -d ' ')
    fi

    # ── Write-gating: 의미 있는 변경만 집계 ──
    # 훅이 생성하는 파일(CURRENT.md, STATE.md, .hxsk 내부 로그)만 있는 세션은
    # session-summary로 남길 가치가 없음 → 저장 생략
    MEANINGFUL=$(echo "$MODIFIED" | sed 's/^[[:space:]MADRC?]*//' \
        | grep -v -E '^(\.hxsk/CURRENT\.md|\.hxsk/STATE\.md|\.hxsk/SESSION_HANDOFF\.md|\.hxsk/runtime/.*|\.hxsk/\..*\.log|\.hxsk/\.modified-this-session)$' \
        | grep -c '.' 2>/dev/null || echo "0")

    if [[ "$MEANINGFUL" -ge 1 ]]; then
        # ── 중복 스킵: 실 변경 내용이 이전과 동일하면 저장 생략 ──
        # 지문 = HEAD 해시 + git status + diff stat 요약의 해시
        # (MODIFICATIONS_COUNT는 단조 증가해 같은 diff에도 값이 달라져 부적합)
        SUMMARY_DIR="$PROJECT_DIR/.hxsk/memories/session-summary"
        HEAD_HASH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "nohead")
        DIFF_SIG=$(printf '%s\n%s\n' "$MODIFIED" "$DIFF_STAT" | md5 2>/dev/null \
            || printf '%s\n%s\n' "$MODIFIED" "$DIFF_STAT" | md5sum 2>/dev/null | awk '{print $1}' \
            || echo "nomd5")
        CUR_FINGERPRINT="${HEAD_HASH}|${DIFF_SIG}"
        LATEST=$(ls -t "$SUMMARY_DIR"/*.md 2>/dev/null | head -1)
        if [[ -n "$LATEST" ]]; then
            LAST_FINGERPRINT=$(grep -m1 '^fingerprint:' "$LATEST" 2>/dev/null | sed 's/^fingerprint: //')
            if [[ "$CUR_FINGERPRINT" == "$LAST_FINGERPRINT" ]]; then
                echo "[$TS] Memory store skipped (same fingerprint: $CUR_FINGERPRINT)" >> "$LOG_FILE"
                rm -f "$TRACK_LOG" "$CLAIMED_FLAG"
                exit 0
            fi
        fi

        # CURRENT.md가 있으면 풍부한 content 사용, 없으면 fallback
        if [[ -f "$CURRENT_MD" ]]; then
            MEMORY_CONTENT=$(head -30 "$CURRENT_MD" 2>/dev/null || true)
        else
            MEMORY_CONTENT="On $TS, the developer worked on the $BRANCH branch, modifying $FILE_COUNT files. $(echo "$RECENT_COMMITS" | head -1)"
        fi
        # 지문 라인 추가 (다음 실행의 중복 감지용)
        MEMORY_CONTENT="${MEMORY_CONTENT}
fingerprint: $CUR_FINGERPRINT"
        # modifications_count 추가
        MEMORY_CONTENT="${MEMORY_CONTENT}
modifications_count: $MODIFICATIONS_COUNT"

        # A-Mem 확장 필드: keywords, contextual_description
        # 변경 파일에서 키워드 추출
        KEYWORDS=$(echo "$MODIFIED" | head -5 | sed 's/^[[:space:]MADRC?]*//' | xargs -I{} basename {} 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        SHORT_COMMIT=$(echo "$RECENT_COMMITS" | head -1 | sed 's/^[a-f0-9]* //' | cut -c1-80)
        CONTEXTUAL_DESC="[$BRANCH] $FILE_COUNT files${SHORT_COMMIT:+. ${SHORT_COMMIT}}"

        "$HOOK_DIR/md-store-memory.sh" \
            "Session [$TS]: $BRANCH" \
            "$MEMORY_CONTENT" \
            "session-summary,branch:$BRANCH,auto" \
            "session-summary" \
            "$KEYWORDS" \
            "$CONTEXTUAL_DESC" \
            "" 2>/dev/null \
            && echo "[$TS] Memory stored (A-Mem extended)" >> "$LOG_FILE" \
            || echo "[$TS] Memory store failed" >> "$LOG_FILE"
    fi

    # ── 3. .context-save.log 로테이션 (1MB 초과 시) ──
    if [[ -f "$LOG_FILE" ]]; then
        LOG_SIZE=$(wc -c < "$LOG_FILE" | tr -d ' ')
        if [[ "$LOG_SIZE" -gt 1048576 ]]; then
            mv "$LOG_FILE" "${LOG_FILE%.log}-$(date '+%Y%m').log"
        fi
    fi

    # ── 4. track-modifications.log + claimed flag 정리 ──
    rm -f "$TRACK_LOG" "$CLAIMED_FLAG"

    # ── 5. 모든 local-tier 자동 prune (설정 기반)
    #    --auto: .hxsk/.prune-config의 tier별 cap(기본 5, bootstrap 1) 적용.
    #    Stop은 매 턴 발화하지만 --auto는 cap 초과 tier만 처리하여 매우 빠름.
    #    단일 tier 하드코드 대신 전 tier 통합 관리.
    PRUNE_SCRIPT="$PROJECT_DIR/.hxsk/scripts/prune-memories.sh"
    if [[ -f "$PRUNE_SCRIPT" ]]; then
        bash "$PRUNE_SCRIPT" --auto >> "$LOG_FILE" 2>&1 || true
    fi
) &

exit 0
