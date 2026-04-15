#!/usr/bin/env bash
# prune-memories.sh — local-tier 메모리 리텐션 정리
#
# 사용법:
#   bash .hxsk/scripts/prune-memories.sh [RETENTION_DAYS] [--dry-run]
#
# 예시:
#   bash prune-memories.sh                # 7일 초과 파일 삭제
#   bash prune-memories.sh 30             # 30일 초과 파일 삭제
#   bash prune-memories.sh --dry-run      # 삭제 대상만 출력 (실행 X)
#   bash prune-memories.sh 3 --dry-run    # 3일 기준 dry-run
#
# 동작:
#   1. RETENTION_DAYS(기본 7일) 초과 파일을 직접 삭제
#   2. 대상: local-tier (gitignore 대상). shared-tier는 건드리지 않음
#   3. git log/PR이 실행 이력을 대체하므로 _retained 이동 불필요
#
# 멀티 리모트: gitignored 파일이므로 각 환경에서 독립적으로 수행.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEM_DIR="$PROJECT_DIR/.hxsk/memories"
RETENTION_DAYS=7
DRY_RUN=0
RETENTION_DAYS_SET=0

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
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --help|-h)
            print_help
            exit 0
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
                echo "Usage: $0 [RETENTION_DAYS] [--dry-run]" >&2
                exit 1
            fi
            ;;
    esac
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

for tier in "${LOCAL_TIERS[@]}"; do
    src="$MEM_DIR/$tier"
    [[ -d "$src" ]] || continue

    # RETENTION_DAYS 초과 *.md 파일 찾기 → 직접 삭제 (git log/PR이 이력 보존)
    while IFS= read -r -d '' f; do
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "[dry-run] would delete: $f"
        else
            rm -f "$f"
        fi
        deleted=$((deleted + 1))
    done < <(find "$src" -maxdepth 1 -type f -name "*.md" -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would prune: $deleted files (retention=${RETENTION_DAYS}d)"
else
    echo "pruned: $deleted files (retention=${RETENTION_DAYS}d)"
fi
exit 0
