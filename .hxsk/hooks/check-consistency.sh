#!/usr/bin/env bash
# check-consistency.sh — 코드/문서/스킬/에이전트/훅 간 정합성 자동 검증
#
# Usage: bash .hxsk/hooks/check-consistency.sh [--fix]
#   --fix: 자동 수정 가능한 항목 수정 (현재: 미구현, 리포트만)
#
# Exit 0: 모든 검사 통과
# Exit 1: 불일치 발견

set -o errexit
set -o nounset
set -o pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
FAIL=0
WARN=0
PASS=0

# ─── Helpers ──────────────────────────────────────

pass() {
    printf "  [PASS] %s\n" "$1"
    ((PASS++)) || true
}

fail() {
    printf "  [FAIL] %s\n" "$1"
    ((FAIL++)) || true
}

warn() {
    printf "  [WARN] %s\n" "$1"
    ((WARN++)) || true
}

# ─── 1. INDEX vs 실제 파일 ────────────────────────

echo "=== INDEX vs 실제 파일 ==="

# Skills
if [[ -f "$HXSK_DIR/skills/INDEX.md" ]]; then
    SKILL_DIRS=$(find "$HXSK_DIR/skills" -name "SKILL.md" -exec dirname {} \; 2>/dev/null | while read -r d; do basename "$d"; done | sort)
    # INDEX 테이블에서 첫 번째 컬럼(스킬명) 추출: | name | desc | path |
    INDEX_SKILLS=$(awk -F'|' '/^\|/ && !/Skill/ && !/---/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); if($2 != "") print $2}' "$HXSK_DIR/skills/INDEX.md" 2>/dev/null | sort)
    SKILL_COUNT=$(echo "$SKILL_DIRS" | grep -c . || true)

    MISSING_IN_INDEX=$(comm -23 <(echo "$SKILL_DIRS") <(echo "$INDEX_SKILLS") 2>/dev/null | tr '\n' ' ')
    MISSING_IN_DIR=$(comm -13 <(echo "$SKILL_DIRS") <(echo "$INDEX_SKILLS") 2>/dev/null | tr '\n' ' ')

    if [[ -n "${MISSING_IN_INDEX// /}" ]]; then
        fail "Skills INDEX 누락: $MISSING_IN_INDEX"
    elif [[ -n "${MISSING_IN_DIR// /}" ]]; then
        fail "Skills 디렉토리 누락: $MISSING_IN_DIR"
    else
        pass "Skills INDEX ↔ 디렉토리 일치 ($SKILL_COUNT)"
    fi
fi

# Agents
if [[ -f "$HXSK_DIR/agents/INDEX.md" ]]; then
    AGENT_FILES=$(find "$HXSK_DIR/agents" -name "*.md" -not -name "INDEX.md" 2>/dev/null | while read -r f; do basename "$f" .md; done | sort)
    INDEX_AGENTS=$(awk -F'|' '/^\|/ && !/Agent/ && !/---/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); if($2 != "") print $2}' "$HXSK_DIR/agents/INDEX.md" 2>/dev/null | sort)
    AGENT_COUNT=$(echo "$AGENT_FILES" | grep -c . || true)

    MISSING_IN_INDEX=$(comm -23 <(echo "$AGENT_FILES") <(echo "$INDEX_AGENTS") 2>/dev/null | tr '\n' ' ')
    MISSING_IN_DIR=$(comm -13 <(echo "$AGENT_FILES") <(echo "$INDEX_AGENTS") 2>/dev/null | tr '\n' ' ')

    if [[ -n "${MISSING_IN_INDEX// /}" ]]; then
        fail "Agents INDEX 누락: $MISSING_IN_INDEX"
    elif [[ -n "${MISSING_IN_DIR// /}" ]]; then
        fail "Agents 파일 누락: $MISSING_IN_DIR"
    else
        pass "Agents INDEX ↔ 파일 일치 ($AGENT_COUNT)"
    fi
fi

# Hooks
if [[ -f "$HXSK_DIR/hooks/INDEX.md" ]]; then
    HOOK_FILES=$(find "$HXSK_DIR/hooks" \( -name "*.sh" -o -name "*.py" \) -exec basename {} \; 2>/dev/null | sort)
    HOOK_COUNT=$(echo "$HOOK_FILES" | grep -c . || true)
    pass "Hooks 파일 ($HOOK_COUNT)"
fi

# ─── 2. settings.json 훅 경로 검증 ───────────────

echo ""
echo "=== settings.json 훅 경로 ==="

SETTINGS="$PROJECT_DIR/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
    # command 필드에서 경로 추출 (macOS 호환)
    ALL_VALID=true
    HOOK_PATH_COUNT=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        path=$(echo "$line" | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/".*//' | tr -d '[:space:]')
        [[ -z "$path" ]] && continue
        ((HOOK_PATH_COUNT++)) || true
        if [[ ! -f "$PROJECT_DIR/$path" ]]; then
            fail "settings.json 경로 미존재: $path"
            ALL_VALID=false
        fi
    done < <(grep '"command"' "$SETTINGS")
    if $ALL_VALID; then
        pass "settings.json 훅 경로 모두 유효 ($HOOK_PATH_COUNT)"
    fi

    # $CLAUDE_PROJECT_DIR 잔존 확인
    if grep -q 'CLAUDE_PROJECT_DIR' "$SETTINGS"; then
        fail "settings.json에 \$CLAUDE_PROJECT_DIR 잔존 — 상대 경로 사용 필요"
    else
        pass "settings.json에 \$CLAUDE_PROJECT_DIR 없음"
    fi

    # 이벤트 수 확인 (최소 7개)
    EVENT_COUNT=$(grep -oE '"(SessionStart|PreToolUse|PostToolUse|PreCompact|Stop|SubagentStop|SessionEnd)"' "$SETTINGS" | sort -u | wc -l | tr -d ' ' || echo "0")
    if [[ "$EVENT_COUNT" -ge 7 ]]; then
        pass "settings.json hook events: $EVENT_COUNT"
    else
        fail "settings.json hook events: $EVENT_COUNT (need 7)"
    fi
else
    warn "settings.json not found (Claude Code only)"
fi

# ─── 3. 스킬/에이전트 내 스크립트 참조 검증 ──────

echo ""
echo "=== 스크립트 참조 검증 ==="

BROKEN_REFS=0
# 스킬/에이전트에서 bash 명령으로 참조하는 스크립트 경로 추출
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    FILE=$(echo "$line" | cut -d: -f1)
    # bash .hxsk/... 패턴 추출 (macOS 호환)
    SCRIPT=$(echo "$line" | sed -n 's/.*bash \(\.hxsk\/[^ `"]*\).*/\1/p')
    [[ -z "$SCRIPT" ]] && continue
    if [[ ! -f "$PROJECT_DIR/$SCRIPT" ]]; then
        fail "$FILE -> $SCRIPT not found"
        ((BROKEN_REFS++)) || true
    fi
done < <(grep -rn 'bash \.hxsk/' "$HXSK_DIR/skills/" "$HXSK_DIR/agents/" 2>/dev/null || true)

if [[ "$BROKEN_REFS" -eq 0 ]]; then
    pass "스킬/에이전트 내 스크립트 참조 모두 유효"
fi

# ─── 4. 버전 일관성 ──────────────────────────────

echo ""
echo "=== 버전 일관성 ==="

VERSION_FILE="$HXSK_DIR/.bootstrap-version"
if [[ -f "$VERSION_FILE" ]]; then
    FILE_VER=$(grep '^version:' "$VERSION_FILE" | sed 's/^version: *//' | tr -d '"[:space:]')

    # bootstrap.sh 내 BOOTSTRAP_VERSION
    SCRIPT_VER=$(grep 'BOOTSTRAP_VERSION=' "$HXSK_DIR/scripts/bootstrap.sh" 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || true)

    if [[ "$FILE_VER" == "$SCRIPT_VER" ]]; then
        pass "버전 일치: bootstrap-version=$FILE_VER, bootstrap.sh=$SCRIPT_VER"
    else
        fail "버전 불일치: bootstrap-version=$FILE_VER, bootstrap.sh=$SCRIPT_VER"
    fi
else
    warn "bootstrap-version 파일 미존재"
fi

# ─── 5. 문서 링크 검증 (주요 파일만) ─────────────

echo ""
echo "=== 문서 링크 검증 ==="

BROKEN_LINKS=0
for DOC in "$PROJECT_DIR/README.md" "$PROJECT_DIR/llms.txt" "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/AGENTS.md"; do
    [[ ! -f "$DOC" ]] && continue
    BASENAME=$(basename "$DOC")
    # 마크다운 링크에서 상대 경로 추출 (http 제외)
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        [[ "$link" == http* ]] && continue
        [[ "$link" == "#"* ]] && continue
        # 앵커 제거
        CLEAN_LINK=$(echo "$link" | sed 's/#.*//')
        [[ -z "$CLEAN_LINK" ]] && continue
        if [[ ! -e "$PROJECT_DIR/$CLEAN_LINK" ]]; then
            fail "$BASENAME → $CLEAN_LINK 미존재"
            ((BROKEN_LINKS++)) || true
        fi
    done < <(grep -oE '\]\([^)]+\)' "$DOC" 2>/dev/null | sed 's/^\]//;s/^(//;s/)$//' | grep -v '^http' | grep -v '^#' || true)
done

if [[ "$BROKEN_LINKS" -eq 0 ]]; then
    pass "주요 문서 링크 모두 유효"
fi

# ─── 6. 컴포넌트 카운트 검증 ─────────────────────

echo ""
echo "=== 컴포넌트 카운트 ==="

if [[ -f "$VERSION_FILE" ]]; then
    REC_SKILLS=$(grep 'skills:' "$VERSION_FILE" | sed 's/.*skills: *//' | tr -d ' ')
    REC_AGENTS=$(grep 'agents:' "$VERSION_FILE" | sed 's/.*agents: *//' | tr -d ' ')
    REC_HOOKS=$(grep 'hooks:' "$VERSION_FILE" | sed 's/.*hooks: *//' | tr -d ' ')

    mkdir -p "$HXSK_DIR/skills" "$HXSK_DIR/agents" "$HXSK_DIR/hooks"
    ACT_SKILLS=$(find "$HXSK_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    ACT_AGENTS=$(find "$HXSK_DIR/agents" -name "*.md" -not -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')
    ACT_HOOKS=$(find "$HXSK_DIR/hooks" \( -name "*.sh" -o -name "*.py" \) 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$REC_SKILLS" == "$ACT_SKILLS" ]]; then
        pass "Skills: $ACT_SKILLS (기록 일치)"
    else
        fail "Skills: 실제 $ACT_SKILLS vs 기록 $REC_SKILLS"
    fi

    if [[ "$REC_AGENTS" == "$ACT_AGENTS" ]]; then
        pass "Agents: $ACT_AGENTS (기록 일치)"
    else
        fail "Agents: 실제 $ACT_AGENTS vs 기록 $REC_AGENTS"
    fi

    if [[ "$REC_HOOKS" == "$ACT_HOOKS" ]]; then
        pass "Hooks: $ACT_HOOKS (기록 일치)"
    else
        fail "Hooks: 실제 $ACT_HOOKS vs 기록 $REC_HOOKS"
    fi
fi

# ─── Summary ──────────────────────────────────────

echo ""
echo "================================================================"
printf " CONSISTENCY CHECK  |  PASS: %d  FAIL: %d  WARN: %d\n" "$PASS" "$FAIL" "$WARN"
if [[ "$FAIL" -gt 0 ]]; then
    echo " RESULT: FAILED — ${FAIL} inconsistency(ies) found"
    echo "================================================================"
    exit 1
else
    echo " RESULT: ALL CONSISTENT"
    echo "================================================================"
    exit 0
fi
