#!/usr/bin/env bash
# prune-memories.sh — local-tier 메모리 리텐션 정리
#
# 사용법:
#   bash .hxsk/scripts/prune-memories.sh [RETENTION_DAYS] [--dry-run]
#   bash .hxsk/scripts/prune-memories.sh --max-count N [--tier TIER] [--dry-run]
#
# 예시:
#   bash .hxsk/scripts/prune-memories.sh                         # 7일 초과 삭제 (TTL)
#   bash .hxsk/scripts/prune-memories.sh 30                      # 30일 초과 삭제
#   bash .hxsk/scripts/prune-memories.sh --dry-run               # TTL 대상만 출력
#   bash .hxsk/scripts/prune-memories.sh 0 --dry-run             # 전체 대상 (0=모든 파일)
#   bash .hxsk/scripts/prune-memories.sh --max-count 20          # tier별 최신 20개만 유지 (FIFO)
#   bash .hxsk/scripts/prune-memories.sh --max-count 20 --tier session-summary  # 특정 tier만
#
# 동작:
#   - 기본 모드: RETENTION_DAYS(기본 7일) 초과 파일 삭제 (TTL 기반)
#   - --max-count 모드: tier별 mtime 최신 N개 유지, 나머지 삭제 (cap 기반)
#   - 대상: local-tier (gitignore 대상). shared-tier는 건드리지 않음
#   - git log/PR이 실행 이력을 대체하므로 _retained 이동 불필요
#
# 가치 기반 승격 (삭제 직전 구제):
#   frontmatter tags에 다음 키워드가 있으면 삭제 대신 shared-tier로 이동:
#     decision / architecture-decision → memories/architecture-decision/
#     root-cause                       → memories/root-cause/
#     incident / security              → memories/security-finding/
#     pattern                          → memories/pattern-discovery/
#     lesson                           → memories/lessons-learned/
#   이동된 파일은 git으로 장기 보존됨 (사용자가 다음 커밋에 포함).
#
# 멀티 리모트: gitignored 파일이므로 각 환경에서 독립적으로 수행.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEM_DIR="$PROJECT_DIR/.hxsk/memories"
RETENTION_DAYS=7
DRY_RUN=0
RETENTION_DAYS_SET=0
MAX_COUNT=""
TIER_FILTER=""

# --help용: 파일 상단의 연속 주석 블록을 종료까지 출력 (delimiter 기반)
print_help() {
    awk '
        NR == 1 && /^#!/ { next }
        /^#/ { sub(/^# ?/, ""); print; next }
        { exit }
    ' "$0"
}

# 인자 파싱:
#  - --dry-run / -n: 플래그
#  - --help / -h: 도움말 출력 후 종료
#  - 순수 숫자: RETENTION_DAYS (한 번만 허용, 중복 거부)
#  - 그 외: Unknown → exit 1
while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --help|-h)
            print_help
            exit 0
            ;;
        --max-count)
            shift
            if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ ]]; then
                echo "--max-count requires a non-negative integer" >&2
                exit 1
            fi
            MAX_COUNT="$1"
            ;;
        --tier)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "--tier requires a tier name" >&2
                exit 1
            fi
            TIER_FILTER="$1"
            ;;
        *)
            if [[ "$arg" =~ ^[0-9]+$ ]]; then
                if [[ "$RETENTION_DAYS_SET" -eq 1 ]]; then
                    echo "Multiple RETENTION_DAYS values (already '$RETENTION_DAYS', got '$arg')" >&2
                    exit 1
                fi
                RETENTION_DAYS="$arg"
                RETENTION_DAYS_SET=1
            else
                echo "Unknown argument: $arg" >&2
                echo "Usage: $0 [RETENTION_DAYS] [--dry-run] | $0 --max-count N [--tier T] [--dry-run]" >&2
                exit 1
            fi
            ;;
    esac
    shift
done

# local-tier만 정리 (shared-tier는 git으로 관리)
LOCAL_TIERS=(
    session-summary
    session-snapshot
    session-handoff
    health-event
    debug-blocked
    debug-eliminated
    bootstrap
    general
    deviation
)

[[ -d "$MEM_DIR" ]] || { echo "memories/ 없음: $MEM_DIR"; exit 0; }

deleted=0
failed=0
promoted=0

# 가치 기반 승격 매핑: frontmatter tags → shared-tier 폴더
# 첫 번째 매칭 태그의 대상 폴더로 이동 (git으로 장기 보존)
promote_target() {
    local f="$1"
    # frontmatter 블록(첫 ---...--- 사이) 내의 tags 라인만 검사
    local tags_block
    tags_block=$(awk '/^---$/{c++; next} c==1' "$f" 2>/dev/null | head -30)
    case "$tags_block" in
        *decision*|*architecture-decision*) echo "architecture-decision" ;;
        *root-cause*)                       echo "root-cause" ;;
        *incident*|*security*)              echo "security-finding" ;;
        *pattern*)                          echo "pattern-discovery" ;;
        *lesson*)                           echo "lessons-learned" ;;
        *) echo "" ;;
    esac
}

delete_file() {
    local f="$1"
    # 삭제 전 승격 검사: 가치 태그가 있으면 shared-tier로 이동
    local target
    target=$(promote_target "$f")
    if [[ -n "$target" ]]; then
        local dest_dir="$MEM_DIR/$target"
        local dest="$dest_dir/$(basename "$f")"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "[dry-run] would promote: $f → $dest"
            promoted=$((promoted + 1))
        else
            mkdir -p "$dest_dir"
            if mv -n "$f" "$dest" 2>/dev/null; then
                promoted=$((promoted + 1))
            else
                echo "promote failed (falling back to delete): $f" >&2
                rm -f "$f" 2>/dev/null && deleted=$((deleted + 1)) || failed=$((failed + 1))
            fi
        fi
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] would delete: $f"
        deleted=$((deleted + 1))
    else
        if rm -f "$f" 2>/dev/null; then
            deleted=$((deleted + 1))
        else
            echo "rm failed: $f" >&2
            failed=$((failed + 1))
        fi
    fi
}

if [[ -n "$MAX_COUNT" ]]; then
    # ── cap 기반: tier별 최신 MAX_COUNT개 유지, 나머지 삭제 ──
    for tier in "${LOCAL_TIERS[@]}"; do
        [[ -n "$TIER_FILTER" && "$tier" != "$TIER_FILTER" ]] && continue
        src="$MEM_DIR/$tier"
        [[ -d "$src" ]] || continue

        # mtime 최신→오래된 순 정렬. 0 기반 skip 후 나머지 삭제.
        # stat 이식성: BSD(%m)/GNU(%Y) 모두 epoch 초.
        files_sorted=$(
            find "$src" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null |
            while IFS= read -r -d '' f; do
                ts=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
                printf '%s\t%s\n' "$ts" "$f"
            done |
            sort -rn -k1,1 |
            cut -f2-
        )
        idx=0
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            idx=$((idx + 1))
            [[ "$idx" -le "$MAX_COUNT" ]] && continue
            delete_file "$f"
        done <<< "$files_sorted"
    done
else
    # ── TTL 기반: RETENTION_DAYS 초과 파일 삭제 ──
    # RETENTION_DAYS=0은 "전체 삭제" (mtime 필터 제거)
    if [[ "$RETENTION_DAYS" -eq 0 ]]; then
        mtime_args=()
    else
        mtime_args=(-mtime +"$RETENTION_DAYS")
    fi

    for tier in "${LOCAL_TIERS[@]}"; do
        [[ -n "$TIER_FILTER" && "$tier" != "$TIER_FILTER" ]] && continue
        src="$MEM_DIR/$tier"
        [[ -d "$src" ]] || continue

        while IFS= read -r -d '' f; do
            delete_file "$f"
        done < <(find "$src" -maxdepth 1 -type f -name "*.md" "${mtime_args[@]}" -print0 2>/dev/null)
    done
fi

if [[ -n "$MAX_COUNT" ]]; then
    mode_desc="max-count=${MAX_COUNT}${TIER_FILTER:+, tier=$TIER_FILTER}"
else
    mode_desc="retention=${RETENTION_DAYS}d${TIER_FILTER:+, tier=$TIER_FILTER}"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would prune: $deleted files, promote: $promoted files ($mode_desc)"
else
    echo "pruned: $deleted files, promoted: $promoted files ($mode_desc, failed=$failed)"
fi
[[ "$failed" -gt 0 ]] && exit 2
exit 0
