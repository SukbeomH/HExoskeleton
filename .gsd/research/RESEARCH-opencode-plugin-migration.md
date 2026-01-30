# OpenCode 플러그인 마이그레이션 리서치

> **연구 목적**: Claude Code용 플러그인/Hooks를 OpenCode에서 그대로 사용할 수 있는지 조사
> **연구 일자**: 2026-01-30
> **참고 문서**: https://opencode.ai/docs/plugins/

---

## 핵심 결론

❌ **Claude Code용 플러그인(Hooks)은 OpenCode에서 그대로 사용할 수 없습니다.**

두 시스템은 근본적인 아키텍처 차이가 있어 Hooks/Plugins 부분은 재작성이 필요합니다.
단, `CLAUDE.md`, Skills 같은 마크다운 기반 설정은 폴백 시스템을 통해 거의 그대로 활용 가능합니다.

---

## 아키텍처 비교

| 구분 | Claude Code Hooks | OpenCode Plugins |
|------|-------------------|------------------|
| **구현 언어** | Shell 명령어 (bash) | JavaScript/TypeScript |
| **플러그인 패키지** | Anthropic 고유 시스템 | `@opencode-ai/plugin` |
| **설정 위치** | `.claude/settings.json` | `.opencode/plugins/` 또는 `~/.config/opencode/plugins/` |
| **런타임** | 시스템 쉘 | Bun |
| **생태계** | Anthropic 종속 | 모델 중립적 (Claude, GPT, Mistral 등) |

---

## OpenCode의 Claude Code 호환성 (자동 폴백)

OpenCode는 기존 Claude Code 설정을 대부분 그대로 사용할 수 있도록 폴백 시스템을 제공합니다:

| 항목 | Claude Code 경로 | OpenCode 경로 | 동작 |
|------|------------------|---------------|------|
| **프로젝트 룰** | `CLAUDE.md` | `AGENTS.md` | `AGENTS.md`가 없으면 `CLAUDE.md` 사용 |
| **글로벌 룰** | `~/.claude/CLAUDE.md` | `~/.config/opencode/AGENTS.md` | 폴백 지원 |
| **Skills** | `~/.claude/skills/` | `~/.config/opencode/skill/` | `.claude/skills/` 경로도 검색 |
| **Skills (프로젝트)** | `.claude/skills/` | `.opencode/skills/` | 양쪽 모두 지원 |

### 파일 로딩 우선순위

1. `AGENTS.md` (프로젝트)
2. `CLAUDE.md` (프로젝트) ← 폴백
3. `~/.config/opencode/AGENTS.md` (글로벌)
4. `~/.claude/CLAUDE.md` (글로벌) ← 폴백

---

## OpenCode 플러그인 구조

### 기본 구조

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ project, client, $, directory, worktree }) => {
  return {
    // Hook 구현
  }
}
```

### 컨텍스트 객체

- `project`: 현재 프로젝트 정보
- `directory`: 현재 작업 디렉토리
- `worktree`: Git worktree 경로
- `client`: AI 상호작용을 위한 OpenCode SDK 클라이언트
- `$`: Bun의 shell API (명령어 실행용)

### 주요 이벤트 훅

| 카테고리 | 이벤트 |
|----------|--------|
| **Tool** | `tool.execute.before`, `tool.execute.after` |
| **Session** | `session.idle`, `session.created`, `session.error`, `session.compacted` |
| **File** | `file.edited`, `file.watcher.updated` |
| **Message** | `message.updated`, `message.removed` |
| **Permission** | `permission.asked`, `permission.replied` |

---

## 마이그레이션 가이드

### Claude Code Hooks → OpenCode Plugins 변환 예시

**Claude Code (settings.json):**
```json
{
  "hooks": {
    "after_response": "bash ~/scripts/notify.sh"
  }
}
```

**OpenCode 변환 (TypeScript):**
```typescript
// .opencode/plugins/notification.ts
export const NotificationPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "완료!" with title "OpenCode"'`
      }
    },
  }
}
```

### 심링크 전략 (두 도구 동시 사용 시)

```bash
# 프로젝트 Skills
ln -s .claude/skills .opencode/skill

# 글로벌 Skills
ln -s ~/.claude/skills ~/.config/opencode/skill
```

### 마이그레이션 체크리스트

| 항목 | 호환성 | 마이그레이션 방법 |
|------|--------|------------------|
| `CLAUDE.md` | ✅ | 그대로 사용 (자동 폴백) 또는 `AGENTS.md`로 이름 변경 |
| Skills (`SKILL.md`) | ✅ | 그대로 사용 (양쪽 경로 지원) |
| Hooks (Bash) | ❌ | TypeScript 플러그인으로 재작성 필요 |
| MCP Servers | ⚠️ | `opencode.json`의 `mcp` 섹션으로 이동 |
| Commands | ⚠️ | YAML frontmatter 추가 필요 |

---

## Custom Tools 정의 방법

```typescript
import { type Plugin, tool } from "@opencode-ai/plugin"

export const CustomToolsPlugin: Plugin = async (ctx) => {
  return {
    tool: {
      mytool: tool({
        description: "커스텀 도구 설명",
        args: {
          foo: tool.schema.string(),
        },
        async execute(args, context) {
          const { directory, worktree } = context
          return `Hello ${args.foo} from ${directory}`
        },
      }),
    },
  }
}
```

---

## 호환성 비활성화

Claude Code 폴백을 끄고 싶다면:

```bash
export OPENCODE_DISABLE_CLAUDE_CODE=1
```

---

## 참고 자료

- [OpenCode Plugins 공식 문서](https://opencode.ai/docs/plugins/)
- [OpenCode Ecosystem](https://opencode.ai/docs/ecosystem)
- [OpenCode Config 문서](https://opencode.ai/docs/config)

---

## 커뮤니티 플러그인 예시

- `opencode-wakatime` - WakaTime 연동
- `opencode-notifier` - 알림 기능
- `opencode-helicone-session` - Helicone 세션 추적
- `opencode-background-agents` - 백그라운드 에이전트
- `oh-my-opencode` - Claude Code 스타일 hooks 지원

---

## 결론 및 권장사항

1. **마크다운 기반 설정** (`CLAUDE.md`, Skills): 그대로 사용 가능
2. **Bash Hooks**: TypeScript로 재작성 필요 (핵심 로직은 재활용 가능)
3. **동시 사용**: 심링크 전략으로 두 도구에서 같은 설정 공유 가능
4. **생태계 이점**: OpenCode는 모델 중립적이라 다양한 LLM 활용 가능
