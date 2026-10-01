#!/usr/bin/env bash
# hooks/hooks.json 에 연결된 훅 스모크 테스트.
# - 가드(file-protect/write-guard/bash-guard)는 .hxsk/ 유무와 무관하게 차단
# - 상태 훅은 opt-in: .hxsk/ 없는 프로젝트에서는 아무것도 만들지 않고 exit 0
# Usage: bash tests/hooks-smoke.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

mkproj() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init; }
NO="$TMP/no-hxsk"; HX="$TMP/hxsk"
mkproj "$NO"; mkproj "$HX"; mkdir -p "$HX/.hxsk"
printf '# Handoff\nnext: smoke\n' > "$HX/.hxsk/SESSION_HANDOFF.md"
printf '# State\nphase: smoke\n' > "$HX/.hxsk/STATE.md"
echo existing > "$HX/existing.txt"; echo existing > "$NO/existing.txt"

# run <project> <hook> <stdin-json> → 표준출력은 $OUT, 종료코드 반환
run() { OUT=$(cd "$1" && CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$1" "$ROOT/hooks/$2" <<<"$3" 2>/dev/null); }
expect() { # expect <label> <want> <got>
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want $2, got $3)"; FAILS=$((FAILS + 1)); fi
}

for P in "$NO" "$HX"; do
    tag=$([ "$P" = "$NO" ] && echo no-hxsk || echo hxsk)
    run "$P" file-protect.py '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'/.env"}}'; expect "$tag file-protect .env" 2 $?
    run "$P" file-protect.py '{"tool_name":"Read","tool_input":{"file_path":"'"$P"'/.env.example"}}'; expect "$tag file-protect .env.example" 0 $?
    run "$P" write-guard.py '{"tool_name":"Write","tool_input":{"file_path":"'"$P"'/existing.txt"}}'; expect "$tag write-guard existing" 2 $?
    run "$P" write-guard.py '{"tool_name":"Write","tool_input":{"file_path":"'"$P"'/new.txt"}}'; expect "$tag write-guard new" 0 $?
    run "$P" bash-guard.py '{"tool_name":"Bash","tool_input":{"command":"rm -rf build"}}'; expect "$tag bash-guard rm -rf" 2 $?
    run "$P" bash-guard.py '{"tool_name":"Bash","tool_input":{"command":"ls"}}'; expect "$tag bash-guard ls" 0 $?
    run "$P" auto-format.sh '{"tool_name":"Edit","tool_input":{"file_path":"'"$P"'/existing.txt"}}'; expect "$tag auto-format" 0 $?
    run "$P" post-turn-verify.sh '{}'; expect "$tag post-turn-verify" 0 $?
done

# ── .hxsk/ 없음: 상태 훅은 no-op, read-before-edit 는 허용 ──
EDIT='{"tool_name":"Edit","tool_input":{"file_path":"'"$NO"'/existing.txt"}}'
run "$NO" read-before-edit.py "$EDIT"; expect "no-hxsk read-before-edit allows" 0 $?
run "$NO" track-read-history.py '{"tool_name":"Read","tool_input":{"file_path":"'"$NO"'/existing.txt"}}'; expect "no-hxsk track-read-history" 0 $?
run "$NO" track-modifications.sh "$EDIT"; expect "no-hxsk track-modifications" 0 $?
run "$NO" session-start.sh '{"source":"startup"}'; expect "no-hxsk session-start" 0 $?; expect "no-hxsk session-start silent" "" "$OUT"
run "$NO" collect-rationalization.sh 'this should work'; expect "no-hxsk collect-rationalization" 0 $?
run "$NO" pre-compact-save.sh '{}'; expect "no-hxsk pre-compact-save" 0 $?
run "$NO" stop-context-save.sh '{}'; expect "no-hxsk stop-context-save" 0 $?
expect "no-hxsk .hxsk/ not created" no "$([ -e "$NO/.hxsk" ] && echo yes || echo no)"

# ── .hxsk/ 있음: 상태 기록 + read-before-edit 차단/허용 ──
EDIT='{"tool_name":"Edit","tool_input":{"file_path":"'"$HX"'/existing.txt"}}'
run "$HX" session-start.sh '{"source":"startup"}'; expect "hxsk session-start" 0 $?
expect "hxsk session-start context" yes "$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print("yes" if "smoke" in d["hookSpecificOutput"]["additionalContext"] else "no")' "$OUT" 2>/dev/null)"
run "$HX" read-before-edit.py "$EDIT"; expect "hxsk read-before-edit blocks unread" 2 $?
run "$HX" track-read-history.py '{"tool_name":"Read","tool_input":{"file_path":"'"$HX"'/existing.txt"}}'; expect "hxsk track-read-history" 0 $?
run "$HX" read-before-edit.py "$EDIT"; expect "hxsk read-before-edit allows after read" 0 $?
run "$HX" track-modifications.sh "$EDIT"; expect "hxsk track-modifications flag" yes "$([ -f "$HX/.hxsk/.modified-this-session" ] && echo yes || echo no)"
LOG="$HX/.hxsk/.track-modifications.log"
has() { grep -q "$1" "$2" 2>/dev/null && echo yes || echo no; }
expect "hxsk track-modifications logs Edit path" yes "$(has $'\tEdit\t'"$HX/existing.txt"'$' "$LOG")"

# post-turn-verify: 코드 변경 + 완료 선언 + 이번 턴 Bash 기록 없음 → 경고, Bash 기록 후 → 조용
echo 'x' >"$HX/app.js"
STOP='{"hook_event_name":"Stop","last_assistant_message":"모두 완료했습니다"}'
warns() { (cd "$HX" && CLAUDE_PROJECT_DIR="$HX" "$ROOT/hooks/post-turn-verify.sh" <<<"$STOP" 2>&1 >/dev/null) | grep -c 'NO COMPLETION WITHOUT VERIFICATION'; }
expect "hxsk post-turn-verify warns without Bash evidence" 1 "$(warns)"
run "$HX" track-modifications.sh '{"tool_name":"Bash","tool_input":{"command":"npm test\n  --ci"}}'
expect "hxsk track-modifications logs Bash command (one line)" yes "$(has $'\tBash\tnpm test   --ci$' "$LOG")"
expect "hxsk post-turn-verify quiet with Bash evidence" 0 "$(warns)"

# post-turn-verify: 변경된 CRLF 스크립트를 LF 로 (GNU/BSD sed 공통), 실행 비트 유지
printf 'echo hi\r\n' >"$HX/crlf.sh" && chmod +x "$HX/crlf.sh"
run "$HX" post-turn-verify.sh '{}'
expect "post-turn-verify strips CRLF" no "$(has $'\r' "$HX/crlf.sh")"
expect "post-turn-verify keeps exec bit" yes "$([ -x "$HX/crlf.sh" ] && echo yes || echo no)"
run "$HX" collect-rationalization.sh 'this should work'; expect "hxsk collect-rationalization log" yes "$([ -s "$HX/.hxsk/.rationalization-patterns.log" ] && echo yes || echo no)"
run "$HX" pre-compact-save.sh '{}'; expect "hxsk pre-compact-save backup" yes "$([ -f "$HX/.hxsk/STATE.md.pre-compact.bak" ] && echo yes || echo no)"
run "$HX" stop-context-save.sh '{}'; expect "hxsk stop-context-save" 0 $?
for _ in $(seq 50); do ls "$HX"/.hxsk/memories/session-summary/*.md >/dev/null 2>&1 && break; sleep 0.2; done
expect "hxsk stop-context-save CURRENT.md" yes "$([ -f "$HX/.hxsk/CURRENT.md" ] && echo yes || echo no)"
expect "hxsk stop-context-save session-summary" yes "$(ls "$HX"/.hxsk/memories/session-summary/*.md >/dev/null 2>&1 && echo yes || echo no)"

# Stop 스냅샷(active-state.sh stop)은 CURRENT.md 만 다시 쓴다 — 손으로 고친 STATE.md / SESSION_HANDOFF.md 는 그대로
printf -- '---\nupdated: 2020-01-01\n---\n## Last Action\n- hand edit\n## Next Steps\n1. mine\n' >"$HX/.hxsk/STATE.md"
printf '# Handoff\nnext: hand edit\n' >"$HX/.hxsk/SESSION_HANDOFF.md"
echo stale >"$HX/.hxsk/CURRENT.md"
cp "$HX/.hxsk/STATE.md" "$TMP/state.before" && cp "$HX/.hxsk/SESSION_HANDOFF.md" "$TMP/handoff.before"
(cd "$HX" && CLAUDE_PROJECT_DIR="$HX" bash "$ROOT/scripts/active-state.sh" stop >/dev/null 2>&1)
same() { cmp -s "$1" "$2" && echo yes || echo no; }
expect "stop snapshot keeps hand-edited STATE.md" yes "$(same "$TMP/state.before" "$HX/.hxsk/STATE.md")"
expect "stop snapshot keeps hand-edited SESSION_HANDOFF.md" yes "$(same "$TMP/handoff.before" "$HX/.hxsk/SESSION_HANDOFF.md")"
expect "stop snapshot regenerates CURRENT.md" yes "$(has '^## Session Narrative' "$HX/.hxsk/CURRENT.md")"

[ "$FAILS" -eq 0 ] && echo "PASS: hooks smoke" || { echo "FAIL: $FAILS hook checks"; exit 1; }
