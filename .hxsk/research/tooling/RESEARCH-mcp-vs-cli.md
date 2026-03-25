# MCP vs CLI: 도구 통합 전략 비교

> **조사일**: 2026-03-04
> **출처**: Eric Holmes, GeekNews, wener-mcp-cli
> **키워드**: MCP, CLI, composability, authentication, wener-mcp-cli, 도구통합

---

## wener-mcp-cli: 멀티소스 MCP 관리

TypeScript 기반 MCP CLI 도구. Claude, Cursor, Gemini, Codex 등 여러 소스의 MCP 설정을 자동 발견하고 통합 관리.

### 핵심 기능

- **멀티소스 설정 디스커버리**: Claude, Cursor, Gemini, Codex 설정 자동 탐지
- **소스 추적**: 설정 출처 표시 + 중복 처리
- **계층적 설정**: 프로젝트 → IDE → 사용자 → 시스템 우선순위
- **도구 검색**: glob 패턴으로 도구 필터링
- **chat-completions 형식 내보내기**: 표준화된 도구 정의 출력

### 설정 우선순위

```
1. .mcp-cli.local.json    (프로젝트 로컬 오버라이드)
2. .mcp-cli.json/.mcp.json (프로젝트 설정)
3. IDE 설정 (Cursor, Gemini, Codex)
4. ~/.config/mcp/          (사용자 설정)
5. MCP_CLI_CONFIG_INLINE   (환경변수, 최고 우선)
```

### 에이전트 안전장치

도구 실행 전 반드시 `mcp-cli info <server>/<tool>` 호출로 스키마 확인 필수 — 파라미터 검증 후 실행.

---

## Eric Holmes의 "MCP는 죽었다, CLI 만세"

### MCP 비판 5가지

| 비판 | 근거 |
|------|------|
| **불필요한 복잡성** | LLM은 수백만 man page로 학습 → CLI를 자연스럽게 이해 |
| **디버깅 어려움** | MCP는 LLM 대화 내부에서만 작동, 독립 검증 불가 |
| **조합 불가** | CLI는 jq/grep/파이프 결합 가능, MCP는 서버 반환 형식에 갇힘 |
| **인증 문제** | CLI는 검증된 auth(AWS SSO, gh auth), MCP는 새 인증 체계 필요 |
| **운영 복잡성** | MCP 서버 = 별도 프로세스 관리, 초기화 불안정 |

### CLI의 장점

- 인간과 에이전트가 **동일 명령어** 공유 → 디버깅 단순
- `jq`, `grep`, 파이프라인으로 **조합 가능** (composability)
- "battle-tested auth flows" (AWS, GitHub 등)
- 별도 배경 프로세스 관리 불필요

### 균형적 시각 (GeekNews 댓글)

- MCP가 완전히 불필요한 것은 아님 — 특수 용도(실시간 스트리밍, 복잡한 상태 관리)에서는 가치 있음
- "MCP가 필요 없는 용도에 무차별적으로 사용하던 환상에서 깨어난 것"
- CLI wrapper로 MCP 기능을 제공하는 하이브리드 접근도 등장

### HXSK 관련 시사점

HXSK 보일러플레이트는 이미 CLI 기반(순수 bash + 네이티브 도구):
- `scripts/md-store-memory.sh`, `scripts/md-recall-memory.sh` = CLI 도구
- MCP 서버 의존 없음
- Holmes의 주장과 완전히 일치하는 아키텍처

---

## 출처

- [Eric Holmes — MCP is Dead, Long Live the CLI](https://ejholmes.github.io/2026/02/28/mcp-is-dead-long-live-the-cli.html)
- [GeekNews — MCP는 죽었다, CLI 만세](https://news.hada.io/topic?id=27129)
- [wenerme/wode/wener-mcp-cli](https://github.com/wenerme/wode/tree/develop/packages/wener-mcp-cli)

*Last updated: 2026-03-04*
