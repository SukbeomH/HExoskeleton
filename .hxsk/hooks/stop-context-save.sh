#!/usr/bin/env bash
# Hook: Stop — 세션 컨텍스트 저장 (외부 종속성 없음)
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

# 플래그 파일 없으면 스킵
[[ -f "$FLAG_FILE" ]] || exit 0

# 플래그 즉시 삭제 (중복 실행 방지)
rm -f "$FLAG_FILE"

# 변경 정보 수집
MODIFIED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -30)
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
DIFF_STAT=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -5)
RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null)

# 백그라운드 실행
(
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    # ── 1. CURRENT.md 생성 (순수 bash 템플릿, Nemori 서사 형태) ──
    mkdir -p "$(dirname "$CURRENT_MD")"

    # 변경 파일 수 계산
    FILE_COUNT=$(echo "$MODIFIED" | grep -c '.' 2>/dev/null || echo "0")

    # 변경 파일 목록 추출 (상태 코드 제거)
    FILE_LIST=$(echo "$MODIFIED" | sed 's/^[[:space:]MADRC?]*//' | head -10)

    # 최근 커밋에서 작업 내용 추론
    LAST_COMMIT_MSG=$(echo "$RECENT_COMMITS" | head -1 | sed 's/^[a-f0-9]* //')

    # 주요 변경 디렉토리 추출
    MAIN_DIRS=$(echo "$FILE_LIST" | xargs -I{} dirname {} 2>/dev/null | sort -u | head -3 | tr '\n' ', ' | sed 's/,$//')

    # Nemori 서사 형태 템플릿
    cat > "$CURRENT_MD" <<EOF
# Current Session Context

## Session Narrative
> On $TS, the developer was working on the **$BRANCH** branch, modifying $FILE_COUNT files across \`${MAIN_DIRS:-the project}\`. ${LAST_COMMIT_MSG:+The recent work involved: "$LAST_COMMIT_MSG".}

## Context Snapshot
- **Active Task**: ${LAST_COMMIT_MSG:-Ongoing development}
- **Branch**: $BRANCH
- **Files Changed**: $FILE_COUNT
- **Last Updated**: $TS

## Working Files
\`\`\`
${MODIFIED:-No changes detected}
\`\`\`

## Recent Commits
\`\`\`
${RECENT_COMMITS:-No recent commits}
\`\`\`

## Diff Stats
\`\`\`
${DIFF_STAT:-No diff available}
\`\`\`
EOF
    echo "[$TS] CURRENT.md saved (pure bash template)" >> "$LOG_FILE"

    # ── 2. 파일 기반 메모리 저장 (변경 파일이 1개 이상일 때) ──
    # Nemori + A-Mem: 서사 형태 + 확장 필드로 저장
    FILE_COUNT=$(echo "$MODIFIED" | grep -c '.' 2>/dev/null || echo "0")

    # track-modifications.log에서 수정 횟수 집계
    MODIFICATIONS_COUNT=0
    if [[ -f "$TRACK_LOG" ]]; then
        MODIFICATIONS_COUNT=$(wc -l < "$TRACK_LOG" | tr -d ' ')
    fi

    if [[ "$FILE_COUNT" -ge 1 ]]; then
        # CURRENT.md가 있으면 풍부한 content 사용, 없으면 fallback
        if [[ -f "$CURRENT_MD" ]]; then
            MEMORY_CONTENT=$(head -30 "$CURRENT_MD" 2>/dev/null || true)
        else
            MEMORY_CONTENT="On $TS, the developer worked on the $BRANCH branch, modifying $FILE_COUNT files. $(echo "$RECENT_COMMITS" | head -1)"
        fi
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

    # ── 4. track-modifications.log 초기화 ──
    rm -f "$TRACK_LOG"
) &

exit 0
