# Harness Adapters

HXSK 메모리 prune 정책을 Claude Code 외의 에이전트 하네스에서도 활성화하는 방법.

## 우선순위

1. **자동 발화 (기본)** — `md-store-memory.sh`, `md-recall-memory.sh`, `bootstrap.sh`가 호출되면 내부 `prune-tick.sh`가 opportunistic하게 실행됨. **어떤 하네스에서도 기본 동작**. 추가 설정 불필요.

2. **하네스별 명시적 훅 (선택)** — 아래 표를 참고해 하네스가 제공하는 훅 시스템에 `prune-memories.sh --auto`를 등록하면 Stop/PreCompact 이벤트에서도 정리.

3. **git 훅 (폴백)** — 하네스가 훅을 지원하지 않거나 메모리 툴을 건너뛰는 경우(Aider, Continue.dev, Antigravity 등)에 `.hxsk/githooks/` 설치로 커밋 시 정리.

## 하네스별 어댑터

| 하네스 | 설정 파일 | 발화 이벤트 | 비고 |
|---|---|---|---|
| **Claude Code** | `.claude/settings.json` | Stop, PreCompact | 이미 통합됨 (.hxsk/hooks/stop-context-save.sh 등) |
| **Cursor 1.7+** | `.cursor/hooks.json` | stop, preCompact | [cursor-hooks.json](cursor-hooks.json) 복사 |
| **Gemini CLI** | `~/.gemini/settings.json` 또는 프로젝트 `.gemini/settings.json` | SessionEnd, PreCompress | [gemini-settings.json](gemini-settings.json) 참고 |
| **GitHub Copilot CLI** | `.copilot/hooks.json` | sessionEnd, agentStop | [copilot-hooks.json](copilot-hooks.json) 참고 |
| **Windsurf Cascade** | `.windsurf/hooks.json` | post_cascade_response | SessionEnd·PreCompact 부재, 턴 종료로 대체 |
| **OpenCode** | `~/.config/opencode/plugin/hxsk.ts` (JS 플러그인) | session.idle, session.compacting | 순수 bash 불가, 얇은 JS wrapper 필요 |
| **OpenAI Codex CLI** | `.codex/hooks.json` (`codex_hooks=true` 필요) + `.hxsk/githooks/pre-push` | stop, git pre-push | PreCompact 없음. 프로젝트 공용 `.codex/hooks.json` 제공 |
| **Hermes Agent** | `.hxsk/adapters/hermes/README.md` | Hermes tool/session lifecycle를 repo-local 문서 surface로 매핑 | 훅 파일보다 read order / memory split / verification discipline 이 핵심 |
| **Aider / Continue / Antigravity** | (lifecycle 훅 미지원) | — | git 훅 폴백 사용 |

## 설치 (선택)

해당 하네스의 설정 파일 위치에 `.hxsk/adapters/<harness>.json`을 복사하거나 병합하세요.

```bash
# Cursor 예시
mkdir -p .cursor
cp .hxsk/adapters/cursor-hooks.json .cursor/hooks.json

# Codex 예시 (프로젝트 공용 hooks.json + 로컬 검증 git hook)
bash .hxsk/scripts/install.sh --harness codex
# Codex 전역 설정에서 codex_hooks=true 활성 필요

# git 훅 폴백 (모든 하네스 공통)
git config core.hooksPath .hxsk/githooks
```

## 설계 근거

- **Opportunistic tick**: 메모리 툴(`md-*`)은 하네스와 무관하게 스킬에서 호출되므로 여기 붙이면 자연 발화
- **Cooldown + atomic lock**: `prune-tick.sh`가 60초 cooldown과 `mkdir` atomic lock을 내장해 스팸·race 방지
- **git 훅**: `core.hooksPath`로 리포지토리 내부 훅 관리, Husky 불필요
- **OS 스케줄러 제외**: launchd/cron/systemd는 크로스 플랫폼·외부 종속성 측면에서 HXSK 원칙(순수 bash + 외부 종속성 0)에 위배

## Hermes Agent Bridge

Hermes는 HXSK에 대해 별도 hook 파일을 강하게 요구하지 않는다. 대신 다음 매핑을 고정한다.

- **Entry order**: `llms.txt` → `AGENTS.md` → `.hxsk/CURRENT.md` → `.hxsk/STATE.md` → `.hxsk/VERIFICATION.md`
- **Long-form memory**: Hermes built-in memory는 짧은 포인터만, canonical long-form context는 `.hxsk/memories/`
- **Task tracking**: Hermes `todo`는 세션 큐, `.hxsk/TODO.md`는 repo backlog
- **Recall**: 과거 repo 판단은 `md-recall-memory.sh`, cross-session chat recall은 Hermes `session_search`
- **Verification**: 완료 판정은 항상 repo-local verification command와 artifact 기준

상세는 [`hermes/README.md`](hermes/README.md) 참조.

추가로 Codex 공존 규칙은 [`../../docs/codex-context-mode-hxsk-coexistence.md`](../../docs/codex-context-mode-hxsk-coexistence.md) 참조.

## Codex + context-mode + HXSK Coexistence

Codex에서 전역 `context-mode`와 repo-local HXSK를 함께 쓰는 경우 우선순위는 다음과 같다.

1. **전역 Codex 설정 (`~/.codex/config.toml`, `~/.codex/hooks.json`)**
   - context-mode MCP 등록
   - 라우팅/세션 추적/compaction continuity
2. **repo-local HXSK surface (`AGENTS.md`, `.hxsk/`, `.hxsk/githooks/`)**
   - read order, file ownership, verify discipline, memory storage 규칙
3. **repo-local Codex hooks.json**
   - 필요한 경우 Stop hook chain 에 HXSK prune/verify 단계를 merge

권장 규칙:
- context-mode 훅은 **전역**에서 유지
- HXSK는 **repo-local 문서와 git-hook fallback**으로 유지
- Stop hook을 repo-local에서 따로 두어야 한다면, `context-mode hook codex stop` 뒤에 `bash .hxsk/scripts/prune-memories.sh --auto` 또는 더 좁은 verify command를 체인으로 병합한다.
- 둘 중 하나를 덮어쓰는 대신 **병합**을 기본으로 한다.
