#!/bin/bash
# gate-check.sh — HXSK 게이트 조건 검증 유틸리티
# Usage: bash .hxsk/hooks/gate-check.sh {status|gate-0|gate-p3|gate-e0|update <gate>}
# Note: settings.json에 자동 등록되지 않음 — 워크플로우 내에서 수동 호출
#
# 체크 항목:
#   - PLAN 없이 EXECUTE 시도 감지
#   - 파일 소유권 선언 없는 병렬 작업 감지
#   - STATE.md Active Gate 상태 표시

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
GATES_FILE="$HXSK_DIR/workflow/GATES.md"
STATE_FILE="$HXSK_DIR/STATE.md"

# ── 컬러 출력 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 게이트 파일 존재 확인 ────────────────────────────────────────────────────
check_gates_file() {
    if [ ! -f "$GATES_FILE" ]; then
        echo "WARN: GATES.md not found at $GATES_FILE" >&2
        return 1
    fi
    return 0
}

# ── STATE.md에서 현재 게이트 상태 읽기 ──────────────────────────────────────
# YAML "field: value  # comment" → value만 추출
_parse_state_field() {
    local field="$1"
    if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
    grep "^${field}:" "$STATE_FILE" 2>/dev/null \
        | head -1 \
        | sed "s/^${field}:[[:space:]]*//" \
        | sed 's/[[:space:]]*#.*//' \
        | tr -d '"' \
        | tr -d "'" \
        | tr -d ' '
}

get_current_gate() { _parse_state_field "current_gate"; }
get_plan_branch()   { _parse_state_field "plan"; }
get_parent_issue()  { _parse_state_field "parent_issue"; }

# ── GATE-0: SPEC.md 존재 및 필수 섹션 확인 ───────────────────────────────────
check_gate_0() {
    local SPEC_FILE="$PROJECT_DIR/SPEC.md"

    if [ ! -f "$SPEC_FILE" ]; then
        echo -e "${RED}[GATE-0 FAIL]${NC} SPEC.md가 없습니다. SPEC.md를 먼저 생성하세요." >&2
        return 1
    fi

    if ! grep -q "^## Goals" "$SPEC_FILE" 2>/dev/null; then
        echo -e "${RED}[GATE-0 FAIL]${NC} SPEC.md에 '## Goals' 섹션이 없습니다." >&2
        return 1
    fi

    if ! grep -q "^## Scope" "$SPEC_FILE" 2>/dev/null; then
        echo -e "${RED}[GATE-0 FAIL]${NC} SPEC.md에 '## Scope' 섹션이 없습니다." >&2
        return 1
    fi

    echo -e "${GREEN}[GATE-0 PASS]${NC} SPEC.md 검증 완료."
    return 0
}

# ── GATE-P3: PLAN.md 태스크 분할 확인 ────────────────────────────────────────
check_gate_p3() {
    local PLAN_FILE="$PROJECT_DIR/PLAN.md"

    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}[GATE-P3 FAIL]${NC} PLAN.md가 없습니다." >&2
        return 1
    fi

    local TASK_COUNT
    TASK_COUNT=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || echo 0)

    if [ "$TASK_COUNT" -lt 1 ]; then
        echo -e "${RED}[GATE-P3 FAIL]${NC} PLAN.md에 '- [ ]' 형식 태스크가 없습니다." >&2
        return 1
    fi

    # files: 소유권 선언 확인
    local FILES_COUNT
    FILES_COUNT=$(grep -c 'files:' "$PLAN_FILE" 2>/dev/null || echo 0)

    if [ "$FILES_COUNT" -lt 1 ]; then
        echo -e "${YELLOW}[GATE-P3 WARN]${NC} PLAN.md 태스크에 'files:' 필드가 없습니다. 파일 소유권 선언을 추가하세요." >&2
    fi

    echo -e "${GREEN}[GATE-P3 PASS]${NC} PLAN.md 태스크 $TASK_COUNT개 확인."
    return 0
}

# ── GATE-E0: EXECUTE 진입 전 전체 확인 ───────────────────────────────────────
check_gate_e0() {
    local ERRORS=0

    # P3 통과 여부
    check_gate_p3 || ERRORS=$((ERRORS + 1))

    # STATE.md sub_issues 확인
    if [ -f "$STATE_FILE" ]; then
        local SUB_ISSUES
        SUB_ISSUES=$(grep 'sub_issues:' "$STATE_FILE" 2>/dev/null | head -1)
        if echo "$SUB_ISSUES" | grep -q '\[\]'; then
            echo -e "${YELLOW}[GATE-E0 WARN]${NC} STATE.md sub_issues 목록이 비어있습니다. 하위 이슈 생성 후 진행하세요." >&2
        fi
    fi

    if [ "$ERRORS" -gt 0 ]; then
        echo -e "${RED}[GATE-E0 FAIL]${NC} EXECUTE 진입 조건 미충족." >&2
        return 1
    fi

    echo -e "${GREEN}[GATE-E0 PASS]${NC} EXECUTE 진입 가능."
    return 0
}

# ── 현재 상태 요약 출력 ───────────────────────────────────────────────────────
show_status() {
    local CURRENT_GATE
    local PLAN_BRANCH
    local PARENT_ISSUE

    CURRENT_GATE=$(get_current_gate)
    PLAN_BRANCH=$(get_plan_branch)
    PARENT_ISSUE=$(get_parent_issue)

    echo -e "${CYAN}=== HXSK Gate Status ===${NC}"
    echo -e "Current Gate : ${CURRENT_GATE:-"(not set)"}"
    echo -e "Plan Branch  : ${PLAN_BRANCH:-"(not set)"}"
    echo -e "Parent Issue : ${PARENT_ISSUE:-"(not set)"}"

    if check_gates_file 2>/dev/null; then
        echo -e "GATES.md     : ${GREEN}OK${NC}"
    else
        echo -e "GATES.md     : ${RED}MISSING${NC}"
    fi
}

# ── STATE.md 업데이트 헬퍼 ───────────────────────────────────────────────────
# Usage: update_state_gate <gate_name>
update_state_gate() {
    local gate="$1"

    if [ ! -f "$STATE_FILE" ]; then
        echo "WARN: STATE.md not found, skipping update" >&2
        return
    fi

    # current_gate 값 업데이트 (sed in-place), 실제 변경 여부 확인
    local before
    before=$(grep "^current_gate:" "$STATE_FILE" 2>/dev/null | head -1 || echo "")

    sed -i.bak "s/^current_gate:.*/current_gate: \"$gate\"/" "$STATE_FILE" 2>/dev/null || {
        echo "ERROR: failed to update STATE.md" >&2
        rm -f "${STATE_FILE}.bak" 2>/dev/null
        return 1
    }
    rm -f "${STATE_FILE}.bak" 2>/dev/null || true

    local after
    after=$(grep "^current_gate:" "$STATE_FILE" 2>/dev/null | head -1 || echo "")

    if [ "$before" = "$after" ] && ! echo "$after" | grep -q "\"$gate\""; then
        echo "WARN: STATE.md current_gate field not found or unchanged" >&2
        return 1
    fi

    echo -e "${GREEN}[STATE]${NC} current_gate → $gate"
}

# ── 메인 ─────────────────────────────────────────────────────────────────────
main() {
    local CMD="${1:-status}"

    case "$CMD" in
        gate-0)     check_gate_0 ;;
        gate-p3)    check_gate_p3 ;;
        gate-e0)    check_gate_e0 ;;
        status)     show_status ;;
        update)     update_state_gate "${2:-}" ;;
        *)
            echo "Usage: $0 {gate-0|gate-p3|gate-e0|status|update <gate>}" >&2
            exit 1
            ;;
    esac
}

main "$@"
