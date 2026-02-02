# CHANGELOG

> 세션별 코드 및 문서 변경사항 기록
> 자동 생성됨 (SessionEnd 훅)

---

## 변경 기록

<!-- 아래에 세션별 변경사항이 자동으로 추가됩니다 -->
### [2026-02-02 11:09] Session: 177790d8

**변경 파일**: 54개
**추가/삭제**: +252 / -5123

#### 수정된 파일
- .claude/agents/arch-review.md
- .claude/agents/clean.md
- .claude/agents/codebase-mapper.md
- .claude/agents/commit.md
- .claude/agents/context-health-monitor.md
- .claude/agents/create-pr.md
- .claude/agents/debugger.md
- .claude/agents/executor.md
- .claude/agents/impact-analysis.md
- .claude/agents/plan-checker.md
- .claude/agents/planner.md
- .claude/agents/pr-review.md
- .claude/agents/verifier.md
- .gemini/GEMINI.md
- CLAUDE.md
- tests/test_sample.py

#### 새 파일
- .claude/agents/bootstrap.md
- .claude/hooks/compact-context.sh
- .claude/hooks/organize-docs.sh
- .claude/hooks/scaffold-gsd.sh
- .claude/hooks/scaffold-infra.sh

#### 삭제된 파일
- .agent/workflows/ (31개 파일 일괄 삭제)

---

### [2026-01-30 18:42] Session: 6dc89ecc

**변경 파일**: 28개
**추가/삭제**: +1493 / -200

#### 수정된 파일
- .claude/hooks/mcp-store-memory.sh
- .claude/hooks/pre-compact-save.sh
- .claude/hooks/session-start.sh
- .claude/hooks/stop-context-save.sh
- .claude/skills/ (6개 SKILL.md 업데이트)
- .github/agents/agent.md
- .mcp.json
- CLAUDE.md
- docs/MCP.md
- scripts/build-antigravity.sh
- scripts/build-opencode.sh

#### 새 파일
- .claude/hooks/mcp-recall-memory.sh
- .claude/skills/memory-protocol/SKILL.md
- .gsd/research/20260130-mcp-memory-alternatives.md
- scripts/convert-hooks-to-plugins.py
- scripts/migrate-memories.py

---

### [2026-01-30] Qlty CLI 통합 및 SC 경험적 검증

**커밋**: `e1a2e3a`, `9345630`, `e4c60d7`, `01e1f7d`

#### 주요 변경
- Qlty CLI 초기화 (`.qlty/qlty.toml`) — ruff, bandit, shellcheck 등 8개 플러그인 자동 감지
- `project-config.yaml` 생성 — python/uv/pytest 설정 통합
- `bootstrap.sh`에 qlty 설치 자동화 추가
- `.mcp.json` FalkorDBLite 백엔드 전환
- `Makefile` qlty 관련 타겟 추가
- Success Criteria 8/9 경험적 검증 완료 (SC#2,4,7,9 추가 검증)

#### 수정된 파일
- `.gsd/SPEC.md` — SC 체크리스트 업데이트
- `.mcp.json` — MCP 서버 설정
- `Makefile` — 빌드 타겟
- `scripts/bootstrap.sh` — 부트스트랩 스크립트

#### 새 파일
- `.qlty/qlty.toml`, `.qlty/.gitignore`, `.qlty/configs/.shellcheckrc`
- `.gsd/project-config.yaml`

---

### [2026-01-30] 훅 자동화 경량화 및 MCP 메모리 저장

**커밋**: `c482d6d`

#### 주요 변경
- `post-turn-index.sh`, `post-turn-verify.sh` 경량화
- `mcp-store-memory.sh`, `stop-context-save.sh` 신규 추가
- `.claude/settings.json` 훅 설정 업데이트

#### 수정된 파일
- `.claude/hooks/post-turn-index.sh`
- `.claude/hooks/post-turn-verify.sh`
- `.claude/settings.json`

#### 새 파일
- `.claude/hooks/mcp-store-memory.sh`
- `.claude/hooks/stop-context-save.sh`

---

### [2026-01-29] 훅 시스템 리팩토링

**커밋**: `7cefb35f`, `8a4d4825`

#### 주요 변경
- 훅 스크립트 6개 전면 리팩토링 (post-turn, pre-compact, save-session, save-transcript, session-start)
- GSD 문서 업데이트 (ARCHITECTURE.md, STACK.md, STATE.md)

#### 수정된 파일
- `.claude/hooks/post-turn-index.sh`
- `.claude/hooks/post-turn-verify.sh`
- `.claude/hooks/pre-compact-save.sh`
- `.claude/hooks/save-session-changes.sh`
- `.claude/hooks/save-transcript.sh`
- `.claude/hooks/session-start.sh`
- `.gsd/ARCHITECTURE.md`
- `.gsd/STACK.md`
- `.gsd/STATE.md`

---
