#!/usr/bin/env bash
# backend-codex.sh — backend.sh's interface on the Codex CLI: each spawn/resume is one turn on the worker's thread.
#   spawn <name> <cwd> <model|""> <perm-mode> <prompt                 → prints job id (one per run)
#   resume <thread-id> <name> <cwd> <perm-mode> <model|""> <prompt     → prints job id
#   list                                   → one claude-agents-shaped JSON entry per run (no waitingFor)
#   stop <job-id>                          → stop that run (its supervisor, codex-turn.py and its app-server)
#   summarize <thread-id> [model]          → summary text from an ephemeral read-only fork
# resume takes the model too (backend.sh's does not): thread/resume would otherwise send the configured model.
# Fixed argument lists, no passthrough: registry.py is the only caller and passes the front's recorded mode, mapped
# here to a sandbox and an approval policy on every spawn and resume. A run is codex-turn.py driving a router-private
# `codex app-server` (stdio); the requests it asks are relayed to the front's /router:approve.
# Runs live in <registry dir>/codex/<job>/ (registry.py sets ROUTER_REGISTRY); codex-run.py supervises each one.
set -euo pipefail
RUN=$(dirname "$0")/codex-run.py
TURN=$(dirname "$0")/codex-turn.py
DIR=$(dirname "${ROUTER_REGISTRY:?backend-codex: ROUTER_REGISTRY not set}")/codex

# sandbox <mode> — Claude permission mode → Codex sandbox. danger-full-access only for bypassPermissions, which
# registry.py passes only when the front itself runs in it (never a mode a Codex run reported).
sandbox() {
    case "$1" in
    plan) echo read-only ;;
    default | acceptEdits | auto | dontAsk) echo workspace-write ;;
    bypassPermissions) echo danger-full-access ;;
    *) echo "backend-codex: bad permission mode '$1'" >&2; return 2 ;;
    esac
}

# approval <mode> — modes that ask before acting → on-request (each request goes to the front); the others never ask
approval() {
    case "$1" in
    default | acceptEdits | auto) echo on-request ;;
    *) echo never ;;
    esac
}

# check <what> <value> <regex> — ids and model names only, nothing flag-like
check() { [[ $2 =~ $3 ]] || { echo "backend-codex: bad $1 '$2'" >&2; exit 2; }; }
MODEL='^([A-Za-z0-9][A-Za-z0-9._:-]*)?$'
ID='^[0-9a-f][0-9a-f-]*$'

job() { od -An -N4 -tx1 /dev/urandom | tr -d ' \n'; }

cmd=${1:-}
shift || true
case "$cmd" in
spawn)
    [ $# -eq 4 ] || { echo "usage: backend-codex.sh spawn <name> <cwd> <model|\"\"> <perm-mode> <prompt" >&2; exit 2; }
    name=$1 cwd=$2 model=$3
    sb=$(sandbox "$4") || exit 2
    check model "$model" "$MODEL"
    j=$(job)
    cd "$cwd"
    python3 "$RUN" start "$DIR/$j" "$name" "" python3 "$TURN" "$DIR/$j" "$name" "$cwd" "$sb" "$(approval "$4")" "$model" ""
    ;;
resume)
    [ $# -eq 5 ] || { echo "usage: backend-codex.sh resume <thread-id> <name> <cwd> <perm-mode> <model|\"\"> <prompt" >&2; exit 2; }
    thread=$1 name=$2 cwd=$3 model=$5
    sb=$(sandbox "$4") || exit 2
    check model "$model" "$MODEL"
    check "thread id" "$thread" "$ID"
    j=$(job)
    cd "$cwd"
    python3 "$RUN" start "$DIR/$j" "$name" "$thread" \
        python3 "$TURN" "$DIR/$j" "$name" "$cwd" "$sb" "$(approval "$4")" "$model" "$thread"
    ;;
list) python3 "$RUN" list "$DIR" ;;
stop)
    check "job id" "${1:?job id}" '^[0-9a-f]+$'
    python3 "$RUN" stop "$DIR/$1"
    ;;
summarize)
    check "thread id" "${1:?thread id}" "$ID"
    check model "${2:-}" "$MODEL"
    codex exec fork --ephemeral --skip-git-repo-check -c 'sandbox_mode="read-only"' ${2:+-m "$2"} "$1" \
        "Summarize this session for a hand-off in at most 300 words: goal, decisions, current state, open issues, files touched." </dev/null
    ;;
*)
    sed -n '2,12p' "$0" >&2
    exit 2
    ;;
esac
