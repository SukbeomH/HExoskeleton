# 기술 부채 해소 + 토큰 최적화 + 이슈 기반 병렬 실행 구조 도입

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 3개 트랙(기술 부채, 토큰 최적화, 병렬 실행 인프라)을 wave 기반 병렬 실행으로 동시 처리한다.

**Architecture:** Wave 1(6개 독립 태스크) → Wave 2(3개, Wave 1 결과 의존) → Wave 3(2개 + 통합 검증). 각 wave 내 태스크는 파일 소유권이 겹치지 않아 `isolation: "worktree"` subagent로 병렬 실행 가능하다.

**Tech Stack:** Bash 5.x, awk, sed, grep — 외부 종속성 없음

---

## 파일 소유권 맵

```
Wave 1 (독립 — 병렬 가능):
  WKT-A: scripts/build-common.sh
  WKT-B: CLAUDE.md
  WKT-C: scripts/bootstrap.sh
  WKT-D: .hxsk/hooks/session-start.sh
  WKT-E: .claude/settings.json
  WKT-F: [신규] .hxsk/issues/, scripts/issue-*.sh

Wave 2 (Wave 1 의존 — 병렬 가능):
  WKT-G: scripts/build-plugin.sh        ← depends_on: [WKT-A]
  WKT-H: scripts/build-opencode.sh      ← depends_on: [WKT-A]
  WKT-I: [신규] .hxsk/skills/dispatcher/, .hxsk/agents/dispatcher.md
                                         ← depends_on: [WKT-F]

Wave 3 (Wave 2 의존 — 병렬 가능):
  WKT-J: [신규] scripts/merge-worktrees.sh
  WKT-K: .hxsk/skills/executor/SKILL.md ← depends_on: [WKT-I]

Wave 4 (순차):
  통합 빌드 검증 + 문서 갱신
```

---

## Wave 1: Foundation (6개 병렬)

### Task WKT-A: `build-common.sh` — JSON 검증 + 공용 함수 (기술 부채 D1)

**Files:**
- Modify: `scripts/build-common.sh:70-82` (verify_json 교체)
- Modify: `scripts/build-common.sh:119` 뒤에 추가 (extract_frontmatter_field)

**Step 1: verify_json을 pure bash로 교체**

```bash
verify_json() {
    local json_path="$1"
    local label
    label="$(basename "$json_path")"

    if [ ! -s "$json_path" ]; then
        echo "  [FAIL] ${label} empty or missing"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
        return
    fi

    local first_char
    first_char=$(head -c1 "$json_path" | tr -d '[:space:]')
    if [[ "$first_char" != "{" && "$first_char" != "[" ]]; then
        echo "  [FAIL] ${label} invalid (not JSON)"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
        return
    fi

    if command -v jq &>/dev/null; then
        if jq empty "$json_path" 2>/dev/null; then
            echo "  [OK] ${label}"
        else
            echo "  [FAIL] ${label} invalid"
            BUILD_ERRORS=$((BUILD_ERRORS + 1))
        fi
    else
        local balance
        balance=$(awk '{for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c=="{"||c=="[")d++;else if(c=="}"||c=="]")d--}} END{print d+0}' "$json_path")
        if [ "$balance" -eq 0 ]; then
            echo "  [OK] ${label}"
        else
            echo "  [FAIL] ${label} invalid (unbalanced)"
            BUILD_ERRORS=$((BUILD_ERRORS + 1))
        fi
    fi
}
```

**Step 2: extract_frontmatter_field 공용 함수 추가 (BUILD_ERRORS 초기화 뒤)**

```bash
# extract_frontmatter_field <file> <field>
extract_frontmatter_field() {
    local file="$1"
    local field="$2"
    awk -v fld="$field" '
        BEGIN { in_fm=0 }
        NR==1 && /^---/ { in_fm=1; next }
        in_fm && /^---/ { exit }
        in_fm && $0 ~ "^" fld ":" {
            sub("^" fld ":[ ]*", "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$file"
}
```

**Step 3: 검증**

Run: `bash -c 'source scripts/build-common.sh; echo "{}" > /tmp/test.json; verify_json /tmp/test.json'`
Expected: `[OK] test.json`

**Step 4: Commit**

```bash
git add scripts/build-common.sh
git commit -m "refactor(build): verify_json + extract_frontmatter_field pure bash 전환"
```

---

### Task WKT-B: `CLAUDE.md` — docs/ 추가 + compaction 지침 (D7 + T3)

**Files:**
- Modify: `CLAUDE.md:17-19` (Repository Layout)
- Modify: `CLAUDE.md:74` 뒤에 추가 (Compaction Rules)

**Step 1: Repository Layout에 docs/ 추가**

```markdown
## Repository Layout

- **.claude/** — Agent/Skill/Hook 설정 (single source of truth)
- **.hxsk/** — Working docs (`SPEC/PLAN/DECISIONS/STATE.md`), `memories/`, `reports/`, `research/`
- **scripts/** — Utility scripts (md-store-memory.sh, md-recall-memory.sh 등)
- **docs/** — 프로젝트 문서 (빌드, 훅, 스킬, 워크플로우, 컨벤션 가이드)
```

**Step 2: Execution Constraints 뒤에 Compaction Rules 추가**

```markdown
## Compaction Rules

압축 시 반드시 보존:
- `.hxsk/.track-modifications.log` 변경 파일 목록
- 현재 SPEC.md 목표 및 활성 PLAN.md 태스크
- 이 세션의 메모리 검색 결과와 아키텍처 결정사항
```

**Step 3: 줄 수 검증**

Run: `wc -l CLAUDE.md`
Expected: ≤120줄

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): Repository Layout에 docs/ 추가, compaction 지침 추가"
```

---

### Task WKT-C: `bootstrap.sh` — python3/uv 선택적 의존성 (D8)

**Files:**
- Modify: `scripts/bootstrap.sh:80-107`

**Step 1: uv를 optional로 변경 (line 80-86)**

```bash
# uv (optional — Python 프로젝트에서만 필요)
if command -v uv &>/dev/null; then
    UV_VER=$(uv --version 2>/dev/null | awk '{print $2}')
    report_pass "uv" "${UV_VER}"
else
    report_skip "uv" "not found — only needed for Python projects"
fi
```

**Step 2: python3를 optional로 변경 (line 88-99)**

```bash
# Python 3 (보안 훅에서 사용 — 선택적)
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version | awk '{print $2}')
    PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
    if [[ "$PY_MINOR" -ge 11 ]]; then
        report_pass "Python" "${PY_VER}"
    else
        report_warn "Python" "${PY_VER} (>= 3.11 recommended)"
    fi
else
    report_warn "Python" "not found — security hooks (file-protect, bash-guard) unavailable"
fi
```

**Step 3: 검증**

Run: `bash scripts/bootstrap.sh 2>&1 | grep -E 'RESULT|Python|uv'`
Expected: `RESULT: ALL REQUIRED CHECKS PASSED` (python3/uv 없어도)

**Step 4: Commit**

```bash
git add scripts/bootstrap.sh
git commit -m "fix(bootstrap): python3/uv를 선택적 의존성으로 변경"
```

---

### Task WKT-D: `session-start.sh` — 토큰 경량화 (T1)

**Files:**
- Modify: `.hxsk/hooks/session-start.sh`

**Step 1: 중복 로드 제거 + 출력 축소**

변경 사항:
1. PATTERNS.md 로드 제거 — CLAUDE.md SessionStart hook의 additionalContext에서 이미 `.hxsk/PATTERNS.md`를 주입하지만, CLAUDE.md 자체가 PATTERNS.md를 시스템 컨텍스트로 로드함 → 중복
2. STATE.md: `head -80` → `head -30` (Current Position + Last Action만)
3. CURRENT.md: `cat` → `head -15`
4. Memory recall: 5건 → 3건

```bash
    # 1. PATTERNS.md — CLAUDE.md에서 이미 로드되므로 생략
    # (제거: PATTERNS_FILE 관련 블록)

    # 2. CURRENT.md 로드 (상위 15줄만)
    CURRENT_FILE="$HXSK_DIR/CURRENT.md"
    if [ -f "$CURRENT_FILE" ]; then
        CURRENT_CONTENT=$(head -15 "$CURRENT_FILE" 2>/dev/null || true)
        if [ -n "$CURRENT_CONTENT" ] && ! grep -q "^<!-- Current task ID" "$CURRENT_FILE"; then
            CONTEXT_PARTS+=("")
            CONTEXT_PARTS+=("## Current Session Context (from .hxsk/CURRENT.md)")
            CONTEXT_PARTS+=("$CURRENT_CONTENT")
        fi
    fi

    # 3. STATE.md 로드 (상위 30줄만)
    STATE_FILE="$HXSK_DIR/STATE.md"
    if [ -f "$STATE_FILE" ]; then
        STATE_CONTENT=$(head -30 "$STATE_FILE" 2>/dev/null || true)
        # ...
    fi

    # 6. Memory Recall (3건으로 축소)
    MEMORY_OUTPUT=$("$HOOK_DIR/md-recall-memory.sh" "project context" "$PROJECT_DIR" 3 2>/dev/null || true)
```

**Step 2: 검증**

Run: `CLAUDE_PROJECT_DIR=. bash .hxsk/hooks/session-start.sh 2>/dev/null | wc -c`
Expected: 이전 대비 40~60% 감소

**Step 3: Commit**

```bash
git add .hxsk/hooks/session-start.sh
git commit -m "perf(hooks): session-start 토큰 40-60% 경량화"
```

---

### Task WKT-E: `settings.json` — SubagentStop 프롬프트 구조화 (T2)

**Files:**
- Modify: `.claude/settings.json:96-98`

**Step 1: 서사형 프롬프트를 구조화 체크리스트로 변경**

```json
{
  "type": "prompt",
  "prompt": "## SubagentStop\n- 핵심 결과 2-3문장 요약\n- 코드 변경 시: `touch .hxsk/.modified-this-session`\n- 재사용 패턴 발견 시: PATTERNS.md에 추가 검토"
}
```

**Step 2: JSON 유효성 확인**

Run: `python3 -c "import json; json.load(open('.claude/settings.json'))" && echo OK`
Expected: `OK`

**Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "perf(hooks): SubagentStop 프롬프트 구조화 (토큰 30% 절감)"
```

---

### Task WKT-F: Issue Registry 생성 (신규 인프라 N1)

**Files:**
- Create: `.hxsk/issues/.gitkeep`
- Create: `scripts/issue-create.sh`
- Create: `scripts/issue-list.sh`
- Modify: `.gitignore` (issues 디렉토리 추적 허용)

**Step 1: .gitignore에 issues 추적 추가**

`.gitignore`의 `.hxsk/*` 섹션에 추가:
```
!.hxsk/issues/
```

**Step 2: issue-create.sh 작성**

```bash
#!/usr/bin/env bash
# issue-create.sh — 이슈 생성 (파일 기반)
# Usage: bash scripts/issue-create.sh <title> <type> <priority> [description]
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
mkdir -p "$ISSUES_DIR"

TITLE="$1"
TYPE="${2:-task}"          # bug|task|debt|feature
PRIORITY="${3:-P2}"        # P0|P1|P2|P3
DESCRIPTION="${4:-}"
TIMESTAMP=$(date '+%Y-%m-%d')

# 다음 이슈 번호 계산
LAST_NUM=$(find "$ISSUES_DIR" -maxdepth 1 -name '*.md' 2>/dev/null \
    | sed 's|.*/||; s|-.*||' | sort -n | tail -1)
NEXT_NUM=$(printf "%03d" $(( ${LAST_NUM:-0} + 1 )))

# slug 생성
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40)
FILENAME="${NEXT_NUM}-${SLUG}.md"

cat > "$ISSUES_DIR/$FILENAME" << EOF
---
id: ${NEXT_NUM}
title: "${TITLE}"
type: ${TYPE}
priority: ${PRIORITY}
status: open
wave: null
created: ${TIMESTAMP}
assignee: null
files: []
---

# ${TITLE}

${DESCRIPTION:-<!-- 이슈 설명 -->}

## Acceptance Criteria

- [ ] <!-- 완료 기준 -->

## Notes

<!-- 추가 메모 -->
EOF

echo "[CREATED] $ISSUES_DIR/$FILENAME"
echo "$FILENAME"
```

**Step 3: issue-list.sh 작성**

```bash
#!/usr/bin/env bash
# issue-list.sh — 이슈 목록 (L0: frontmatter만)
# Usage: bash scripts/issue-list.sh [status] [priority]
set -euo pipefail

ISSUES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/issues"
STATUS_FILTER="${1:-}"
PRIORITY_FILTER="${2:-}"

if [ ! -d "$ISSUES_DIR" ] || [ -z "$(ls "$ISSUES_DIR"/*.md 2>/dev/null)" ]; then
    echo "No issues found."
    exit 0
fi

printf "%-5s %-8s %-4s %-8s %-6s %s\n" "ID" "TYPE" "PRI" "STATUS" "WAVE" "TITLE"
printf "%-5s %-8s %-4s %-8s %-6s %s\n" "-----" "--------" "----" "--------" "------" "----------------------------"

for f in "$ISSUES_DIR"/*.md; do
    [ -f "$f" ] || continue

    # frontmatter 추출 (awk)
    eval "$(awk '
        BEGIN { in_fm=0 }
        NR==1 && /^---/ { in_fm=1; next }
        in_fm && /^---/ { exit }
        in_fm {
            if (/^id:/) { sub(/^id: */, ""); printf "ID=%s\n", $0 }
            if (/^type:/) { sub(/^type: */, ""); printf "TYPE=%s\n", $0 }
            if (/^priority:/) { sub(/^priority: */, ""); printf "PRI=%s\n", $0 }
            if (/^status:/) { sub(/^status: */, ""); printf "STATUS=%s\n", $0 }
            if (/^wave:/) { sub(/^wave: */, ""); printf "WAVE=%s\n", $0 }
            if (/^title:/) { sub(/^title: */, ""); gsub(/"/, ""); printf "TITLE=\"%s\"\n", $0 }
        }
    ' "$f")"

    # 필터
    [ -n "$STATUS_FILTER" ] && [ "$STATUS" != "$STATUS_FILTER" ] && continue
    [ -n "$PRIORITY_FILTER" ] && [ "$PRI" != "$PRIORITY_FILTER" ] && continue

    printf "%-5s %-8s %-4s %-8s %-6s %s\n" "$ID" "$TYPE" "$PRI" "$STATUS" "${WAVE:-—}" "$TITLE"
done
```

**Step 4: 검증**

Run: `bash scripts/issue-create.sh "테스트 이슈" task P2 "테스트입니다" && bash scripts/issue-list.sh`
Expected: 테이블에 이슈 1건 표시

Run: `rm .hxsk/issues/001-*.md` (테스트 정리)

**Step 5: Commit**

```bash
git add scripts/issue-create.sh scripts/issue-list.sh .hxsk/issues/.gitkeep .gitignore
git commit -m "feat(infra): 파일 기반 이슈 레지스트리 추가"
```

---

## Wave 2: Core (3개 병렬, Wave 1 의존)

### Task WKT-G: `build-plugin.sh` — python3 전면 제거 (D2+D3+D4+D5)

**depends_on:** [WKT-A]
**Files:**
- Modify: `scripts/build-plugin.sh` (4개 python3 블록 교체)

**Step 1: 버전 추출 교체 (line 27-29)**

```bash
VERSION="1.0.0"
MANIFEST="${BOILERPLATE}/.release-please-manifest.json"
if [ -f "$MANIFEST" ]; then
    VERSION=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST" | head -1 | tr -d '"')
    [ -z "$VERSION" ] && VERSION="1.0.0"
fi
```

**Step 2: hooks.json 변환 교체 (line 210-249)**

```bash
echo "[Phase 4b] Transforming hooks..."

# settings.json에서 hooks 객체 추출 → 경로 변환 → hooks 래핑
{
    echo '{"hooks":'
    awk '
        /"hooks"[[:space:]]*:/ { found=1; depth=0; next }
        found {
            for (i=1; i<=length($0); i++) {
                c = substr($0,i,1)
                if (c == "{") { depth++; started=1 }
                if (c == "}") depth--
                if (started && depth == 0) {
                    print substr($0, 1, i)
                    found=0; break
                }
            }
            if (found) print
        }
    ' "$BOILERPLATE/.claude/settings.json" \
    | sed 's|"\$CLAUDE_PROJECT_DIR"/\.hxsk/hooks/|${CLAUDE_PLUGIN_ROOT}/scripts/|g' \
    | sed "s|\"\\$CLAUDE_PROJECT_DIR\"/\\.hxsk/hooks/|\${CLAUDE_PLUGIN_ROOT}/scripts/|g"
    echo '}'
} > "$PLUGIN/hooks/hooks.json"
echo "  [+] Created hooks.json with transformed paths"
```

**Step 3: .mcp.json 변환 교체 (line 264-302)**

```bash
if [ -f "$BOILERPLATE/.mcp.json" ]; then
    sed \
        -e 's|": "\."$|": "${CLAUDE_PROJECT_DIR:-.}"|' \
        -e '/"context7"/,/}/d' \
        -e '/"enable_tool_search"/d' \
        "$BOILERPLATE/.mcp.json" > "$PLUGIN/.mcp.json"
    echo "  [+] Created .mcp.json with adjusted paths"
else
    echo "  [SKIP] .mcp.json not found (pure bash mode)"
fi
```

**Step 4: README 생성 교체 (line 540-759)**

`extract_frontmatter_field` (build-common.sh에서 source됨)을 활용:

```bash
echo "[Phase 6c] Creating README.md..."

PLUGIN_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    "$PLUGIN/.claude-plugin/plugin.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Commands 수집
CMD_ROWS=""
CMD_COUNT=0
for f in "$PLUGIN/commands/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "${f%.md}")
    desc=$(extract_frontmatter_field "$f" "description")
    [ -z "$desc" ] && desc="Run ${name}"
    CMD_ROWS="${CMD_ROWS}| \`/hxsk:${name}\` | ${desc} |
"
    CMD_COUNT=$((CMD_COUNT + 1))
done

# Skills 수집
SKILL_ROWS=""
SKILL_COUNT=0
for d in "$PLUGIN/skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    sm="$d/SKILL.md"
    desc=""
    [ -f "$sm" ] && desc=$(extract_frontmatter_field "$sm" "description")
    [ -z "$desc" ] && desc="Run ${name} skill"
    SKILL_ROWS="${SKILL_ROWS}| \`${name}\` | ${desc} |
"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

# Agents 수집
AGENT_ROWS=""
AGENT_COUNT=0
for f in "$PLUGIN/agents/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "${f%.md}")
    desc=$(extract_frontmatter_field "$f" "description")
    [ -z "$desc" ] && desc="${name} agent"
    AGENT_ROWS="${AGENT_ROWS}| \`${name}\` | ${desc} |
"
    AGENT_COUNT=$((AGENT_COUNT + 1))
done

# README 조립 (heredoc)
cat > "$PLUGIN/README.md" << READMEEOF
# HExoskeleton for Claude Code

**Get Shit Done** v${PLUGIN_VERSION} — AI agent development methodology with pure bash-based memory system.

**외부 종속성 없음** — Node.js, Python 환경, MCP 서버 설치 없이 바로 사용 가능합니다.

## Installation

\`\`\`bash
claude --plugin-dir /path/to/hxsk-plugin
\`\`\`

## Commands (${CMD_COUNT})

| Command | Description |
|---------|-------------|
${CMD_ROWS}
## Skills (${SKILL_COUNT})

| Skill | Description |
|-------|-------------|
${SKILL_ROWS}
## Agents (${AGENT_COUNT})

| Agent | Description |
|-------|-------------|
${AGENT_ROWS}
## HXSK Document Structure

\`\`\`
.hxsk/
├── SPEC.md           # Project specification
├── DECISIONS.md      # Architecture decision records
├── PATTERNS.md       # Distilled learnings (2KB limit)
├── STATE.md          # Current execution state
├── templates/        # Document templates
└── examples/         # Usage examples
\`\`\`

## Hooks

| Event | Action |
|-------|--------|
| **SessionStart** | Environment setup, status check |
| **PreToolUse** | File protection, bash guard |
| **PostToolUse** | Auto-format, track modifications |
| **Stop** | Verify work, save context |
| **SessionEnd** | Save transcript, session changes |

## License

MIT
READMEEOF

echo "  [+] Created README.md (v${PLUGIN_VERSION}, ${CMD_COUNT} commands, ${SKILL_COUNT} skills, ${AGENT_COUNT} agents)"
```

**Step 5: 빌드 검증**

Run: `make build-plugin 2>&1 | tail -20`
Expected: `BUILD SUCCESSFUL`

Run: `grep -c 'python3' scripts/build-plugin.sh | grep -v '#\|PYEOF\|heredoc\|\$ python3'`
Expected: 0 (python3 인라인 호출 없음)

**Step 6: Commit**

```bash
git add scripts/build-plugin.sh
git commit -m "refactor(build): build-plugin.sh에서 python3 완전 제거 — pure bash"
```

---

### Task WKT-H: `build-opencode.sh` — .mcp.json 변환 제거 (D6)

**depends_on:** [WKT-A]
**Files:**
- Modify: `scripts/build-opencode.sh:270-306`

**Step 1: python3 .mcp.json 변환을 sed로 교체**

```bash
if [ -f "$BOILERPLATE/.mcp.json" ]; then
    sed -e '/"enable_tool_search"/d' \
        "$BOILERPLATE/.mcp.json" > "$OPENCODE/.mcp.json"
    echo "  [+] .mcp.json created"
else
    echo "  [SKIP] .mcp.json not found (pure bash mode)"
fi
```

**Step 2: 빌드 검증**

Run: `make build-opencode 2>&1 | tail -10`
Expected: `BUILD SUCCESSFUL` 또는 `.mcp.json` SKIP

**Step 3: Commit**

```bash
git add scripts/build-opencode.sh
git commit -m "refactor(build): build-opencode.sh .mcp.json 변환에서 python3 제거"
```

---

### Task WKT-I: Dispatcher Skill + Agent 생성 (신규 인프라 N2)

**depends_on:** [WKT-F]
**Files:**
- Create: `.hxsk/skills/dispatcher/SKILL.md`
- Create: `.hxsk/agents/dispatcher.md`

**Step 1: Dispatcher Skill 작성**

```markdown
---
name: dispatcher
description: "Wave 기반 병렬 이슈 디스패치 — 이슈 → worktree subagent 배정"
version: 1.0.0
trigger: "dispatch|병렬 실행|wave 실행|이슈 배정"
allowed-tools:
  - Agent
  - Read
  - Bash
  - Glob
  - Grep
---

## Quick Reference
- **입력**: PLAN.md (wave 구조) 또는 .hxsk/issues/*.md (이슈 목록)
- **출력**: wave별 subagent 병렬 실행 → 결과 수집 → merge
- **규칙**: 같은 wave 내 파일 소유권 겹침 없음 검증 필수
- **Merge**: `scripts/merge-worktrees.sh` 사용
- **Fallback**: 충돌 시 이슈 에스컬레이션

# Dispatcher Skill

<role>
You are a wave-based parallel dispatch orchestrator.
You take a set of issues or plans grouped into dependency waves
and dispatch each wave's items as isolated subagents in parallel worktrees.
</role>

## Dispatch Protocol

### Phase 1: Load & Validate

1. 이슈 목록 로드 (L0: frontmatter만)
   ```bash
   bash scripts/issue-list.sh open
   ```

2. Wave 할당 검증
   - 같은 wave 내 이슈의 `files` 필드 교차 확인
   - 겹치면 → 후속 wave로 이동 또는 분할

### Phase 2: Wave 실행

각 wave를 순차적으로 처리하되, wave 내 이슈는 병렬 dispatch:

```
for wave in 1, 2, 3...:
    for issue in wave:
        Agent(
            prompt: "이슈 #{id} 실행: {title}\n\n{issue 본문 전체}",
            isolation: "worktree",
            subagent_type: "general-purpose",
            run_in_background: true
        )
    모든 subagent 완료 대기
    결과 수집 및 리뷰
```

### Phase 3: Merge

각 subagent worktree 결과를 순차 merge:

```bash
bash scripts/merge-worktrees.sh <worktree-path> <branch-name>
```

충돌 발생 시:
1. 자동 해소 시도 (`git merge --no-edit`)
2. 실패 시 이슈 상태를 `blocked`로 변경
3. 사용자에게 에스컬레이션

### Phase 4: Verify

모든 merge 후 통합 검증:
- `make build` 성공 확인
- 변경된 파일의 영향 분석 (impact-analysis skill)

## Dispatch Rules

1. **Wave 순서 엄수**: Wave N+1은 Wave N 완료 후에만 시작
2. **파일 소유권 검증**: 같은 wave 내 이슈가 동일 파일 수정 금지
3. **Subagent 독립성**: 각 subagent는 자체 worktree에서 독립 실행
4. **실패 격리**: 하나의 subagent 실패가 다른 subagent에 영향 없음
5. **결과 리뷰**: merge 전 각 subagent 결과를 메인 에이전트가 리뷰
```

**Step 2: Dispatcher Agent 작성**

```markdown
---
description: "Wave 기반 병렬 이슈 디스패치 오케스트레이터"
model: opus
tools: ["Agent", "Read", "Write", "Bash", "Glob", "Grep"]
---

You are the HXSK Dispatcher agent. Your role is to orchestrate
parallel execution of issues across isolated git worktrees.

Follow the dispatcher skill exactly:
1. Load issues from `.hxsk/issues/` (L0: frontmatter only)
2. Validate wave assignments and file ownership
3. Dispatch each wave's issues as parallel subagents with `isolation: "worktree"`
4. Collect results, review changes, merge worktrees
5. Run integration verification

Key constraints:
- Same-wave issues MUST NOT modify the same files
- Always run `scripts/merge-worktrees.sh` for merging
- Escalate merge conflicts as new issues
- Use `run_in_background: true` for parallel dispatch within a wave
```

**Step 3: Commit**

```bash
git add .hxsk/skills/dispatcher/SKILL.md .hxsk/agents/dispatcher.md
git commit -m "feat(infra): dispatcher skill + agent — wave 기반 병렬 실행"
```

---

## Wave 3: Integration (2개 병렬, Wave 2 의존)

### Task WKT-J: `merge-worktrees.sh` 생성 (N3)

**Files:**
- Create: `scripts/merge-worktrees.sh`

**Step 1: merge-worktrees.sh 작성**

```bash
#!/usr/bin/env bash
# merge-worktrees.sh — Subagent worktree 결과를 현재 브랜치에 merge
# Usage: bash scripts/merge-worktrees.sh <worktree-path> [branch-name]
set -euo pipefail

WORKTREE_PATH="$1"
BRANCH="${2:-}"

if [ -z "$BRANCH" ]; then
    BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null)
fi

if [ -z "$BRANCH" ]; then
    echo "[FAIL] Cannot determine branch for worktree: $WORKTREE_PATH"
    exit 1
fi

echo "=== Merging worktree ==="
echo "  Worktree: $WORKTREE_PATH"
echo "  Branch: $BRANCH"

# 변경사항 확인
CHANGES=$(git -C "$WORKTREE_PATH" diff --stat HEAD 2>/dev/null || true)
COMMITS=$(git -C "$WORKTREE_PATH" log --oneline "$(git merge-base HEAD "$BRANCH")..${BRANCH}" 2>/dev/null || true)

if [ -z "$COMMITS" ]; then
    echo "  [SKIP] No new commits on $BRANCH"
    exit 0
fi

echo ""
echo "[Commits]"
echo "$COMMITS"
echo ""

# Merge 시도
if git merge --no-ff "$BRANCH" -m "merge: $BRANCH (subagent worktree)"; then
    echo ""
    echo "[OK] Merged $BRANCH successfully"

    # Worktree 정리
    git worktree remove "$WORKTREE_PATH" 2>/dev/null || true
    git branch -d "$BRANCH" 2>/dev/null || true
    echo "[OK] Cleaned up worktree and branch"
else
    echo ""
    echo "[CONFLICT] Merge conflict detected"
    echo ""
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U
    echo ""
    echo "Options:"
    echo "  1. Resolve manually and: git merge --continue"
    echo "  2. Abort merge: git merge --abort"
    echo "  3. Create issue: bash scripts/issue-create.sh 'Merge conflict: $BRANCH' bug P1"
    exit 2
fi
```

**Step 2: Commit**

```bash
chmod +x scripts/merge-worktrees.sh
git add scripts/merge-worktrees.sh
git commit -m "feat(infra): merge-worktrees.sh — subagent 워크트리 병합 스크립트"
```

---

### Task WKT-K: Executor Pattern D 확장 (N4)

**depends_on:** [WKT-I]
**Files:**
- Modify: `.hxsk/skills/executor/SKILL.md` (Step 3에 Pattern D 추가)

**Step 1: Pattern D 추가 (line 77 뒤)**

```markdown
**Pattern D: Parallel wave dispatch (has wave structure)**
- Read wave assignments from PLAN.md
- For each wave (sequential):
  - Validate file ownership within wave
  - Dispatch wave items as parallel subagents (Agent tool, isolation: "worktree")
  - Wait for all subagents to complete
  - Review results and merge worktrees
- After all waves: run overall verification
- Note: Use dispatcher skill for orchestration details
```

**Step 2: Step 3의 패턴 선택 로직에 Wave 감지 추가**

```markdown
### Step 3: Determine Execution Pattern

Check PLAN.md for execution mode:
- No checkpoints, no waves → **Pattern A** (sequential)
- Has checkpoints → **Pattern B** (checkpoint stops)
- Is a continuation → **Pattern C** (resume)
- Has WAVE_STRUCTURE with 2+ wave-1 plans → **Pattern D** (parallel dispatch)
```

**Step 3: Commit**

```bash
git add .hxsk/skills/executor/SKILL.md
git commit -m "feat(executor): Pattern D — wave 기반 병렬 실행 지원"
```

---

## Wave 4: 통합 검증 (순차)

### Task VERIFY: 전체 빌드 + 문서 갱신

**depends_on:** [WKT-G, WKT-H, WKT-I, WKT-J, WKT-K]

**Step 1: 전체 빌드**

Run: `make clean && make build 2>&1 | tail -30`
Expected: `All builds complete!` — 3개 타겟 성공

**Step 2: python3 잔여 확인**

Run: `grep -rn 'python3 -c\|python3 -' scripts/build-plugin.sh scripts/build-opencode.sh scripts/build-common.sh | grep -v '^\s*#\|PYEOF\|heredoc\|\$ python3'`
Expected: 출력 없음

**Step 3: hooks.json 변환 검증**

Run: `grep -c '\.hxsk/hooks/' hxsk-plugin/hooks/hooks.json`
Expected: `0`

**Step 4: 신규 인프라 검증**

Run: `bash scripts/issue-create.sh "검증 테스트" task P3 "통합 테스트" && bash scripts/issue-list.sh && rm .hxsk/issues/001-*.md`
Expected: 이슈 생성 → 목록 표시 → 정리

**Step 5: ARCHITECTURE.md 갱신**

기술 부채 섹션 + 신규 컴포넌트 추가:

```markdown
## Technical Debt

- [x] ~~빌드 스크립트 python3 의존성~~ — 2026-03-24 해소
- [x] ~~CLAUDE.md docs/ 미반영~~ — 2026-03-24 해소
- [x] ~~bootstrap.sh python3 필수 요구~~ — 2026-03-24 해소
- [x] ~~SessionStart hook 토큰 과다~~ — 2026-03-24 해소
- [ ] `detect-language.sh` 빌드 타겟 미포함
- [ ] `.hxsk/templates/` 추적/비추적 경계 문서화 부족
```

**Step 6: Commit**

```bash
git add .hxsk/ARCHITECTURE.md .hxsk/STACK.md
git commit -m "docs: 기술 부채 해소 + 병렬 실행 인프라 반영"
```

---

## 실행 요약

```
Wave 1 (6개 병렬):   WKT-A  WKT-B  WKT-C  WKT-D  WKT-E  WKT-F
                       │                                    │
Wave 2 (3개 병렬):   WKT-G ─────────── WKT-H          WKT-I
                       │                 │               │
Wave 3 (2개 병렬):                  WKT-J            WKT-K
                                      │                │
Wave 4 (순차):                      VERIFY ────────────┘

총 커밋: 12개 (Wave별 atomic)
신규 파일: 6개
수정 파일: 8개
외부 종속성: 0
```

| Wave | 태스크 | 병렬 수 | 예상 시간 |
|------|--------|---------|-----------|
| 1 | WKT-A~F | 6 | 가장 긴 단일 태스크 기준 |
| 2 | WKT-G~I | 3 | WKT-G가 가장 큼 |
| 3 | WKT-J~K | 2 | 비슷한 크기 |
| 4 | VERIFY | 1 | 검증만 |
