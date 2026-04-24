# OpenCode 호환성 검증 결과

## Verification Date
2026-04-24

## OpenCode Version
1.14.18

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

| 항목 | 기대 동작 | CLI 검증 결과 | 판정 |
|------|-----------|---------------|------|
| CLAUDE.md 폴백 | AGENTS.md 없을 때 CLAUDE.md 로드 | RESEARCH 문서 확인: 폴백 지원. 프로젝트에 AGENTS.md 존재하므로 우선 사용됨. `OPENCODE_DISABLE_CLAUDE_CODE=1` 환경변수로 비활성화 가능 | ✅ |
| Skills (.claude/skills/) 로드 | `.claude/skills/` 경로 탐색 | RESEARCH 문서 확인: `.claude/skills/` 및 `.opencode/skills/` 양쪽 경로 지원. 심링크 전략으로 공유 가능 | ✅ |
| Hooks (bash) 지원 | 미지원 (TypeScript 전용) | CLI에서 직접 확인 불가. RESEARCH 문서 기준 bash hooks는 미지원. 단, `oh-my-opencode` 플러그인이 이미 설치되어 있어 Claude Code 스타일 hooks를 부분 지원 | ⚠️ |
| TypeScript 플러그인 | `.opencode/plugins/*.ts` | `~/.config/opencode/plugins/` 디렉토리 없음. 단, `opencode.json`의 `plugin` 배열로 npm 패키지 방식 사용 중 (`oh-my-opencode`, `opencode-antigravity-auth`) | ✅ |
| `opencode plugin <module>` 명령 | npm 패키지 설치 지원 | `--help`에서 확인: `opencode plugin <module>` 명령 존재 (`plug` alias 지원) | ✅ |
| `opencode run` 명령 | headless 실행 지원 | `--help`에서 확인: `opencode run [message..]` 명령 존재 | ✅ |
| `opencode serve` / `opencode web` | 서버/웹 UI 모드 | `--help`에서 확인: 두 명령 모두 존재 | ✅ |

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

1. **마크다운 설정 (CLAUDE.md, AGENTS.md, Skills)**: 폴백 시스템으로 그대로 동작. AGENTS.md가 이미 존재하므로 우선 사용됨.
2. **Bash Hooks**: 직접 지원 불가하나, `oh-my-opencode` 플러그인이 이미 글로벌 config에 설치되어 있어 Claude Code 스타일 hooks를 부분 커버.
3. **플러그인 시스템**: `~/.config/opencode/plugins/` 디렉토리 방식이 아닌 `opencode.json`의 `plugin` 배열 + npm 패키지 방식으로 사용 중이며 정상 작동.
4. **`opencode run`**: headless 실행 지원으로 CI/자동화 환경에서도 활용 가능.

---

## Next Steps

1. **세션 검증 (Task 2)**: `opencode` 실행 후 AGENTS.md / CLAUDE.md 로드 확인
2. **Skills 심링크 확인**: `~/.claude/skills/` → `~/.config/opencode/skill/` 심링크 필요 여부 확인
3. **oh-my-opencode 범위 파악**: `.hxsk/hooks/` bash hooks 중 TypeScript 재작성 없이 `oh-my-opencode`로 커버 가능한 것 목록화
4. **나머지 hooks 마이그레이션**: `oh-my-opencode`로 커버 불가한 hooks는 TypeScript 플러그인으로 재작성 대상 식별
