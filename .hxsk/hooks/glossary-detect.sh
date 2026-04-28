#!/usr/bin/env bash
# Glossary 후보 감지 + 힌트 주입 (UserPromptSubmit 훅 용도)
# Usage: echo "사용자 메시지" | bash glossary-detect.sh
#        또는: bash glossary-detect.sh "사용자 메시지"
# stdout: 힌트 메시지 (매칭된 경우) + 등록 권유 (임계치 초과 시)
# HXSK_GLOSSARY_DISABLE=1 로 완전 비활성화 가능

set -euo pipefail

# 한글 정규식이 바이트 범위로 해석되지 않도록 UTF-8 강제
export LC_ALL=en_US.UTF-8 2>/dev/null || export LC_ALL=C.UTF-8 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 훅은 프로젝트 루트 CWD에서 실행됨. SCRIPT_DIR/../.. 또는 git root 사용.
PROJECT_PATH="${HXSK_PROJECT_DIR:-$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || pwd)}"
GLOSSARY="${PROJECT_PATH}/.hxsk/GLOSSARY.md"
CANDIDATES="${PROJECT_PATH}/.hxsk/.glossary-candidates.tsv"
THRESHOLD="${HXSK_GLOSSARY_THRESHOLD:-3}"

# 비활성화 우회
[[ "${HXSK_GLOSSARY_DISABLE:-0}" == "1" ]] && exit 0

# GLOSSARY.md 없으면 조용히 종료 (사용자 흐름 비차단)
[[ ! -f "$GLOSSARY" ]] && exit 0

# 입력 수신 (stdin 또는 $1)
if [[ -n "${1:-}" ]]; then
  INPUT="$1"
elif [[ ! -t 0 ]]; then
  INPUT="$(cat)"
else
  exit 0
fi

[[ -z "$INPUT" ]] && exit 0

# ── 1. GLOSSARY에서 canonical + aliases 목록 구성 ────────────────────────────
# canonical: GLOSSARY.md 표에서 추출 (헤더·구분선 제외)
# grep -v "^|---" 로 |---|---|---| 구분선 제거, grep -v "canonical" 로 헤더 제거
CANONICALS=$(grep "^|" "$GLOSSARY" 2>/dev/null \
  | grep -v "^|---" \
  | grep -v "canonical" \
  | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' \
  | grep -v "^$" || true)

# aliases: term-definition/*.md의 aliases 블록만 추출 (lazy lookup)
# awk로 frontmatter aliases: 섹션만 파싱 (disambiguates_from 등 혼입 방지)
TERM_DIR="${PROJECT_PATH}/.hxsk/memories/term-definition"
ALIASES=""
if [[ -d "$TERM_DIR" ]]; then
  ALIASES=$(awk '
    /^aliases:/ { in_aliases=1; next }
    in_aliases && /^  - / { gsub(/^  - /, ""); gsub(/["\x27]/, ""); print; next }
    in_aliases && !/^  - / { in_aliases=0 }
  ' "$TERM_DIR"/*.md 2>/dev/null | grep -v "^$" || true)
fi

ALL_KNOWN=$(printf "%s\n%s" "$CANONICALS" "$ALIASES" | grep -v "^$" | sort -u)

# ── 2. 입력에서 토큰 추출 ───────────────────────────────────────────────────
# 한글 명사구(2자+), 영문 PascalCase/camelCase, 영문 2자+ 알파벳 연속
TOKENS=$(printf "%s" "$INPUT" \
  | grep -oE '[가-힣]{2,}|[A-Z][a-zA-Z]{1,}|[a-z]{3,}' \
  | sort -u || true)

# ── 3. 매칭: 알려진 용어 → 힌트 출력 ──────────────────────────────────────
while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  # 대소문자 무시 비교
  MATCH=$(echo "$ALL_KNOWN" | grep -ix "$token" 2>/dev/null | head -1 || true)
  if [[ -n "$MATCH" ]]; then
    # canonical 찾기 (직접 매칭)
    CANON=$(echo "$CANONICALS" | grep -ix "$MATCH" 2>/dev/null | head -1 || true)
    if [[ -z "$CANON" ]]; then
      # alias → canonical 역방향 탐색 (frontmatter canonical 필드 직접 추출)
      FILE=$(grep -rl "  - \"${MATCH}\"\|  - '${MATCH}'\|  - ${MATCH}$" "$TERM_DIR" 2>/dev/null | head -1 || true)
      if [[ -n "$FILE" ]]; then
        CANON=$(grep -m1 "^canonical:" "$FILE" 2>/dev/null | sed 's/^canonical: *//' | tr -d '"'"'" || true)
      fi
    fi
    [[ -z "$CANON" ]] && CANON="$MATCH"
    CTX=$(grep "^| ${CANON} " "$GLOSSARY" 2>/dev/null | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}' | head -1 || echo "hxsk")
    echo "💡 '${token}' → HXSK ${CANON} (context: ${CTX:-hxsk}) 의미로 해석합니다."
  fi
done <<< "$TOKENS"

# ── 4. 미등록 토큰 → candidates.tsv 누적 ──────────────────────────────────
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# candidates.tsv 헤더 초기화 (없으면)
if [[ ! -f "$CANDIDATES" ]]; then
  echo -e "term\tcount\tfirst_seen\tlast_seen" > "$CANDIDATES"
fi

while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  # 이미 알려진 용어 스킵
  KNOWN=$(echo "$ALL_KNOWN" | grep -ix "$token" 2>/dev/null | head -1 || true)
  [[ -n "$KNOWN" ]] && continue
  # 너무 짧거나 일반 stop word 스킵 (3자 미만 영문)
  [[ ${#token} -lt 2 ]] && continue

  # TSV에서 기존 항목 찾기 (awk로 탭 구분 exact match)
  ROW=$(awk -F'\t' -v t="$token" 'NR>1 && $1==t {print; exit}' "$CANDIDATES" 2>/dev/null || true)
  if [[ -n "$ROW" ]]; then
    OLD_COUNT=$(echo "$ROW" | awk -F'\t' '{print $2}')
    FIRST=$(echo "$ROW" | awk -F'\t' '{print $3}')
    NEW_COUNT=$((OLD_COUNT + 1))
    # awk로 해당 행만 교체 (헤더 보존)
    awk -F'\t' -v t="$token" -v c="$NEW_COUNT" -v f="$FIRST" -v l="$NOW" \
      'BEGIN{OFS="\t"} NR==1 || $1!=t {print} $1==t {print t, c, f, l}' \
      "$CANDIDATES" > "${CANDIDATES}.tmp" && mv "${CANDIDATES}.tmp" "$CANDIDATES"
    if [[ "$NEW_COUNT" -ge "$THRESHOLD" ]]; then
      echo "📝 '${token}' ${NEW_COUNT}회 감지. \`/define ${token}\` 으로 등록을 권장합니다."
    fi
  else
    printf "%s\t%d\t%s\t%s\n" "$token" "1" "$NOW" "$NOW" >> "$CANDIDATES"
  fi
done <<< "$TOKENS"

exit 0
