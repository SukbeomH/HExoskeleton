# OpenCode 호환성 검증 결과

## Verification Date
2026-04-24 (공식 문서 조사 포함)

## OpenCode Version
1.14.18 (설치) / 1.14.22 (최신 — 주간 릴리스 중)

## Test Environment
- OS: macOS (Darwin 25.3.0)
- OpenCode path: /Users/sukbeom/.superset/bin/opencode
- Project: /Users/sukbeom/Desktop/Hexoskeleton

---

## CLI Verification (자동 검증)

### 명령 실행 결과

**`opencode --version`**
```
1.14.18
```

**`opencode --help 2>&1 | head -40`**
```
Commands:
  opencode completion          generate shell completion script
  opencode acp                 start ACP (Agent Client Protocol) server
  opencode mcp                 manage MCP (Model Context Protocol) servers
  opencode [project]           start opencode tui                          [default]
  opencode attach <url>        attach to a running opencode server
  opencode run [message..]     run opencode with a message
  opencode debug               debugging and troubleshooting tools
  opencode providers           manage AI providers and credentials         [aliases: auth]
  opencode agent               manage agents
  opencode upgrade [target]    upgrade opencode to the latest or a specific version
  opencode uninstall           uninstall opencode and remove all related files
  opencode serve               starts a headless opencode server
  opencode web                 start opencode server and open web interface
  opencode models [provider]   list all available models
  opencode stats               show token usage and cost statistics
  opencode export [sessionID]  export session data as JSON
  opencode import <file>       import session data from JSON file or URL
  opencode github              manage GitHub agent
  opencode pr <number>         fetch and checkout a GitHub PR branch, then run opencode
  opencode session             manage sessions
  opencode plugin <module>     install plugin and update config            [aliases: plug]
  opencode db                  database tools
```

**`ls ~/.config/opencode/`**
```
.gitignore  45B
antigravity-accounts.json  414B
bun.lock  707B
oh-my-opencode.json  632B
opencode.json  1.5K
package.json  62B
```

**`ls ~/.config/opencode/plugins/`**
```
no plugins dir
```

**글로벌 config (`~/.config/opencode/opencode.json`) 확인:**
- 활성 플러그인: `oh-my-opencode`, `opencode-antigravity-auth@1.2.8`
- `oh-my-opencode`: Claude Code 스타일 hooks 지원 플러그인 (이미 설치됨)

---

## Results Table

> 공식 문서 출처: https://opencode.ai/docs/rules/ · /docs/skills/ · /docs/plugins/

| 항목 | 기대 동작 | 검증 방법 | 판정 |
|------|-----------|-----------|------|
| CLAUDE.md 폴백 | AGENTS.md 없을 때 CLAUDE.md 로드 | **공식 문서 확인** (opencode.ai/docs/rules/): AGENTS.md 없으면 CLAUDE.md 자동 로드. `OPENCODE_DISABLE_CLAUDE_CODE=1`로 비활성화 가능. 이 프로젝트는 AGENTS.md 존재 → 우선 사용 | ✅ |
| Skills (.claude/skills/) 로드 | `.claude/skills/` 경로 탐색 | **공식 문서 확인** (opencode.ai/docs/skills/): 공식 지원 경로에 `.claude/skills/<name>/SKILL.md` 명시. `.opencode/skills/`, `~/.config/opencode/skills/`, `.agents/skills/` 도 지원 | ✅ |
| Hooks (bash) 직접 지원 | 미지원 예상 | **공식 문서 확인** (opencode.ai/docs/plugins/): 플러그인 시스템은 TypeScript/JS 전용. bash 직접 실행 불가 | ❌ |
| TypeScript 플러그인 | npm 패키지 방식 | **공식 문서 + CLI 확인**: `opencode plugin <module>` 명령으로 npm 설치. `oh-my-opencode`, `opencode-antigravity-auth@1.2.8` 이미 글로벌 활성 | ✅ |
| oh-my-opencode hooks 커버리지 | bash hooks 부분 대체 | **공식 문서 확인** (GitHub): 25+ 빌트인 훅, 병렬 에이전트 오케스트레이션, 원자적 git 커밋 자동화, tmux 통합 포함. 상당 부분 HXSK bash hooks와 기능 중복 | ⚠️ (부분 커버) |
| `opencode run` headless | CI 자동화 지원 | **CLI 확인**: `opencode run [message..]` 존재. headless 실행 가능 | ✅ |

### 지원 이벤트 (공식 문서 기준)

| 카테고리 | 이벤트 |
|----------|--------|
| Tool | `tool.execute.before`, `tool.execute.after` |
| Session | `session.created`, `session.compacted`, `session.idle`, `session.error` |
| File | `file.edited`, `file.watcher.updated` |
| Message | `message.updated`, `message.removed` |
| Shell | `shell.env` |

---

## Session-Level Verification (사용자 확인 필요)

다음 항목은 실제 opencode 세션 실행 후 확인 필요:

- [ ] CLAUDE.md / AGENTS.md 실제 로드 메시지 확인 (`opencode` 실행 시 로딩 로그)
- [ ] Skills 목록 실제 인식 여부 (`~/.claude/skills/` 경로 탐색 확인)
- [ ] `oh-my-opencode` 플러그인의 hooks 동작 여부 (HXSK hooks와 동등 수준인지)
- [ ] `.hxsk/hooks/` 내 bash hooks 중 `oh-my-opencode`로 커버되는 것 목록화

---

## Recommendation

**OpenCode v1.14.18은 HXSK 프로젝트에서 즉시 사용 가능한 상태입니다.**

1. **마크다운 설정 (AGENTS.md, Skills)**: 공식 문서로 완전 확인. AGENTS.md 우선, 없으면 CLAUDE.md 폴백. `.claude/skills/` 공식 지원 경로.
2. **Bash Hooks 대체**: `oh-my-opencode`(25+ hooks, 글로벌 활성)가 상당 부분 커버. 완전 대체는 아니며 HXSK 고유 hooks(gate-check, memory-store 등)는 TypeScript 재작성 필요.
3. **플러그인 설치**: `opencode plugin <npm-package>` 명령으로 npm 방식 사용. `.opencode/plugins/` 로컬 파일 방식도 지원.
4. **headless 지원**: `opencode run [message]`로 CI 통합 가능.

### HXSK Hooks 마이그레이션 우선순위

| Hook | oh-my-opencode 커버 | TypeScript 재작성 필요도 |
|------|---------------------|-------------------------|
| stop-context-save.sh | ⚠️ 부분 (세션 종료 이벤트 지원) | 중간 |
| md-store-memory.sh | ❌ 미커버 | 높음 |
| gate-check.sh | ❌ 미커버 | 높음 |
| track-modifications.sh | ⚠️ 부분 (file.edited 이벤트) | 낮음 |

---

## Next Steps

1. **세션 실행 검증 (Task 2)**: `opencode` TUI에서 AGENTS.md / Skills 실제 로드 확인
2. **oh-my-opencode 기능 목록 확인**: `~/.config/opencode/oh-my-opencode.json` 설정 읽기
3. **HXSK TypeScript 플러그인 MVP**: md-store-memory, gate-check를 TypeScript로 포팅하는 것이 핵심 과제
4. **버전 업그레이드**: 1.14.18 → 1.14.22 (`opencode upgrade`)
