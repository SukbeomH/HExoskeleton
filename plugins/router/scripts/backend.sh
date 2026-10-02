#!/usr/bin/env bash
# backend.sh — the only file that talks to the session backend (Claude Code CLI).
# Replace this file to run workers on another backend (e.g. Orca); keep the interface.
#   spawn <name> <cwd> [model] [perm-mode] [extra claude args...] <prompt  → prints job id
#   resume <session-uuid> <name> <cwd> [extra args, only if removed] <prompt → prints job id
#   list                                   → claude agents --json --all
#   stop <job-id>                          → stop a background session
#   summarize <session-uuid> [model]       → summary text from a forked headless resume
# Pass "" to skip an optional positional (e.g. model) and still give later ones.
# spawn/resume: prompt on stdin (registry.py composes it); stdout is only the job id, hints go to stderr.
set -euo pipefail

# job_id <claude output> — "backgrounded · <id> · <name>" (other lines go to stderr)
job_id() {
    local id
    id=$(sed -n 's/^backgrounded [^ ]* \([0-9a-f][0-9a-f]*\).*/\1/p' <<<"$1" | head -1)
    grep -v '^backgrounded ' <<<"$1" >&2 || true
    [ -n "$id" ] || { echo "backend: no job id in claude output" >&2; return 1; }
    echo "$id"
}

cmd=${1:-}
shift || true
case "$cmd" in
spawn)
    [ $# -ge 2 ] || { echo "usage: backend.sh spawn <name> <cwd> [model] [perm-mode] [args...] <prompt" >&2; exit 2; }
    name=$1 cwd=$2 model=${3:-} mode=${4:-} prompt=$(cat)
    shift $(($# < 4 ? $# : 4))
    args=(--bg --name "$name" --agent router:topic-worker)
    [ -z "$model" ] || args+=(--model "$model")
    [ -z "$mode" ] || args+=(--permission-mode "$mode")
    out=$(cd "$cwd" && claude "${args[@]}" "$@" "$prompt" </dev/null 2>&1) || { echo "$out" >&2; exit 1; }
    job_id "$out"
    ;;
resume)
    [ $# -ge 3 ] || { echo "usage: backend.sh resume <session-uuid> <name> <cwd> [args...] <prompt" >&2; exit 2; }
    sid=$1 name=$2 cwd=$3 prompt=$(cat)
    shift 3
    # Still listed → wake it in place with its saved options (any flag would start a copy instead).
    # Removed from the list → nothing is saved, so restate the name (SendMessage addresses by name).
    flags=()
    listed=$(claude agents --json --all 2>/dev/null </dev/null) # capture first: grep -q in a pipe can SIGPIPE claude
    grep -q "$sid" <<<"$listed" || flags=(--name "$name" "$@")
    out=$(cd "$cwd" && claude --resume "$sid" --bg ${flags[@]+"${flags[@]}"} "$prompt" </dev/null 2>&1) || { echo "$out" >&2; exit 1; }
    job_id "$out"
    ;;
list) claude agents --json --all ;;
stop) claude stop "${1:?job id}" ;;
summarize)
    claude -p --resume "${1:?session uuid}" --fork-session ${2:+--model "$2"} \
        "Summarize this session for a hand-off in at most 300 words: goal, decisions, current state, open issues, files touched." </dev/null
    ;;
*)
    sed -n '2,10p' "$0" >&2
    exit 2
    ;;
esac
