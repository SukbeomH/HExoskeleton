#!/usr/bin/env bash
# 파일 기반 메모리 검색 (ReWOO 압축 + A-Mem 2-hop)
# Usage: md-recall-memory.sh <query> [project_path] [limit] [mode] [hop]
# grep 기반 .hxsk/memories/**/*.md 검색, 최신순 정렬, limit 적용
# mode: compact (기본, contextual_description만), full (전체 내용)
# hop: 1 (직접 검색만), 2 (related 필드 추적 포함, 기본값)

set -uo pipefail

QUERY="${1:?Usage: md-recall-memory.sh <query> [project_path] [limit] [mode] [hop]}"
PROJECT_PATH="${2:-${CLAUDE_PROJECT_DIR:-.}}"
LIMIT="${3:-5}"
MODE="${4:-compact}"  # compact (ReWOO) 또는 full
HOP="${5:-2}"         # A-Mem: 1=직접만, 2=related 포함

MEMORIES_DIR="$PROJECT_PATH/.hxsk/memories"

# memories 디렉토리 없으면 빈 출력
[ -d "$MEMORIES_DIR" ] || exit 0

# 모든 메모리 파일에서 검색 (파일명 + 내용)
# 최신순 정렬: 파일명이 YYYY-MM-DD 접두사이므로 역순 정렬
RESULTS=$(find "$MEMORIES_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null \
    | sort -r \
    | head -100 \
    | xargs grep -li "$QUERY" 2>/dev/null \
    | head -"$LIMIT" || true)

if [ -z "$RESULTS" ]; then
    # 검색어가 매칭되지 않으면 최근 파일 반환
    RESULTS=$(find "$MEMORIES_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null \
        | sort -r \
        | head -"$LIMIT" || true)
fi

[ -z "$RESULTS" ] && exit 0

# ── A-Mem 2-hop: related 필드 추적 ──
RELATED_FILES=""
if [ "$HOP" = "2" ]; then
    # 1차 결과의 related 필드에서 파일명 추출
    while IFS= read -r filepath; do
        [ -f "$filepath" ] || continue
        # related 섹션에서 파일명 추출 (YAML 배열)
        RELATED=$(sed -n '/^related:/,/^[a-z]/p' "$filepath" 2>/dev/null | grep -E '^\s*-\s*' | sed 's/^\s*-\s*//' || true)
        if [ -n "$RELATED" ]; then
            while IFS= read -r related_ref; do
                [ -z "$related_ref" ] && continue
                # related_ref에서 파일 경로 검색 (여러 타입 디렉토리에서)
                FOUND=$(find "$MEMORIES_DIR" -name "*${related_ref}*" -type f 2>/dev/null | head -1 || true)
                if [ -n "$FOUND" ] && ! echo "$RESULTS" | grep -qF "$FOUND"; then
                    RELATED_FILES="$RELATED_FILES$FOUND"$'\n'
                fi
            done <<< "$RELATED"
        fi
    done <<< "$RESULTS"
fi

# related 파일을 결과에 추가 (limit 내에서)
if [ -n "$RELATED_FILES" ]; then
    CURRENT_COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')
    REMAINING=$((LIMIT - CURRENT_COUNT))
    if [ "$REMAINING" -gt 0 ]; then
        EXTRA=$(echo "$RELATED_FILES" | head -"$REMAINING")
        RESULTS="$RESULTS"$'\n'"$EXTRA"
    fi
fi

# 각 파일에서 메타데이터 추출
while IFS= read -r filepath; do
    [ -f "$filepath" ] || continue

    # frontmatter에서 title 추출
    TITLE=$(sed -n 's/^title: *"\{0,1\}\(.*\)"\{0,1\}$/\1/p' "$filepath" | head -1)
    if [ -z "$TITLE" ]; then
        TITLE=$(basename "$filepath" .md)
    fi

    # frontmatter에서 contextual_description 추출 (A-Mem)
    CTX_DESC=$(sed -n 's/^contextual_description: *"\{0,1\}\(.*\)"\{0,1\}$/\1/p' "$filepath" | head -1)

    # frontmatter에서 type 추출
    TYPE=$(sed -n 's/^type: *\(.*\)$/\1/p' "$filepath" | head -1)

    # 파일명에서 날짜 추출 (YYYY-MM-DD)
    FILENAME=$(basename "$filepath")
    FILE_DATE=$(echo "$FILENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")

    # related 파일 여부 표시
    IS_RELATED=""
    if echo "$RELATED_FILES" | grep -qF "$filepath"; then
        IS_RELATED=" [→related]"
    fi

    if [ "$MODE" = "compact" ]; then
        # ReWOO 압축 모드: title + contextual_description (200자 제한)
        echo "- **${TITLE}** [${TYPE}] ${FILE_DATE}${IS_RELATED}"
        if [ -n "$CTX_DESC" ]; then
            echo "  ${CTX_DESC:0:200}"
        else
            # 1차 fallback: > 블록쿼트 (Nemori 서사 문장)
            NARRATIVE=$(awk '/^---$/{c++;next} c>=2 && /^>/{print; exit}' "$filepath" 2>/dev/null | sed 's/^> //' || true)
            if [ -n "$NARRATIVE" ]; then
                echo "  ${NARRATIVE:0:200}"
            else
                # 2차 fallback: 헤더·빈줄·블록쿼트 제외 첫 줄
                SUMMARY=$(awk '/^---$/{c++;next} c>=2 && /^[^#>]/ && NF{print; exit}' "$filepath" 2>/dev/null || true)
                [ -n "$SUMMARY" ] && echo "  ${SUMMARY:0:150}..."
            fi
        fi
    else
        # full 모드: 전체 내용 포함
        echo "### ${TITLE} [${TYPE}]"
        echo "📁 \`${filepath}\`"
        echo ""
        # frontmatter 이후 내용
        awk '/^---$/{c++;next} c>=2{print}' "$filepath" 2>/dev/null | head -20
        echo ""
    fi
done <<< "$RESULTS"
