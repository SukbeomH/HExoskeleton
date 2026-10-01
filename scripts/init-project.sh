#!/usr/bin/env bash
# init-project.sh — 프로젝트에 HXSK 작업 상태(.hxsk/)를 만든다. 기존 파일은 덮어쓰지 않는다(멱등).
# Usage: scripts/init-project.sh [--skills] <project-dir>
#   --skills  skills/ 를 <project>/.agents/skills/ 로 복사 (Codex/Copilot/Cursor/Antigravity/Devin/OpenCode).
#             이 복사본은 재실행 시 갱신된다(= 업그레이드). 플러그인 사용자는 `claude plugin update hxsk@hexoskeleton`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS=0
if [ "${1:-}" = "--skills" ]; then SKILLS=1; shift; fi
DIR="$(cd "${1:?Usage: init-project.sh [--skills] <project-dir>}" && pwd)"
HX="$DIR/.hxsk"

put() { # put <template> <path under .hxsk/> — 없을 때만 생성
    if [ -e "$HX/$2" ]; then echo "[OK]  .hxsk/$2"; else cp "$ROOT/templates/$1" "$HX/$2" && echo "[NEW] .hxsk/$2"; fi
}

mkdir -p "$HX/memories"
put spec.md SPEC.md
put patterns.md PATTERNS.md
put context-config.yaml context-config.yaml
put hxsk.gitignore .gitignore
for f in CURRENT STATE SESSION_HANDOFF VERIFICATION; do [ -e "$HX/$f.md" ] && echo "[OK]  .hxsk/$f.md" || echo "[NEW] .hxsk/$f.md"; done
CLAUDE_PROJECT_DIR="$DIR" bash "$ROOT/scripts/active-state.sh" ensure # 없는 상태 파일만 생성

if [ "$DIR" -ef "$ROOT" ]; then
    echo "[OK]  AGENTS.md (HXSK repo itself — contributor guide, no block)"
elif grep -qs '<!-- hxsk -->' "$DIR/AGENTS.md"; then
    echo "[OK]  AGENTS.md HXSK block"
else
    [ -s "$DIR/AGENTS.md" ] && echo >>"$DIR/AGENTS.md"
    cat >>"$DIR/AGENTS.md" <<'EOF'
<!-- hxsk -->
## HXSK (HExoskeleton)
- Workflow: SPEC.md → PLAN.md → EXECUTE → VERIFY. Working state lives in `.hxsk/`; resume from `.hxsk/SESSION_HANDOFF.md` and `.hxsk/STATE.md`.
- Skills: `planner` → `plan-checker` → `executor` → `verifier`; store/recall project memory with `memory-protocol` (`.hxsk/memories/`).
- Paths inside a skill (`scripts/…`, `references/…`, `../<other-skill>/…`) are relative to that skill's directory.
- No completion claim without executed verification evidence, recorded in `.hxsk/VERIFICATION.md`.
<!-- /hxsk -->
EOF
    echo "[NEW] AGENTS.md HXSK block"
fi

if [ "$SKILLS" = 1 ]; then
    if [ "$DIR/.agents/skills" -ef "$ROOT/skills" ]; then
        echo "[OK]  .agents/skills (already the HXSK skills directory)"
    else
        mkdir -p "$DIR/.agents/skills"
        cp -R "$ROOT/skills/." "$DIR/.agents/skills/"
        echo "[SYNC] .agents/skills ← $ROOT/skills"
    fi
fi
