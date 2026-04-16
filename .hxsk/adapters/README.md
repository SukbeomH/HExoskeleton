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
| **OpenAI Codex CLI** | `.codex/hooks.json` (`codex_hooks=true` 필요) | stop | PreCompact 없음 |
| **Aider / Continue / Antigravity** | (lifecycle 훅 미지원) | — | git 훅 폴백 사용 |

## 설치 (선택)

해당 하네스의 설정 파일 위치에 `.hxsk/adapters/<harness>.json`을 복사하거나 병합하세요.

```bash
# Cursor 예시
mkdir -p .cursor
cp .hxsk/adapters/cursor-hooks.json .cursor/hooks.json

# git 훅 폴백 (모든 하네스 공통)
git config core.hooksPath .hxsk/githooks
```

## 설계 근거

- **Opportunistic tick**: 메모리 툴(`md-*`)은 하네스와 무관하게 스킬에서 호출되므로 여기 붙이면 자연 발화
- **Cooldown + atomic lock**: `prune-tick.sh`가 60초 cooldown과 `mkdir` atomic lock을 내장해 스팸·race 방지
- **git 훅**: `core.hooksPath`로 리포지토리 내부 훅 관리, Husky 불필요
- **OS 스케줄러 제외**: launchd/cron/systemd는 크로스 플랫폼·외부 종속성 측면에서 HXSK 원칙(순수 bash + 외부 종속성 0)에 위배
