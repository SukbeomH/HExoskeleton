#!/usr/bin/env bash
# pre-pr-check.sh — PR 생성 전 버전/CHANGELOG/릴리즈 정보 누락 검증
#
# Usage: bash .hxsk/hooks/pre-pr-check.sh
#
# Exit 0: 모든 검사 통과
# Exit 1: 누락 발견

set -o errexit
set -o nounset
set -o pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
FAIL=0
WARN=0
PASS=0

pass() { printf "  [PASS] %s\n" "$1"; ((PASS++)) || true; }
fail() { printf "  [FAIL] %s\n" "$1"; ((FAIL++)) || true; }
warn() { printf "  [WARN] %s\n" "$1"; ((WARN++)) || true; }

echo "================================================================"
echo " PRE-PR CHECK"
echo "================================================================"

# ─── 1. 버전 동기화 ──────────────────────────────

echo ""
echo "=== Version sync ==="

VERSION_FILE="$HXSK_DIR/.bootstrap-version"
FILE_VER=""
SCRIPT_VER=""

if [[ -f "$VERSION_FILE" ]]; then
    FILE_VER=$(grep '^version:' "$VERSION_FILE" | sed 's/^version: *//' | tr -d '"[:space:]')
fi

if [[ -f "$HXSK_DIR/scripts/bootstrap.sh" ]]; then
    SCRIPT_VER=$(grep 'BOOTSTRAP_VERSION=' "$HXSK_DIR/scripts/bootstrap.sh" | head -1 | sed 's/.*="\(.*\)"/\1/')
fi

if [[ -n "$FILE_VER" && -n "$SCRIPT_VER" ]]; then
    if [[ "$FILE_VER" == "$SCRIPT_VER" ]]; then
        pass "bootstrap-version ($FILE_VER) = bootstrap.sh ($SCRIPT_VER)"
    else
        fail "bootstrap-version ($FILE_VER) != bootstrap.sh ($SCRIPT_VER)"
    fi
else
    warn "Version files not found"
fi

# ─── 2. CHANGELOG 엔트리 ─────────────────────────

echo ""
echo "=== CHANGELOG ==="

CHANGELOG="$HXSK_DIR/CHANGELOG.md"
if [[ -f "$CHANGELOG" && -n "$FILE_VER" ]]; then
    if grep -q "v${FILE_VER}" "$CHANGELOG"; then
        pass "CHANGELOG has v${FILE_VER} entry"

        # 날짜 확인
        TODAY=$(date '+%Y-%m-%d')
        ENTRY_DATE=$(grep "v${FILE_VER}" "$CHANGELOG" | head -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
        if [[ "$ENTRY_DATE" == "$TODAY" ]]; then
            pass "CHANGELOG date is today ($TODAY)"
        elif [[ -n "$ENTRY_DATE" ]]; then
            warn "CHANGELOG date ($ENTRY_DATE) is not today ($TODAY)"
        fi
    else
        fail "CHANGELOG has no v${FILE_VER} entry"
    fi
else
    warn "CHANGELOG or version file not found"
fi

# ─── 3. 미커밋 변경사항 ──────────────────────────

echo ""
echo "=== Git status ==="

UNCOMMITTED=$(git -C "$PROJECT_DIR" status --short 2>/dev/null | awk '!/^\?\?/ {count++} END {print count+0}')
if [[ "$UNCOMMITTED" -eq 0 ]]; then
    pass "No uncommitted changes"
else
    warn "$UNCOMMITTED uncommitted change(s) — commit before PR"
fi

# ─── 4. 브랜치가 master가 아닌지 ─────────────────

# CI에서는 GITHUB_HEAD_REF (PR 소스 브랜치), 로컬에서는 git branch
BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")}"
if [[ "$BRANCH" == "master" || "$BRANCH" == "main" ]]; then
    fail "On $BRANCH branch — create a feature branch first"
else
    pass "On branch: $BRANCH"
fi

# ─── 5. 새 커밋 vs CHANGELOG 커버리지 ────────────

echo ""
echo "=== Commit coverage ==="

# master와의 diff에서 변경된 주요 파일 확인
BASE_BRANCH="origin/master"
CHANGED_AREAS=""

if git -C "$PROJECT_DIR" rev-parse "$BASE_BRANCH" &>/dev/null; then
    DIFF_FILES=$(git -C "$PROJECT_DIR" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || true)

    # 주요 영역 변경 감지
    if echo "$DIFF_FILES" | grep -q '\.hxsk/hooks/'; then
        CHANGED_AREAS="$CHANGED_AREAS hooks"
    fi
    if echo "$DIFF_FILES" | grep -q '\.hxsk/skills/'; then
        CHANGED_AREAS="$CHANGED_AREAS skills"
    fi
    if echo "$DIFF_FILES" | grep -q '\.hxsk/agents/'; then
        CHANGED_AREAS="$CHANGED_AREAS agents"
    fi
    if echo "$DIFF_FILES" | grep -q '\.hxsk/scripts/'; then
        CHANGED_AREAS="$CHANGED_AREAS scripts"
    fi
    if echo "$DIFF_FILES" | grep -q 'settings.json'; then
        CHANGED_AREAS="$CHANGED_AREAS settings"
    fi
    if echo "$DIFF_FILES" | grep -q '\.hxsk/prompts/'; then
        CHANGED_AREAS="$CHANGED_AREAS prompts"
    fi

    COMMIT_COUNT=$(git -C "$PROJECT_DIR" log --oneline "$BASE_BRANCH"...HEAD 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$COMMIT_COUNT" -gt 0 ]]; then
        pass "$COMMIT_COUNT commit(s) on this branch"
        if [[ -n "$CHANGED_AREAS" ]]; then
            pass "Changed areas:$CHANGED_AREAS"
        fi
    else
        warn "No commits ahead of $BASE_BRANCH"
    fi
fi

# ─── 6. 컴포넌트 카운트 vs bootstrap-version ─────

echo ""
echo "=== Component counts ==="

mkdir -p "$HXSK_DIR/skills" "$HXSK_DIR/agents" "$HXSK_DIR/hooks"
ACT_SKILLS=$(find "$HXSK_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
ACT_AGENTS=$(find "$HXSK_DIR/agents" -name "*.md" -not -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')
ACT_HOOKS=$(find "$HXSK_DIR/hooks" \( -name "*.sh" -o -name "*.py" \) 2>/dev/null | wc -l | tr -d ' ')

pass "Component counts (S:$ACT_SKILLS A:$ACT_AGENTS H:$ACT_HOOKS)"

# .bootstrap-version 카운트 자동 동기화
if [[ -f "$VERSION_FILE" ]]; then
    REC_SKILLS=$(grep 'skills:' "$VERSION_FILE" | sed 's/.*skills: *//' | tr -d ' ')
    REC_AGENTS=$(grep 'agents:' "$VERSION_FILE" | sed 's/.*agents: *//' | tr -d ' ')
    REC_HOOKS=$(grep 'hooks:' "$VERSION_FILE" | sed 's/.*hooks: *//' | tr -d ' ')

    if [[ "$REC_SKILLS" != "$ACT_SKILLS" || "$REC_AGENTS" != "$ACT_AGENTS" || "$REC_HOOKS" != "$ACT_HOOKS" ]]; then
        sed -i.bak "s/skills: .*/skills: $ACT_SKILLS/" "$VERSION_FILE"
        sed -i.bak "s/agents: .*/agents: $ACT_AGENTS/" "$VERSION_FILE"
        sed -i.bak "s/hooks: .*/hooks: $ACT_HOOKS/" "$VERSION_FILE"
        rm -f "${VERSION_FILE}.bak"
        warn "카운트 자동 갱신: S:$REC_SKILLS→$ACT_SKILLS A:$REC_AGENTS→$ACT_AGENTS H:$REC_HOOKS→$ACT_HOOKS"
    fi
fi

# ─── 7. GitHub 릴리즈 확인 ────────────────────────

echo ""
echo "=== GitHub release ==="

if [[ "${HXSK_SKIP_GITHUB:-0}" == "1" ]]; then
    warn "GitHub release check skipped (HXSK_SKIP_GITHUB=1)"
elif command -v gh &>/dev/null && [[ -n "$FILE_VER" ]]; then
    RELEASE_TAG="setup-v${FILE_VER}"
    LATEST_RELEASE=$(gh release list --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || true)

    if gh release view "$RELEASE_TAG" &>/dev/null; then
        pass "Release $RELEASE_TAG exists"
        # 릴리즈 에셋의 setup.md와 로컬 비교
        REMOTE_HASH=$(gh release view "$RELEASE_TAG" --json assets -q '.assets[] | select(.name=="setup.md") | .digest' 2>/dev/null || true)
        LOCAL_HASH="sha256:$(shasum -a 256 .hxsk/prompts/setup.md 2>/dev/null | awk '{print $1}')"
        if [[ -n "$REMOTE_HASH" && "$REMOTE_HASH" != "$LOCAL_HASH" ]]; then
            warn "Release setup.md differs from local — release update needed after merge"
        fi
    else
        warn "Release $RELEASE_TAG not found — will be created on merge (CI)"
    fi

    if [[ -n "$LATEST_RELEASE" ]]; then
        LATEST_VER=$(echo "$LATEST_RELEASE" | sed 's/^setup-v//')
        pass "Latest release: $LATEST_RELEASE"
        # 현재 버전이 최신 릴리즈보다 높은지 (단순 문자열 비교)
        if [[ "$FILE_VER" != "$LATEST_VER" && "$FILE_VER" > "$LATEST_VER" ]]; then
            pass "Version $FILE_VER > latest release $LATEST_VER (new release expected)"
        elif [[ "$FILE_VER" == "$LATEST_VER" ]]; then
            pass "Version matches latest release"
        else
            fail "Version $FILE_VER < latest release $LATEST_VER — version downgrade?"
        fi
    fi
else
    warn "gh CLI not available or version unknown — release check skipped"
fi

# ─── 8. 정합성 검증 연동 ─────────────────────────

echo ""
echo "=== Consistency check ==="

CONSISTENCY_SCRIPT="$HXSK_DIR/hooks/check-consistency.sh"
if [[ -x "$CONSISTENCY_SCRIPT" ]]; then
    if bash "$CONSISTENCY_SCRIPT" >/dev/null 2>&1; then
        pass "check-consistency.sh: ALL CONSISTENT"
    else
        fail "check-consistency.sh: FAILED — run 'bash $CONSISTENCY_SCRIPT' for details"
    fi
else
    warn "check-consistency.sh not found or not executable"
fi

# ─── 9. 버전업 추천 (Conventional Commits 분석) ──

echo ""
echo "=== Version recommendation ==="

BASE_BRANCH="origin/master"
if [[ -n "$FILE_VER" ]] && git rev-parse "$BASE_BRANCH" &>/dev/null 2>&1; then
    COMMITS=$(git log --oneline "$BASE_BRANCH"...HEAD 2>/dev/null || true)

    if [[ -z "$COMMITS" ]]; then
        pass "No new commits — no version change needed"
    else
        # Conventional Commits 분석
        # BREAKING CHANGE / feat! / fix! → major
        # feat: → minor
        # fix: / refactor: / perf: / docs: / ci: / chore: → patch
        HAS_BREAKING=false
        HAS_FEAT=false
        HAS_FIX=false
        FEAT_COUNT=0
        FIX_COUNT=0
        OTHER_COUNT=0

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # 커밋 해시 제거 (첫 단어)
            MSG="${line#* }"

            # BREAKING CHANGE 감지
            if echo "$MSG" | grep -qiE 'BREAKING|!:'; then
                HAS_BREAKING=true
            fi

            # 타입 분류
            TYPE=$(echo "$MSG" | grep -oE '^(feat|fix|refactor|perf|docs|ci|chore|test|style|build|revert)' || true)
            case "$TYPE" in
                feat)
                    HAS_FEAT=true
                    ((FEAT_COUNT++)) || true
                    ;;
                fix|refactor|perf)
                    HAS_FIX=true
                    ((FIX_COUNT++)) || true
                    ;;
                docs|ci|chore|test|style|build|revert)
                    ((OTHER_COUNT++)) || true
                    ;;
                *)
                    # 비표준 커밋도 patch로 간주
                    ((OTHER_COUNT++)) || true
                    ;;
            esac
        done <<< "$COMMITS"

        # 현재 버전 파싱
        CUR_MAJOR=$(echo "$FILE_VER" | cut -d. -f1)
        CUR_MINOR=$(echo "$FILE_VER" | cut -d. -f2)
        CUR_PATCH=$(echo "$FILE_VER" | cut -d. -f3)

        # 추천 버전 계산
        if $HAS_BREAKING; then
            REC_VER="$((CUR_MAJOR + 1)).0.0"
            REASON="BREAKING CHANGE detected"
            BUMP="major"
        elif $HAS_FEAT; then
            REC_VER="${CUR_MAJOR}.$((CUR_MINOR + 1)).0"
            REASON="${FEAT_COUNT} feat commit(s)"
            BUMP="minor"
        elif $HAS_FIX; then
            REC_VER="${CUR_MAJOR}.${CUR_MINOR}.$((CUR_PATCH + 1))"
            REASON="${FIX_COUNT} fix/refactor commit(s)"
            BUMP="patch"
        else
            REC_VER=""
            REASON="${OTHER_COUNT} docs/ci/chore commit(s) only"
            BUMP="none"
        fi

        # 커밋 요약
        TOTAL=$((FEAT_COUNT + FIX_COUNT + OTHER_COUNT))
        echo "  Commits: $TOTAL (feat:$FEAT_COUNT fix:$FIX_COUNT other:$OTHER_COUNT)"

        if [[ "$BUMP" == "none" ]]; then
            pass "No version bump needed — $REASON"
        elif [[ -n "$REC_VER" && "$FILE_VER" == "$REC_VER" ]]; then
            pass "Version $FILE_VER matches recommendation ($BUMP: $REASON)"
        elif [[ -n "$REC_VER" && "$FILE_VER" != "$REC_VER" ]]; then
            # 현재 버전이 추천보다 높으면 OK (이미 올렸을 수 있음)
            if [[ "$FILE_VER" > "$REC_VER" ]]; then
                pass "Version $FILE_VER >= recommended $REC_VER ($BUMP: $REASON)"
            else
                warn "Version bump recommended: $FILE_VER -> $REC_VER ($BUMP: $REASON)"
                echo ""
                echo "  To apply:"
                echo "    1. .hxsk/.bootstrap-version   → version: $REC_VER"
                echo "    2. .hxsk/scripts/bootstrap.sh → BOOTSTRAP_VERSION=\"$REC_VER\""
                echo "    3. .hxsk/CHANGELOG.md         → ### [$(date '+%Y-%m-%d')] v$REC_VER entry"
                echo "    4. llms.txt                   → HXSK v$REC_VER"
            fi
        fi
    fi
else
    warn "Version or base branch not available — skip recommendation"
fi

# ─── Summary ──────────────────────────────────────

echo ""
echo "================================================================"
printf " PRE-PR CHECK  |  PASS: %d  FAIL: %d  WARN: %d\n" "$PASS" "$FAIL" "$WARN"
if [[ "$FAIL" -gt 0 ]]; then
    echo " RESULT: NOT READY — fix ${FAIL} issue(s) before creating PR"
    echo "================================================================"
    exit 1
else
    echo " RESULT: READY FOR PR"
    echo "================================================================"
    exit 0
fi
