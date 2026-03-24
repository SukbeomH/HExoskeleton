#!/usr/bin/env bash
# 파일 기반 메모리 저장 (A-Mem 확장)
# Usage: md-store-memory.sh <title> <content> [tags] [type] [keywords] [contextual_desc] [related]
# 출력: .hxsk/memories/{type}/{YYYY-MM-DD}_{slug}.md (YAML frontmatter + markdown)
# A-Mem 연구 기반: keywords, contextual_description, related 필드 지원

set -uo pipefail

TITLE="${1:?Usage: md-store-memory.sh <title> <content> [tags] [type] [keywords] [contextual_desc] [related]}"
CONTENT="${2:?Missing content}"
TAGS="${3:-general,auto}"
TYPE="${4:-general}"
KEYWORDS="${5:-}"          # LLM 생성 검색 키워드 (쉼표 구분)
CONTEXTUAL_DESC="${6:-}"   # 1줄 요약 (검색 결과 압축용)
RELATED="${7:-}"           # 관련 메모리 파일명 배열 (쉼표 구분)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MEMORIES_DIR="$PROJECT_DIR/.hxsk/memories"

# Type 디렉토리 검증 (없으면 general 폴백)
TYPE_DIR="$MEMORIES_DIR/$TYPE"
if [ ! -d "$TYPE_DIR" ]; then
    TYPE_DIR="$MEMORIES_DIR/general"
    mkdir -p "$TYPE_DIR"
fi

# 파일명 생성: YYYY-MM-DD_slug.md
DATE_PREFIX=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-60)
FILENAME="${DATE_PREFIX}_${SLUG}.md"
FILEPATH="$TYPE_DIR/$FILENAME"

# ── Nemori Predict-Calibrate: 중복 메모리 방지 ──
# 동일 title 또는 유사 keywords가 있으면 스킵 또는 related 링크만 추가
DUPLICATE_CHECK=""
if [ -d "$MEMORIES_DIR" ]; then
    # 1. 동일 title 검색 (오늘 날짜 내)
    DUPLICATE_CHECK=$(find "$TYPE_DIR" -name "${DATE_PREFIX}_*.md" 2>/dev/null | head -20 | \
        xargs grep -li "title: \"$TITLE\"" 2>/dev/null | head -1 || true)

    # 2. 동일 slug 파일이 이미 있으면 (같은 제목)
    if [ -z "$DUPLICATE_CHECK" ] && [ -f "$FILEPATH" ]; then
        DUPLICATE_CHECK="$FILEPATH"
    fi
fi

# 중복 발견 시: 스킵하고 기존 파일 경로 반환
if [ -n "$DUPLICATE_CHECK" ]; then
    echo "[SKIP:DUPLICATE] $DUPLICATE_CHECK"
    exit 0
fi

# ── Predict-Calibrate: keyword similarity warning (cross-day, cross-type) ──
if [ -n "$KEYWORDS" ]; then
    _MATCH_COUNT=0
    _SIMILAR_FILE=""
    for _KW in $(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | head -3); do
        [ -z "$_KW" ] && continue
        _FOUND=$(grep -rl "  - $_KW" "$MEMORIES_DIR" 2>/dev/null | grep -v "$FILEPATH" | head -1 || true)
        if [ -n "$_FOUND" ]; then
            _MATCH_COUNT=$((_MATCH_COUNT + 1))
            [ -z "$_SIMILAR_FILE" ] && _SIMILAR_FILE="$_FOUND"
        fi
    done
    if [ "$_MATCH_COUNT" -ge 2 ]; then
        echo "[WARN:SIMILAR] $_SIMILAR_FILE" >&2
    fi
fi

# 일반 중복 방지: 같은 날짜+슬러그면 타임스탬프 추가
if [ -f "$FILEPATH" ]; then
    TIME_SUFFIX=$(date +%H%M%S)
    FILENAME="${DATE_PREFIX}_${SLUG}_${TIME_SUFFIX}.md"
    FILEPATH="$TYPE_DIR/$FILENAME"
fi

# YAML frontmatter + markdown 작성
ISO_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# tags를 YAML 배열로 변환
YAML_TAGS=$(echo "$TAGS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed '/^$/d' | sed 's/^/  - /')

# keywords를 YAML 배열로 변환 (A-Mem)
YAML_KEYWORDS=""
if [ -n "$KEYWORDS" ]; then
    YAML_KEYWORDS=$(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed '/^$/d' | sed 's/^/  - /')
fi

# related를 YAML 배열로 변환 (A-Mem Link)
YAML_RELATED=""
if [ -n "$RELATED" ]; then
    YAML_RELATED=$(echo "$RELATED" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed '/^$/d' | sed 's/^/  - /')
fi

# contextual_description 자동 생성 (비어있으면 content 첫 100자)
if [ -z "$CONTEXTUAL_DESC" ]; then
    CONTEXTUAL_DESC=$(echo "$CONTENT" | head -1 | cut -c1-100)
fi

# YAML frontmatter 생성
{
    echo "---"
    echo "title: \"$TITLE\""
    echo "tags:"
    echo "$YAML_TAGS"
    echo "type: $TYPE"
    echo "created: $ISO_DATE"
    # A-Mem 확장 필드
    echo "contextual_description: \"$CONTEXTUAL_DESC\""
    if [ -n "$YAML_KEYWORDS" ]; then
        echo "keywords:"
        echo "$YAML_KEYWORDS"
    fi
    if [ -n "$YAML_RELATED" ]; then
        echo "related:"
        echo "$YAML_RELATED"
    fi
    echo "---"
    echo ""
    echo "## $TITLE"
    echo ""
    echo "$CONTENT"
} > "$FILEPATH"

echo "$FILEPATH"
