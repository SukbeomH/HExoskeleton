#!/usr/bin/env bash

# setup-verify.sh — HExoskeleton 설치 상태 자동 검증
# 5개 필수 조건을 독립적으로 검사하고 PASS/FAIL 집계 출력.
#
# Usage: bash .hxsk/scripts/setup-verify.sh
#
# Exit 0: 모든 조건 PASS
# Exit 1: 하나 이상 FAIL
#
# NOTE: set -e 전체 적용 금지 — 각 조건을 독립적으로 검사해야 함

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

pass() {
    printf "  [OK]   %s\n" "$1"
    ((PASS_COUNT++)) || true
}

fail() {
    local msg="$1" hint="$2"
    printf "  [FAIL] %s\n" "$msg"
    printf "         → %s\n" "$hint"
    ((FAIL_COUNT++)) || true
}

# ─────────────────────────────────────────────────────
# Header
# ─────────────────────────────────────────────────────

echo "================================================================"
echo " SETUP-VERIFY — HExoskeleton 설치 검증"
echo "================================================================"
echo ""

# ─────────────────────────────────────────────────────
# 조건 1: .claude/skills/ 에 스킬 5개 이상 존재
# ─────────────────────────────────────────────────────

SKILL_COUNT=0
if [[ -d ".claude/skills" ]]; then
    SKILL_COUNT=$(ls .claude/skills/ 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$SKILL_COUNT" -ge 5 ]]; then
    pass "스킬 ${SKILL_COUNT}개 설치됨 (.claude/skills/)"
else
    fail "스킬 ${SKILL_COUNT}개 — 5개 이상 필요" \
        "setup.md Step 4 재실행: bash .hxsk/scripts/bootstrap.sh"
fi

# ─────────────────────────────────────────────────────
# 조건 2: .claude/agents/ 에 에이전트 파일 존재
# ─────────────────────────────────────────────────────

AGENT_COUNT=0
if [[ -d ".claude/agents" ]]; then
    AGENT_COUNT=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$AGENT_COUNT" -ge 1 ]]; then
    pass "에이전트 ${AGENT_COUNT}개 설치됨 (.claude/agents/)"
else
    fail "에이전트 파일 없음 (.claude/agents/*.md)" \
        "setup.md Step 4 재실행: bash .hxsk/scripts/bootstrap.sh"
fi

# ─────────────────────────────────────────────────────
# 조건 3: .claude/settings.json 에 훅 이벤트 7개 모두 존재
# ─────────────────────────────────────────────────────

HOOK_FAIL=()
SETTINGS_FILE=".claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    for hook in SessionStart PreToolUse PostToolUse PreCompact Stop SubagentStop SessionEnd; do
        if ! grep -q "\"${hook}\"" "$SETTINGS_FILE" 2>/dev/null; then
            HOOK_FAIL+=("$hook")
        fi
    done

    if [[ "${#HOOK_FAIL[@]}" -eq 0 ]]; then
        pass "훅 이벤트 7개 모두 설정됨 (.claude/settings.json)"
    else
        fail "훅 누락: ${HOOK_FAIL[*]}" \
            "setup.md Step 6 재실행 — settings.json에 누락된 훅 추가"
    fi
else
    fail "settings.json 파일 없음 (.claude/settings.json)" \
        "setup.md Step 6 재실행: .claude/settings.json 생성 필요"
fi

# ─────────────────────────────────────────────────────
# 조건 4: .hxsk/memories/ 에 타입별 디렉토리 존재
# ─────────────────────────────────────────────────────

MEM_COUNT=0
if [[ -d ".hxsk/memories" ]]; then
    MEM_COUNT=$(find ".hxsk/memories" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$MEM_COUNT" -ge 1 ]]; then
    pass "메모리 타입 디렉토리 ${MEM_COUNT}개 존재 (.hxsk/memories/)"
else
    fail "메모리 디렉토리 없음 (.hxsk/memories/)" \
        "setup.md Step 3 재실행: bash .hxsk/scripts/bootstrap.sh"
fi

# ─────────────────────────────────────────────────────
# 조건 5: .hxsk/.bootstrap-version 파싱 가능
# ─────────────────────────────────────────────────────

VERSION_FILE=".hxsk/.bootstrap-version"
PARSED_VERSION=""

if [[ -f "$VERSION_FILE" ]]; then
    PARSED_VERSION=$(grep '^version:' "$VERSION_FILE" 2>/dev/null | sed 's/^version: *//' | tr -d '"[:space:]' || true)
fi

if [[ -n "$PARSED_VERSION" ]]; then
    pass "bootstrap 버전 파싱 성공: v${PARSED_VERSION} (.hxsk/.bootstrap-version)"
else
    fail ".bootstrap-version 파싱 실패 또는 파일 없음" \
        "setup.md Step 1 재실행: bash .hxsk/scripts/bootstrap.sh"
fi

# ─────────────────────────────────────────────────────
# 집계 출력
# ─────────────────────────────────────────────────────

echo ""
echo "================================================================"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
    printf " PASS %d/%d | FAIL %d/%d\n" "$PASS_COUNT" "$TOTAL" "$FAIL_COUNT" "$TOTAL"
    echo " RESULT: 모든 조건 통과"
else
    printf " PASS %d/%d | FAIL %d/%d\n" "$PASS_COUNT" "$TOTAL" "$FAIL_COUNT" "$TOTAL"
    echo " RESULT: ${FAIL_COUNT}개 조건 실패 — 위 복구 안내를 참조하세요"
fi
echo "================================================================"

[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1
