#!/usr/bin/env bash
# backend-codex.sh — backend.sh's interface on the Codex CLI: each spawn/resume is one `codex exec` run.
#   spawn <name> <cwd> <model|""> <perm-mode> <prompt                 → prints job id (one per run)
#   resume <thread-id> <name> <cwd> <perm-mode> <model|""> <prompt     → prints job id
#   list                                   → one claude-agents-shaped JSON entry per run (no waitingFor)
#   stop <job-id>                          → stop that run (its supervisor and codex exec)
#   summarize <thread-id> [model]          → summary text from an ephemeral read-only fork
# resume takes the model too (backend.sh's does not): `exec resume` sends the configured model on thread/resume.
# Fixed argument lists, no passthrough: registry.py is the only caller and passes the front's recorded mode, mapped
# here to a sandbox on every spawn and resume (`exec resume` has no -s, so `-c sandbox_mode=`). `codex exec` never
# asks for approval (it runs like dontAsk): no approval relay; a worker the sandbox stops reports `blocked`.
# Runs live in <registry dir>/codex/<job>/ (registry.py sets ROUTER_REGISTRY); codex-run.py supervises each one.
set -euo pipefail
RUN=$(dirname "$0")/codex-run.py
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
    python3 "$RUN" start "$DIR/$j" "$name" "" \
        codex exec --json -o "$DIR/$j/last.txt" -C "$cwd" -s "$sb" ${model:+-m "$model"} -
    ;;
resume)
    [ $# -eq 5 ] || { echo "usage: backend-codex.sh resume <thread-id> <name> <cwd> <perm-mode> <model|\"\"> <prompt" >&2; exit 2; }
    thread=$1 name=$2 cwd=$3 model=$5
    sb=$(sandbox "$4") || exit 2
    check model "$model" "$MODEL"
    check "thread id" "$thread" "$ID"
    j=$(job)
    cd "$cwd" # exec resume has no -C: the thread runs in the process cwd
    python3 "$RUN" start "$DIR/$j" "$name" "$thread" \
        codex exec resume --json -o "$DIR/$j/last.txt" -c "sandbox_mode=\"$sb\"" ${model:+-m "$model"} "$thread" -
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
