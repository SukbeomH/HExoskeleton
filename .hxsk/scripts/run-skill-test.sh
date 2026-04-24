#!/usr/bin/env bash
# run-skill-test.sh — HXSK 스킬 강인성 테스트 러너
# Usage:
#   bash .hxsk/scripts/run-skill-test.sh <skill-name>           # 드라이런 (시나리오 검증)
#   bash .hxsk/scripts/run-skill-test.sh <skill-name> --execute # 실제 LLM 호출
#   bash .hxsk/scripts/run-skill-test.sh --all                  # 전체 시나리오 드라이런
#
# Exit codes: 0=GREEN, 1=RED or FAIL, 2=SKIP (시나리오 없음)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SCENARIOS_DIR="$PROJECT_DIR/.hxsk/tests/scenarios"
REPORTS_DIR="$PROJECT_DIR/.hxsk/reports"
SKILL="${1:-}"
EXECUTE=0
TODAY=$(date +%Y-%m-%d)

# ── 인수 파싱 ─────────────────────────────────────────────────────────────────
if [ "${2:-}" = "--execute" ]; then EXECUTE=1; fi

if [ -z "$SKILL" ]; then
    echo "Usage: $0 <skill-name|--all> [--execute]" >&2
    exit 1
fi

# ── 전체 모드 ────────────────────────────────────────────────────────────────
if [ "$SKILL" = "--all" ]; then
    PASS=0; FAIL=0; SKIP=0
    for dir in "$SCENARIOS_DIR"/*/; do
        s=$(basename "$dir")
        bash "$0" "$s" "${2:-}" 2>/dev/null && PASS=$((PASS+1)) || {
            code=$?
            [ $code -eq 2 ] && SKIP=$((SKIP+1)) || FAIL=$((FAIL+1))
        }
    done
    echo ""
    echo "=== SUMMARY: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ==="
    [ $FAIL -eq 0 ] && exit 0 || exit 1
fi

# ── 시나리오 디렉토리 확인 ───────────────────────────────────────────────────
SCENARIO_DIR="$SCENARIOS_DIR/$SKILL"
if [ ! -d "$SCENARIO_DIR" ]; then
    echo "[SKIP] $SKILL: 시나리오 없음 ($SCENARIO_DIR)"
    exit 2
fi

# 필수 파일 확인
for f in red-prompt.md green-prompt.md red-violations.txt green-compliance.txt; do
    if [ ! -f "$SCENARIO_DIR/$f" ]; then
        echo "[FAIL] $SKILL: $f 누락" >&2
        exit 1
    fi
done

SKILL_MD="$PROJECT_DIR/.hxsk/skills/$SKILL/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
    echo "[FAIL] $SKILL: SKILL.md 없음" >&2
    exit 1
fi

echo "=== SKILL TEST: $SKILL ==="

# ── 드라이런 모드 ────────────────────────────────────────────────────────────
if [ "$EXECUTE" -eq 0 ]; then
    echo "[DRY-RUN] 시나리오 구조 검증"
    RED_VIOLATIONS=$(wc -l < "$SCENARIO_DIR/red-violations.txt")
    GREEN_PATTERNS=$(wc -l < "$SCENARIO_DIR/green-compliance.txt")
    echo "  red-prompt:       $(wc -l < "$SCENARIO_DIR/red-prompt.md") 줄"
    echo "  green-prompt:     $(wc -l < "$SCENARIO_DIR/green-prompt.md") 줄"
    echo "  red-violations:   $RED_VIOLATIONS 패턴"
    echo "  green-compliance: $GREEN_PATTERNS 패턴"
    if [ "$RED_VIOLATIONS" -lt 1 ] || [ "$GREEN_PATTERNS" -lt 1 ]; then
        echo "[FAIL] 패턴 목록이 비어 있음" >&2
        exit 1
    fi
    echo "[PASS] $SKILL 시나리오 구조 유효"
    exit 0
fi

# ── 실행 모드 (--execute) ────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
    echo "[FAIL] claude CLI 없음 — EXECUTE 모드 불가" >&2
    exit 1
fi

mkdir -p "$REPORTS_DIR"
REPORT_FILE="$REPORTS_DIR/skill-test-$TODAY-$SKILL.md"
RED_OUT=$(mktemp)
GREEN_OUT=$(mktemp)
trap "rm -f $RED_OUT $GREEN_OUT" EXIT

# Phase 1: RED — 스킬 없이 실행
echo "[RED] 스킬 없이 압박 시나리오 실행..."
claude --print -p "$(cat "$SCENARIO_DIR/red-prompt.md")" > "$RED_OUT" 2>/dev/null || true

RED_VIOLATED=0
RED_FOUND=""
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if grep -qi "$pattern" "$RED_OUT" 2>/dev/null; then
        RED_VIOLATED=$((RED_VIOLATED+1))
        RED_FOUND="$RED_FOUND\n  - 위반 패턴: $pattern"
    fi
done < "$SCENARIO_DIR/red-violations.txt"

# Phase 2: GREEN — 스킬 임베드 후 실행
echo "[GREEN] 스킬 임베드 후 동일 시나리오 실행..."
GREEN_PROMPT=$(cat "$SCENARIO_DIR/green-prompt.md")
SKILL_CONTENT=$(cat "$SKILL_MD")
FULL_PROMPT="$GREEN_PROMPT

---
## 반드시 다음 스킬을 참조하세요:
$SKILL_CONTENT"
claude --print -p "$FULL_PROMPT" > "$GREEN_OUT" 2>/dev/null || true

GREEN_COMPLIED=0
GREEN_TOTAL=0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    GREEN_TOTAL=$((GREEN_TOTAL+1))
    if grep -qi "$pattern" "$GREEN_OUT" 2>/dev/null; then
        GREEN_COMPLIED=$((GREEN_COMPLIED+1))
    fi
done < "$SCENARIO_DIR/green-compliance.txt"

# ── 판정 ────────────────────────────────────────────────────────────────────
RED_STATUS="PASS (위반 $RED_VIOLATED건 관찰)"
[ "$RED_VIOLATED" -lt 1 ] && RED_STATUS="WARN (위반 관찰 안됨 — false negative 가능)"

GREEN_RATIO="$GREEN_COMPLIED/$GREEN_TOTAL"
VERDICT="GREEN"
[ "$GREEN_COMPLIED" -lt "$GREEN_TOTAL" ] && VERDICT="RED (준수 $GREEN_RATIO)"

# ── 리포트 작성 ──────────────────────────────────────────────────────────────
cat > "$REPORT_FILE" << EOF
# Skill Test Report: $SKILL

- **Date**: $TODAY
- **Mode**: EXECUTE

## RED Phase
$RED_STATUS
$(printf "$RED_FOUND")

## GREEN Phase
준수: $GREEN_COMPLIED / $GREEN_TOTAL 패턴

## Verdict
**$VERDICT**

## RED Output (요약)
\`\`\`
$(head -20 "$RED_OUT")
\`\`\`

## GREEN Output (요약)
\`\`\`
$(head -20 "$GREEN_OUT")
\`\`\`
EOF

echo "[VERDICT] $VERDICT → $REPORT_FILE"
[ "$VERDICT" = "GREEN" ] && exit 0 || exit 1
