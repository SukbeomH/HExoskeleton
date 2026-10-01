# Hooks

훅은 Claude Code 플러그인 `hxsk`의 [`hooks/hooks.json`](../hooks/hooks.json)으로만 등록된다. 명령은 `"${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` 형태라 설치 위치와 무관하게 동작하고, 대상 프로젝트는 `CLAUDE_PROJECT_DIR`로 찾는다. 다른 하네스에서는 훅이 동작한다고 가정하지 않는다.

## 두 종류

- **가드·포맷 (항상 동작)**: 모든 프로젝트에 적용된다.
- **상태 훅 (opt-in)**: 프로젝트에 `.hxsk/` 디렉터리가 있을 때만 동작한다. 없으면 아무것도 쓰지 않고 exit 0 한다. `.hxsk/`는 `hxsk-init` 스킬(`scripts/init-project.sh`)이 만든다.

| 이벤트 (matcher) | 스크립트 | 종류 | 하는 일 |
|---|---|---|---|
| PreToolUse (Edit\|Write\|Read) | `file-protect.py` | 가드 | `.env`, 키·인증서 등 민감 파일 접근 차단 (exit 2) |
| PreToolUse (Write) | `write-guard.py` | 가드 | 기존 파일 덮어쓰기 차단 — 수정은 Edit |
| PreToolUse (Bash) | `bash-guard.py` | 가드 | `rm -rf` 등 파괴적 명령 차단 |
| PreToolUse (Edit) | `read-before-edit.py` | 상태 | 이번 세션에 Read 하지 않은 파일의 Edit 차단 (`.hxsk/` 없으면 허용) |
| PostToolUse (Read) | `track-read-history.py` | 상태 | Read 이력 기록 (`.hxsk/.read-history.log`) |
| PostToolUse (Edit\|Write) | `auto-format.sh` | 포맷 | qlty 또는 확장자별 포매터로 자동 포맷 |
| PostToolUse (Edit\|Write, Bash) | `track-modifications.sh` | 상태 | 변경 플래그와 이번 턴의 변경 로그 (`.hxsk/.track-modifications.log`) |
| SessionStart (startup\|resume) | `session-start.sh` | 상태 | STATE/HANDOFF 등 작업 상태를 컨텍스트로 주입 |
| PreCompact (auto\|manual) | `pre-compact-save.sh` | 상태 | 압축 전 상태 문서 백업 |
| Stop | `post-turn-verify.sh` | 포맷 + 상태 | 변경 파일 CRLF 정리·lint 경고는 항상, "완료" 선언에 검증 실행 기록이 없을 때의 경고는 `.hxsk/`에서만 |
| Stop | `stop-context-save.sh` | 상태 | `CURRENT.md` 스냅샷만 다시 씀(`STATE.md`·`SESSION_HANDOFF.md`는 없을 때 템플릿으로 만들 뿐 이후 건드리지 않음), session-summary 메모리 저장, 메모리 prune |
| Stop | `collect-rationalization.sh` | 상태 | Iron Law 위반 시그널 수집 |

`_json_parse.sh`(jq → python3 → node 순 JSON 파서)와 `compact-context.sh`는 훅이 내부적으로 쓰는 헬퍼다.

## 규칙

- 차단은 exit 2 + stderr 메시지. 그 외 실패는 작업을 막지 않는다(exit 0).
- 런타임 파일(`.hxsk/*.log`, 플래그, 백업)은 `.hxsk/.gitignore`(템플릿 `templates/hxsk.gitignore`)가 무시한다.
- 훅을 추가·수정하면 `tests/hooks-smoke.sh`에 `.hxsk/` 유무 두 경우를 모두 넣고 `scripts/verify.sh`로 확인한다.
