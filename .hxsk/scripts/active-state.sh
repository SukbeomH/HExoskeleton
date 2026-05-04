#!/usr/bin/env bash
# active-state.sh — HXSK canonical active-state surface 보장 및 최신 snapshot 갱신
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
TEMPLATES_DIR="$HXSK_DIR/templates"
RUNTIME_DIR="$HXSK_DIR/runtime/session-snapshots"
CURRENT_FILE="$HXSK_DIR/CURRENT.md"
STATE_FILE="$HXSK_DIR/STATE.md"
HANDOFF_FILE="$HXSK_DIR/SESSION_HANDOFF.md"
VERIFICATION_FILE="$HXSK_DIR/VERIFICATION.md"

usage() {
    echo "Usage: $0 {ensure|stop|status}" >&2
    exit 1
}

iso_date() { date '+%Y-%m-%d'; }
ts_human() { date '+%Y-%m-%d %H:%M:%S'; }

session_key() {
    local base
    base="${HXSK_SESSION_ID:-${CLAUDE_SESSION_ID:-}}"
    if [[ -n "$base" ]]; then
        echo "$base"
    else
        printf '%s-%s' "$(date '+%Y%m%d-%H%M%S')" "$$"
    fi
}

ensure_current() {
    [[ -f "$CURRENT_FILE" ]] && return 0
    if [[ -f "$TEMPLATES_DIR/current.md" ]]; then
        cp "$TEMPLATES_DIR/current.md" "$CURRENT_FILE"
    else
        cat > "$CURRENT_FILE" <<'EOF'
# Current Session Context

## Active Task
- None yet.

## Working Files
- None yet.

## Decisions Made
- None yet.

## Blockers
- None.
EOF
    fi
}

ensure_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<'EOF'
---
updated: __ISO_DATE__
owner: master
status: maintain
---

# Project State

## Active Gate
plan: ""
parent_issue: ""
current_gate: ""
sub_issues: []
forge: ""

## Active Dispatcher
master: ""
status: ""
tasks: []

## Current Position
- **Milestone:** —
- **Phase:** —
- **Status:** maintain
- **Plan:** Define the first SPEC/PLAN pair.

## Last Action
- None — freshly initialized.

## Next Steps
1. Define project spec in `.hxsk/SPEC.md`
2. Create plan in `PLAN.md`
3. Run verification before completion claims

## Canonical Active Docs
- `SPEC.md` — 목표/제약/성공 기준
- `CURRENT.md` — 현재 세션 서사와 최근 실행 문맥
- `STATE.md` — 구조화된 현재 상태 / gate / blockers / next checkpoint
- `SESSION_HANDOFF.md` — 다음 세션 재진입용 최소 handoff
- `VERIFICATION.md` — 검증 truth / evidence / verdict

## Blockers
- 없음

## Concerns
- `CURRENT.md` / `SESSION_HANDOFF.md` 는 latest local snapshot 이므로 same-worktree 병렬 writer 를 허용하지 않습니다.

## History
<!-- Format: - YYYY-MM-DD branch-or-plan: #issue -> result -->
EOF
        python3 - "$STATE_FILE" "$(iso_date)" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
iso = sys.argv[2]
path.write_text(path.read_text().replace('__ISO_DATE__', iso))
PY
        return 0
    fi

    python3 - "$STATE_FILE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
if '## Active Gate' not in text:
    insert = '''## Active Gate
plan: ""
parent_issue: ""
current_gate: ""
sub_issues: []
forge: ""

## Active Dispatcher
master: ""
status: ""
tasks: []

'''
    marker = '# Project State\n\n'
    if marker in text:
        text = text.replace(marker, marker + insert, 1)
    else:
        text = insert + text
if '## History' not in text:
    text = text.rstrip() + '\n\n## History\n<!-- Format: - YYYY-MM-DD branch-or-plan: #issue -> result -->\n'
path.write_text(text)
PY
}

ensure_handoff() {
    [[ -f "$HANDOFF_FILE" ]] && return 0
    if [[ -f "$TEMPLATES_DIR/session_handoff.md" ]]; then
        cp "$TEMPLATES_DIR/session_handoff.md" "$HANDOFF_FILE"
    else
        cat > "$HANDOFF_FILE" <<'EOF'
# Session Handoff

## Resume Order
1. `llms.txt`
2. `AGENTS.md`
3. `.hxsk/CURRENT.md`
4. `.hxsk/STATE.md`
5. `.hxsk/VERIFICATION.md`
EOF
    fi
}

ensure_verification() {
    [[ -f "$VERIFICATION_FILE" ]] && return 0
    cat > "$VERIFICATION_FILE" <<'EOF'
# Verification

## Summary
- No verification recorded yet.
- Treat this file as the current truth / evidence / verdict surface.

## Latest Checks
- No checks executed yet.

## Verdict
- PENDING
EOF
}

ensure_all() {
    mkdir -p "$HXSK_DIR" "$RUNTIME_DIR"
    ensure_current
    ensure_state
    ensure_handoff
    ensure_verification
}

update_state_metadata() {
    local branch="$1"
    local task="$2"
    python3 - "$STATE_FILE" "$branch" "$task" "$(iso_date)" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
branch, task, updated = sys.argv[2], sys.argv[3], sys.argv[4]
text = path.read_text()
text = re.sub(r'(?m)^updated:\s*.*$', f'updated: {updated}', text)
if '## Last Action' in text:
    text = re.sub(r'## Last Action\n(?:- .*\n)?', f'## Last Action\n- Latest local snapshot captured from `{branch}` — {task}.\n', text, count=1)
if '## Next Steps' in text:
    text = re.sub(r'## Next Steps\n(?:.*\n){0,4}', '## Next Steps\n1. Continue from `.hxsk/SESSION_HANDOFF.md` immediate next action\n2. Re-run verification before completion claims\n3. Use a fresh worktree for concurrent execution slices\n', text, count=1)
path.write_text(text)
PY
}

write_runtime_snapshot() {
    local key="$1"
    local dir="$RUNTIME_DIR/$key"
    mkdir -p "$dir"
    cp "$CURRENT_FILE" "$dir/CURRENT.md"
    cp "$HANDOFF_FILE" "$dir/SESSION_HANDOFF.md"
}

stop_snapshot() {
    ensure_all

    local ts branch modified diff_stat recent_commits file_count file_list main_dirs last_commit task key
    ts="${ACTIVE_STATE_TS:-$(ts_human)}"
    branch="${ACTIVE_STATE_BRANCH:-$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo unknown)}"
    modified="${ACTIVE_STATE_MODIFIED:-$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -30)}"
    diff_stat="${ACTIVE_STATE_DIFF_STAT:-$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -5)}"
    recent_commits="${ACTIVE_STATE_RECENT_COMMITS:-$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null || true)}"
    file_count=$(printf '%s\n' "$modified" | grep -c '.' 2>/dev/null || echo 0)
    file_list=$(printf '%s\n' "$modified" | sed 's/^[[:space:]MADRC?]*//' | head -10)
    main_dirs=$(printf '%s\n' "$file_list" | xargs -I{} dirname {} 2>/dev/null | sort -u | head -3 | tr '\n' ', ' | sed 's/,$//')
    last_commit=$(printf '%s\n' "$recent_commits" | head -1 | sed 's/^[a-f0-9]* //')
    task="${last_commit:-Ongoing development}"
    key="$(session_key)"

    python3 - "$CURRENT_FILE" "$HANDOFF_FILE" "$ts" "$branch" "$file_count" "$main_dirs" "$last_commit" "$task" "$modified" "$recent_commits" "$diff_stat" "$key" <<'PY'
from pathlib import Path
import sys
current_path = Path(sys.argv[1])
handoff_path = Path(sys.argv[2])
ts, branch, file_count, main_dirs, last_commit, task, modified, recent_commits, diff_stat, key = sys.argv[3:13]
main_dirs = main_dirs or 'the project'
last_commit_sentence = f'The recent work involved: "{last_commit}".' if last_commit else ''
current_text = f'''# Current Session Context

## Session Scope
- **Latest Snapshot Owner**: local worktree
- **Parallel Rule**: same-worktree concurrent writers are unsupported; use a fresh worktree per execution slice.

## Session Narrative
> On {ts}, the developer was working on the **{branch}** branch, modifying {file_count} files across `{main_dirs}`. {last_commit_sentence}

## Context Snapshot
- **Active Task**: {task}
- **Branch**: {branch}
- **Files Changed**: {file_count}
- **Last Updated**: {ts}

## Working Files
```
{modified or 'No changes detected'}
```

## Recent Commits
```
{recent_commits or 'No recent commits'}
```

## Diff Stats
```
{diff_stat or 'No diff available'}
```
'''

handoff_text = f'''---
updated: {ts.split()[0]}
branch: {branch}
next_owner: next-session
session_key: {key}
---

# Session Handoff

## Resume Order
1. `llms.txt`
2. `AGENTS.md`
3. `.hxsk/CURRENT.md`
4. `.hxsk/STATE.md`
5. `.hxsk/VERIFICATION.md`
6. 필요 시 `.hxsk/DECISIONS.md`, `.hxsk/PATTERNS.md`, `.hxsk/memories/`

## Last Stable Context
- 브랜치: `{branch}`
- 상태: latest local snapshot stored for the canonical active-state surface
- 태스크: {task}
- 세션 키: `{key}`

## Immediate Next Action
- `.hxsk/CURRENT.md` 와 `.hxsk/STATE.md`를 읽고, 필요한 경우 새 worktree에서 다음 execution slice를 여십시오.

## Verification Pointer
- 기본 검증: `bash .hxsk/scripts/local-verify.sh`
- 문서/설정 점검: `bash .hxsk/scripts/doc-lint.sh && bash .hxsk/hooks/check-consistency.sh`

## Notes
- 이 파일은 latest local handoff snapshot 입니다.
- 병렬 작업은 same-worktree writer 대신 worktree 분리로 운영하십시오.
'''
current_path.write_text(current_text)
handoff_path.write_text(handoff_text)
PY

    update_state_metadata "$branch" "$task"
    write_runtime_snapshot "$key"
}

status_cmd() {
    ensure_all
    printf 'CURRENT=%s\nSTATE=%s\nHANDOFF=%s\nVERIFICATION=%s\n' \
        "$CURRENT_FILE" "$STATE_FILE" "$HANDOFF_FILE" "$VERIFICATION_FILE"
}

case "${1:-}" in
    ensure) ensure_all ;;
    stop) stop_snapshot ;;
    status) status_cmd ;;
    *) usage ;;
esac
