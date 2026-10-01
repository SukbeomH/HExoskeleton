#!/usr/bin/env bash
# active-state.sh — HXSK canonical active-state surface 보장 및 최신 snapshot 갱신
# ensure: 없는 상태 파일만 템플릿으로 생성. stop: CURRENT.md(자동 스냅샷)만 다시 쓴다.
# STATE.md / SESSION_HANDOFF.md / VERIFICATION.md 는 사람·에이전트가 관리하며, 생성 후에는 건드리지 않는다.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HXSK_DIR="$PROJECT_DIR/.hxsk"
TEMPLATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates"
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
- `CURRENT.md` 는 Stop 훅이 매 턴 다시 쓰는 local snapshot 이므로 same-worktree 병렬 writer 를 허용하지 않습니다.

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
}

ensure_handoff() {
    [[ -f "$HANDOFF_FILE" ]] && return 0
    if [[ -f "$TEMPLATES_DIR/session_handoff.md" ]]; then
        cp "$TEMPLATES_DIR/session_handoff.md" "$HANDOFF_FILE"
    else
        cat > "$HANDOFF_FILE" <<'EOF'
# Session Handoff

## Resume Order
1. `AGENTS.md`
2. `.hxsk/CURRENT.md`
3. `.hxsk/STATE.md`
4. `.hxsk/VERIFICATION.md`
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

write_runtime_snapshot() {
    local key="$1"
    local dir="$RUNTIME_DIR/$key"
    mkdir -p "$dir"
    cp "$CURRENT_FILE" "$dir/CURRENT.md"
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

    python3 - "$CURRENT_FILE" "$ts" "$branch" "$file_count" "$main_dirs" "$last_commit" "$task" "$modified" "$recent_commits" "$diff_stat" <<'PY'
from pathlib import Path
import sys
current_path = Path(sys.argv[1])
ts, branch, file_count, main_dirs, last_commit, task, modified, recent_commits, diff_stat = sys.argv[2:11]
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

current_path.write_text(current_text)
PY

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
