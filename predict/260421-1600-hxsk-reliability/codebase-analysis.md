# HXSK Reliability Predict — Codebase Analysis

**Session**: 260421-1600-hxsk-reliability  
**Scope**: `.hxsk/scripts/` + `.hxsk/hooks/`

---

## Scripts Analyzed

| File | Lines | Shell Standard | set flags | Key Concerns |
|------|-------|---------------|-----------|--------------|
| `md-store-memory.sh` | 132 | `env bash` | `-uo pipefail` | TYPE_DIR redirect, YAML inject, missing -e |
| `md-recall-memory.sh` | 126 | `env bash` | `-uo pipefail` | head-100 cap, fallback no marker, sed early exit, missing -e |
| `prune-tick.sh` | 76 | `env bash` | `-euo pipefail` | SIGKILL stale lock |
| `prune-memories.sh` | 296 | `env bash` | `set -euo pipefail` | source config, awk over-match, exit 2 |
| `bootstrap.sh` | 459 | `env bash` | `set -euo pipefail` | .env auto-copy, merge.ours.driver silent |
| `check-consistency.sh` | 481 | `env bash` | `set -euo pipefail` | python3 hook pattern miss, lowercase placeholder miss |
| `pre-compact-save.sh` | 100 | `/bin/bash` | `set -euo pipefail` | shebang inconsistent, python3 silent fail |
| `stop-context-save.sh` | 168 | `env bash` | `set -euo pipefail` | flag delete race, mtime ordering |

---

## Common Patterns

### CLAUDE_PROJECT_DIR Usage (모든 스크립트 공통)
```bash
MEMORIES_DIR="${CLAUDE_PROJECT_DIR:-.}/.hxsk/memories"
```
미설정 시 `.` (현재 디렉토리) 폴백. CI/서브에이전트 환경에서 CWD != 프로젝트 루트 가능.

### Lock Pattern (prune-tick.sh)
```bash
mkdir "$LOCK_DIR" || exit 0
trap 'rmdir "$LOCK_DIR"' EXIT
```
SIGKILL 취약. flock(1) 또는 mtime 기반 stale 감지로 교체 권장.

### Memory Path Structure
```
.hxsk/memories/
  architecture-decision/
  bug-root-cause/
  pattern/
  session-end/
  lessons-learned/
    A/  B/  C/  D/  E/
  general/           ← TYPE_DIR fallback 목적지
```

---

## Signal Quality Metrics

| 메트릭 | 값 | 해석 |
|--------|-----|------|
| Scripts with missing -e | 2/8 | 25% — 개선 여지 |
| Scripts with CLAUDE_PROJECT_DIR check | 0/8 | 0% — systemic risk |
| Scripts with explicit error output | 3/8 | 37% — 대부분 조용한 실패 |
| Hard-coded caps | 1 (`head -100`) | 검색 범위 제한 |
