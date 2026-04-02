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

# ─── 7. Agent frontmatter 필수 필드 ───────────────

echo ""
echo "=== Agent/Skill frontmatter ==="

MISSING_FM=0
# Agent: description, tools 필수
for agent_file in "$HXSK_DIR/agents/"*.md; do
    [[ ! -f "$agent_file" ]] && continue
    bn=$(basename "$agent_file")
    [[ "$bn" == "INDEX.md" ]] && continue
    # frontmatter 영역 (첫 --- ~ 두번째 ---)
    FM=$(sed -n '/^---$/,/^---$/p' "$agent_file" 2>/dev/null)
    if [[ -z "$FM" ]]; then
        fail "Agent $bn: frontmatter missing"
        ((MISSING_FM++)) || true
        continue
    fi
    if ! echo "$FM" | grep -q 'description:'; then
        fail "Agent $bn: description field missing"
        ((MISSING_FM++)) || true
    fi
    if ! echo "$FM" | grep -q 'tools:'; then
        fail "Agent $bn: tools field missing"
        ((MISSING_FM++)) || true
    fi
done

# Skill: frontmatter with name + description
for skill_dir in "$HXSK_DIR/skills/"*/; do
    skill_file="$skill_dir/SKILL.md"
    [[ ! -f "$skill_file" ]] && continue
    sn=$(basename "$skill_dir")
    FM=$(sed -n '/^---$/,/^---$/p' "$skill_file" 2>/dev/null)
    if [[ -z "$FM" ]]; then
        # frontmatter 없는 스킬은 경고만
        warn "Skill $sn: no frontmatter"
        continue
    fi
    if ! echo "$FM" | grep -q 'description:'; then
        fail "Skill $sn: description field missing"
        ((MISSING_FM++)) || true
    fi
done

if [[ "$MISSING_FM" -eq 0 ]]; then
    pass "Agent/Skill frontmatter fields OK"
fi

# ─── 8. Hook 실행 권한 + shebang ─────────────────

echo ""
echo "=== Hook 실행 권한 + shebang ==="

PERM_FAIL=0
while IFS= read -r hook_file; do
    [[ -z "$hook_file" ]] && continue
    bn=$(basename "$hook_file")
    # 실행 권한 확인
    if [[ ! -x "$hook_file" ]]; then
        fail "$bn: not executable (chmod +x needed)"
        ((PERM_FAIL++)) || true
    fi
    # shebang 확인
    FIRST_LINE=$(head -1 "$hook_file")
    case "$bn" in
        *.sh)
            if [[ "$FIRST_LINE" != "#!/usr/bin/env bash" && "$FIRST_LINE" != "#!/bin/bash" ]]; then
                fail "$bn: bad shebang '$FIRST_LINE'"
                ((PERM_FAIL++)) || true
            fi
            ;;
        *.py)
            if [[ "$FIRST_LINE" != "#!/usr/bin/env python3" ]]; then
                fail "$bn: bad shebang '$FIRST_LINE'"
                ((PERM_FAIL++)) || true
            fi
            ;;
    esac
done < <(find "$HXSK_DIR/hooks" \( -name "*.sh" -o -name "*.py" \) 2>/dev/null)

if [[ "$PERM_FAIL" -eq 0 ]]; then
    pass "Hook permissions + shebangs OK"
fi

# ─── 9. 심볼릭 링크 유효성 ───────────────────────

echo ""
echo "=== Symlink validity ==="

LINK_FAIL=0
for link in "$PROJECT_DIR/.cursorrules" "$PROJECT_DIR/.windsurfrules" "$PROJECT_DIR/.github/copilot-instructions.md"; do
    if [[ -L "$link" ]]; then
        TARGET=$(readlink "$link")
        # 절대/상대 경로 해석
        if [[ "$TARGET" == /* ]]; then
            RESOLVED="$TARGET"
        else
            RESOLVED="$(dirname "$link")/$TARGET"
        fi
        if [[ ! -e "$RESOLVED" ]]; then
            fail "Symlink $(basename "$link") -> $TARGET (broken)"
            ((LINK_FAIL++)) || true
        else
            pass "Symlink $(basename "$link") -> $TARGET"
        fi
    fi
    # 심볼릭 링크가 없으면 무시 (선택 사항)
done

if [[ "$LINK_FAIL" -eq 0 && "$(find "$PROJECT_DIR" -maxdepth 1 -name ".cursorrules" -o -name ".windsurfrules" 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ]]; then
    warn "No agent symlinks found (optional)"
fi

# ─── 10. 템플릿 플레이스홀더 잔존 ────────────────

echo ""
echo "=== Placeholder detection ==="

PH_FAIL=0
# working docs에서 플레이스홀더 패턴 검색 (templates/ 제외)
for wdoc in "$HXSK_DIR/SPEC.md" "$HXSK_DIR/STATE.md" "$HXSK_DIR/DECISIONS.md" "$HXSK_DIR/ROADMAP.md"; do
    [[ ! -f "$wdoc" ]] && continue
    bn=$(basename "$wdoc")
    # {Goal 1}, {Brief description} 등 — ${VAR} 환경변수 패턴 제외
    PLACEHOLDERS=$(grep -n '{[A-Z]' "$wdoc" 2>/dev/null | grep -v '\$\{' | grep -v '```' | head -3 || true)
    if [[ -n "$PLACEHOLDERS" ]]; then
        fail "$bn: placeholder found — $(echo "$PLACEHOLDERS" | head -1)"
        ((PH_FAIL++)) || true
    fi
done

if [[ "$PH_FAIL" -eq 0 ]]; then
    pass "No template placeholders in working docs"
fi

# ─── 11. 메모리 타입 디렉토리 커버리지 ────────────

echo ""
echo "=== Memory type coverage ==="

REQUIRED_TYPES="architecture-decision root-cause debug-eliminated debug-blocked health-event session-handoff execution-summary deviation pattern-discovery bootstrap session-summary session-snapshot security-finding general"
MEM_MISSING=0
for mtype in $REQUIRED_TYPES; do
    if [[ ! -d "$HXSK_DIR/memories/$mtype" ]]; then
        fail "Memory type missing: $mtype"
        ((MEM_MISSING++)) || true
    fi
done

if [[ "$MEM_MISSING" -eq 0 ]]; then
    pass "Memory types: all 14 present"
fi

# ─── 12. 데드 에이전트/스킬 탐지 ─────────────────

echo ""
echo "=== Dead component detection ==="

DEAD_COUNT=0
# 모든 참조 가능 파일을 하나의 검색 풀로 결합
SEARCH_FILES=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.md" 2>/dev/null; echo "$HXSK_DIR/skills/"*/SKILL.md; echo "$HXSK_DIR/agents/"*.md; find "$HXSK_DIR/docs" -name "*.md" 2>/dev/null)

for agent_file in "$HXSK_DIR/agents/"*.md; do
    [[ ! -f "$agent_file" ]] && continue
    bn=$(basename "$agent_file" .md)
    [[ "$bn" == "INDEX" ]] && continue
    # INDEX.md 이외의 파일에서 에이전트명이 참조되는지
    REF_COUNT=$(grep -rl "$bn" $SEARCH_FILES 2>/dev/null | grep -v "INDEX.md" | grep -v "$agent_file" | wc -l | tr -d ' ')
    if [[ "$REF_COUNT" -eq 0 ]]; then
        warn "Agent '$bn' referenced nowhere (possible dead component)"
        ((DEAD_COUNT++)) || true
    fi
done

for skill_dir in "$HXSK_DIR/skills/"*/; do
    [[ ! -d "$skill_dir" ]] && continue
    sn=$(basename "$skill_dir")
    REF_COUNT=$(grep -rl "$sn" $SEARCH_FILES 2>/dev/null | grep -v "INDEX.md" | grep -v "$skill_dir" | wc -l | tr -d ' ')
    if [[ "$REF_COUNT" -eq 0 ]]; then
        warn "Skill '$sn' referenced nowhere (possible dead component)"
        ((DEAD_COUNT++)) || true
    fi
done

if [[ "$DEAD_COUNT" -eq 0 ]]; then
    pass "No dead agents/skills detected"
else
    pass "Dead component scan: $DEAD_COUNT warnings"
fi

# ─── 13. set -euo pipefail 일관성 ────────────────

echo ""
echo "=== Strict mode (set -euo pipefail) ==="

STRICT_FAIL=0
while IFS= read -r sh_file; do
    [[ -z "$sh_file" ]] && continue
    bn=$(basename "$sh_file")
    # _json_parse.sh 같은 라이브러리 파일은 제외
    [[ "$bn" == _* ]] && continue
    if ! grep -q 'set -o errexit\|set -euo\|set -e' "$sh_file" 2>/dev/null; then
        warn "$bn: no strict mode (set -e/errexit)"
        ((STRICT_FAIL++)) || true
    fi
done < <(find "$HXSK_DIR/hooks" -name "*.sh" 2>/dev/null; find "$HXSK_DIR/scripts" -name "*.sh" 2>/dev/null)

if [[ "$STRICT_FAIL" -eq 0 ]]; then
    pass "All shell scripts use strict mode"
fi

# ─── 14. settings.json JSON 문법 ─────────────────

echo ""
echo "=== settings.json JSON syntax ==="

if [[ -f "$SETTINGS" ]]; then
    if command -v python3 &>/dev/null; then
        if python3 -m json.tool < "$SETTINGS" >/dev/null 2>&1; then
            pass "settings.json: valid JSON"
        else
            fail "settings.json: invalid JSON syntax"
        fi
    else
        warn "python3 not found — JSON validation skipped"
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
