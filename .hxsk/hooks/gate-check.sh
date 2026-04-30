#!/bin/bash
# gate-check.sh — HXSK 게이트 조건 검증 유틸리티
# Usage: bash .hxsk/hooks/gate-check.sh {status|gate-0|gate-p3|gate-e0|update <gate>}
# Note: settings.json에 자동 등록되지 않음 — 워크플로우 내에서 수동 호출
#
# 체크 항목:
#   - PLAN 없이 EXECUTE 시도 감지
#   - 파일 소유권 선언 없는 병렬 작업 감지
#   - STATE.md Active Gate 상태 표시

set -euo pipefail

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

# ── STATE.md 필드 업데이트 헬퍼 ─────────────────────────────────────────────
# 단일 필드를 sed로 교체. 고유 필드(current_gate, plan, parent_issue, forge)에만 사용.
_update_state_field() {
    local field="$1"
    local value="$2"
    if ! grep -q "^${field}:" "$STATE_FILE" 2>/dev/null; then
        echo "WARN: field '${field}' not found in STATE.md" >&2
        return 1
    fi
    sed -i.bak "s|^${field}:.*|${field}: ${value}|" "$STATE_FILE" 2>/dev/null
    rm -f "${STATE_FILE}.bak" 2>/dev/null || true
}

# Active Gate 필드 전체 초기화 (GATE-D0)
_reset_active_gate() {
    _update_state_field "plan"         '""'
    _update_state_field "parent_issue" '""'
    _update_state_field "current_gate" '""'
    _update_state_field "forge"        '""'
    sed -i.bak 's|^sub_issues:.*|sub_issues: []|' "$STATE_FILE" 2>/dev/null
    rm -f "${STATE_FILE}.bak" 2>/dev/null || true
}

# Active Dispatcher 필드 초기화 (GATE-D0) — 첫 번째 master/status 행만 교체
_reset_active_dispatcher() {
    sed -i.bak '0,/^master:/{s|^master:.*|master: ""|}' "$STATE_FILE" 2>/dev/null
    sed -i.bak '0,/^status:/{s|^status:.*|status: ""|}' "$STATE_FILE" 2>/dev/null
    rm -f "${STATE_FILE}.bak" 2>/dev/null || true
}

# (구 API 호환 — 내부에서 _update_state_field 호출)
update_state_gate() {
    local gate="${1:-}"
    [ -f "$STATE_FILE" ] || { echo "WARN: STATE.md not found" >&2; return; }
    _update_state_field "current_gate" "\"$gate\"" && \
        echo -e "${GREEN}[STATE]${NC} current_gate → $gate"
}

# ── GATE 통과 기록 ────────────────────────────────────────────────────────────
# Usage: gate-check.sh pass <GATE> [data]
#   GATE-P1 <branch>     plan 브랜치명 + forge 자동 감지
#   GATE-P2 <issue>      parent_issue 번호
#   GATE-P3              current_gate만 갱신
#   GATE-P4 <N,N,...>    sub_issues 목록 ([1, 2, 3])
#   GATE-E0              current_gate + dispatcher master 기록
#   GATE-V0|V1|V2|V3     current_gate만 갱신
#   GATE-D0 [result_doc] Active Gate + Dispatcher 초기화, History 추가
record_gate_pass() {
    local gate="${1:-}"
    local data="${2:-}"

    [ -n "$gate" ] || { echo "Usage: gate-check.sh pass <GATE> [data]" >&2; return 1; }
    [ -f "$STATE_FILE" ] || { echo "ERROR: STATE.md not found at $STATE_FILE" >&2; return 1; }

    case "$gate" in
        GATE-P1)
            _update_state_field "current_gate" "\"$gate\""
            [ -n "$data" ] && _update_state_field "plan" "\"$data\""
            # forge 자동 감지
            if [ -f "$PROJECT_DIR/.hxsk/scripts/forge-detect.sh" ]; then
                local forge
                forge=$(bash "$PROJECT_DIR/.hxsk/scripts/forge-detect.sh" 2>/dev/null \
                    | grep "^FORGE_PLATFORM=" | cut -d= -f2 | tr -d '"' || echo "unknown")
                [ -n "$forge" ] && _update_state_field "forge" "\"$forge\""
            fi
            ;;
        GATE-P2)
            _update_state_field "current_gate" "\"$gate\""
            [ -n "$data" ] && _update_state_field "parent_issue" "\"$data\""
            ;;
        GATE-P4)
            _update_state_field "current_gate" "\"$gate\""
            if [ -n "$data" ]; then
                local formatted
                formatted=$(echo "$data" | tr ',' ' ' | xargs | tr ' ' ',')
                formatted=$(echo "$data" | sed 's/,/, /g')
                sed -i.bak "s|^sub_issues:.*|sub_issues: [$formatted]|" "$STATE_FILE" 2>/dev/null
                rm -f "${STATE_FILE}.bak" 2>/dev/null || true
            fi
            ;;
        GATE-D0)
            # History에 완료 항목 추가 (초기화 전에 현재 값 읽기)
            local today plan_val issue_val
            today=$(date +%Y-%m-%d)
            plan_val=$(_parse_state_field "plan")
            issue_val=$(_parse_state_field "parent_issue")
            local result="${data:-done}"
            # ## History 섹션 주석 다음 줄에 삽입 (BSD/GNU sed 호환 — python3 사용)
            local entry="- $today ${plan_val:-unknown}: #${issue_val:-?} → $result"
            python3 - "$STATE_FILE" "$entry" <<'PYEOF'
import sys
path, entry = sys.argv[1], sys.argv[2]
lines = open(path).readlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if not inserted and line.strip().startswith("<!-- Format:"):
        out.append(entry + "\n")
        inserted = True
open(path, "w").writelines(out)
PYEOF
            # Active Gate + Dispatcher 초기화
            _reset_active_gate
            _reset_active_dispatcher
            ;;
        *)
            # GATE-P3, GATE-E0, GATE-V0~V3: current_gate만 갱신
            _update_state_field "current_gate" "\"$gate\""
            ;;
    esac

    echo -e "${GREEN}[GATE PASS]${NC} $gate 기록 완료 → STATE.md 갱신"
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
        pass)       record_gate_pass "${2:-}" "${3:-}" ;;
        reset)      _reset_active_gate && _reset_active_dispatcher && \
                        echo -e "${GREEN}[STATE]${NC} Active Gate + Dispatcher 초기화 완료" ;;
        *)
            echo "Usage: $0 {gate-0|gate-p3|gate-e0|status|update <gate>|pass <GATE> [data]|reset}" >&2
            exit 1
            ;;
    esac
}

main "$@"
