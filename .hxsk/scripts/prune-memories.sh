#!/usr/bin/env bash
# prune-memories.sh — local-tier 메모리 리텐션 & 아카이브
#
# 사용법:
#   bash .hxsk/scripts/prune-memories.sh [RETENTION_DAYS]
#
# 동작:
#   1. RETENTION_DAYS(기본 30일) 초과 파일을 _archive/YYYY-MM/{tier}/로 이동
#   2. 대상: local-tier (gitignore 대상). shared-tier는 건드리지 않음
#   3. 월별 롤업 파일(YYYY-MM_rollup.md) 생성 — 커밋 해시·파일 수 요약
#
# 멀티 리모트: 아카이브는 gitignored라 각 환경에서 독립적으로 수행.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEM_DIR="$PROJECT_DIR/.hxsk/memories"
ARCHIVE_DIR="$MEM_DIR/_archive"
RETENTION_DAYS="${1:-30}"

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

moved=0
rolled_up_months=""

for tier in "${LOCAL_TIERS[@]}"; do
    src="$MEM_DIR/$tier"
    [[ -d "$src" ]] || continue

    # RETENTION_DAYS 초과 *.md 파일 찾기
    while IFS= read -r -d '' f; do
        base=$(basename "$f")
        # 파일명에서 YYYY-MM 추출 (형식: YYYY-MM-DD_*)
        month="${base:0:7}"
        if [[ ! "$month" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
            # 형식 불일치 시 mtime에서 추출
            month=$(date -r "$f" '+%Y-%m' 2>/dev/null || echo "unknown")
        fi

        dest_dir="$ARCHIVE_DIR/$month/$tier"
        mkdir -p "$dest_dir"
        mv "$f" "$dest_dir/"
        moved=$((moved + 1))

        # 롤업 대상 월 기록
        case " $rolled_up_months " in
            *" $month "*) ;;
            *) rolled_up_months="$rolled_up_months $month" ;;
        esac
    done < <(find "$src" -maxdepth 1 -type f -name "*.md" -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
done

# 월별 롤업 파일 생성 (session-summary만 해당)
for month in $rolled_up_months; do
    [[ -z "$month" || "$month" == "unknown" ]] && continue
    rollup="$ARCHIVE_DIR/$month/${month}_rollup.md"
    summary_dir="$ARCHIVE_DIR/$month/session-summary"
    [[ -d "$summary_dir" ]] || continue

    {
        echo "# Rollup: $month"
        echo ""
        echo "> session-summary 월별 집계 (자동 생성)"
        echo ""
        file_count=$(find "$summary_dir" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        echo "- Sessions: $file_count"
        echo ""
        echo "## Commits mentioned"
        grep -h "^[a-f0-9]\{7,\} " "$summary_dir"/*.md 2>/dev/null \
            | sort -u | head -100
        echo ""
        echo "## Branches"
        grep -h "^- \*\*Branch\*\*:" "$summary_dir"/*.md 2>/dev/null \
            | sort -u
    } > "$rollup"
done

echo "pruned: $moved files (retention=${RETENTION_DAYS}d)"
[[ -n "$rolled_up_months" ]] && echo "rollups:$rolled_up_months"
exit 0
