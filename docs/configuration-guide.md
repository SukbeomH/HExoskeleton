# Configuration Guide

> 모든 HExoskeleton 설정 키 레퍼런스. 환경 변수 · 설정 파일 · 하네스 훅 바인딩.

## 1. Configuration Files Overview

| 파일 | 스코프 | 버전 관리 | 용도 |
|------|-------|---------|------|
| `.env` | 프로젝트 | ❌ (gitignored) | 프로젝트 식별자, API 키, TLS |
| `.env.example` | 프로젝트 | ✅ | `.env` 템플릿 |
| `.envrc` | 프로젝트 | ✅ | direnv 로드 |
| `.hxsk/context-config.yaml` | HXSK | ✅ | 컨텍스트/프룬 설정 |
| `.hxsk/.prune-config` | HXSK | ❌ (gitignored) | 메모리 프룬 세부 |
| `.hxsk/.bootstrap-version` | HXSK | ✅ | 설치된 HXSK 버전 |
| `.claude/settings.json` | Claude Code | ✅ | 훅 바인딩 (팀 공유) |
| `.claude/settings.local.json` | Claude Code | ❌ (gitignored) | 개인 설정 |
| `.hxsk/adapters/*` | 하네스별 | ✅ | Gemini/Cursor/Copilot 등 훅 설정 |

## 2. Environment Variables (.env)

### 2.1 프로젝트 기본
```bash
# 필수
PROJECT_ID=my_project          # 프로젝트 식별자 (메모리 slug 접두사)
```

### 2.2 외부 API (선택)
```bash
# MCP 서버
MCP_TIMEOUT=80000              # ms. code-graph-rag 등 MCP 서버 타임아웃

# Context7 문서 MCP
CONTEXT7_API_KEY=your-key

# 기업 프록시 환경
SSL_CERT_FILE=/path/to/ca-bundle.pem
```

### 2.3 HXSK 동작 튜닝
```bash
# 메모리 cap (local tier)
HXSK_MEMORY_CAP=5              # 각 메모리 타입당 최대 파일 수 (기본 5)

# 프룬 tick 쿨다운
HXSK_PRUNE_COOLDOWN_SEC=60     # opportunistic trigger 최소 간격 (기본 60s)

# Forge 강제 지정 (자동감지 오버라이드)
HXSK_FORGE_CMD=gh              # gh / glab / tea
```

### 2.4 자동 주입 변수 (Claude Code)
```bash
# Claude Code가 자동 설정 — 사용자 설정 불필요
CLAUDE_PROJECT_DIR=/absolute/path    # 프로젝트 루트
CLAUDE_PLUGIN_ROOT=/path/to/plugin   # 플러그인 모드 시
CLAUDE_CODE_VERSION=x.y.z            # Claude Code 버전
```

## 3. Context Config (`.hxsk/context-config.yaml`)

컨텍스트 및 메모리 자동 정리 설정:

```yaml
# Active layer — 세션마다 로드되는 파일
active:
  patterns:
    max_items: 20              # PATTERNS.md 최대 항목 수
    max_kb: 2                  # PATTERNS.md 최대 크기
    auto_prune: true           # 한계 초과 시 자동 프룬
  current:
    max_kb: 1                  # CURRENT.md 최대 크기
    reset_on_session_start: true
  prd_active:
    max_kb: 3

# Archive layer — 일상적으로 로드 안 되는 파일
archive:
  journal:
    keep_sessions: 5           # 최근 N 세션 보존
    archive_older: true
    archive_format: "journal-{year}-{month}.md"
  changelog:
    keep_entries: 20
    archive_monthly: true
    archive_format: "changelog-{year}-{month}.md"
  prd_done:
    retention_days: 30
    archive_format: "prd-{year}-{month}.json"

# 폴더 라우팅 (생성된 파일 자동 이동)
folders:
  reports: reports/            # REPORT-*.md → .hxsk/reports/
  research: research/          # RESEARCH-*.md → .hxsk/research/
  archive: archive/            # 월별 아카이브

# 자동 정리 트리거
triggers:
  on_session_end: true         # SessionEnd 훅 시 정리
  on_compact: true             # PreCompact 시 정리
  manual_only: false
```

## 4. Prune Config (`.hxsk/.prune-config`)

메모리 프룬 세부 설정. shell-sourceable:

```bash
cp .hxsk/templates/prune-config.sample .hxsk/.prune-config
# 필요한 값만 주석 해제/수정
```

### 4.1 Tier별 cap
```bash
# 기본값 (모든 tier에 적용)
PRUNE_DEFAULT_CAP=5

# 특정 tier override (하이픈→언더스코어)
PRUNE_CAP_bootstrap=1          # bootstrap snapshot은 1개만
# PRUNE_CAP_session_summary=5
# PRUNE_CAP_session_snapshot=5
# PRUNE_CAP_session_handoff=5
# PRUNE_CAP_health_event=5
# PRUNE_CAP_debug_blocked=5
# PRUNE_CAP_debug_eliminated=5
# PRUNE_CAP_general=5
# PRUNE_CAP_deviation=5
```

**대상 tier**: v5.5.0부터 모든 local-tier가 일괄 cap=5 적용.

### 4.2 쿨다운
```bash
PRUNE_TICK_COOLDOWN=60         # 초. 너무 짧으면 I/O 낭비
```

### 4.3 가치 기반 승격 (자동)
설정 없음 — `prune-memories.sh`가 자동 판단:
- `tags` 필드에 `decision` / `root-cause` / `architecture-decision` / `incident` 포함된 메모리
- → `local/` 프룬 대상에서 제외되고 `shared/`로 승격

## 5. Claude Code Settings

### 5.1 Team-shared (`.claude/settings.json`)

훅 바인딩 표준:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Read",
        "hooks": [{"type": "command", "command": ".hxsk/hooks/file-protect.py", "timeout": 5}]
      },
      {
        "matcher": "Edit",
        "hooks": [{"type": "command", "command": ".hxsk/hooks/read-before-edit.py", "timeout": 5}]
      },
      {
        "matcher": "Write",
        "hooks": [{"type": "command", "command": ".hxsk/hooks/write-guard.py", "timeout": 5}]
      },
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": ".hxsk/hooks/bash-guard.py", "timeout": 5}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {"type": "command", "command": ".hxsk/hooks/track-modifications.sh", "timeout": 3},
          {"type": "command", "command": ".hxsk/hooks/auto-format.sh", "timeout": 10}
        ]
      }
    ],
    "PreCompact": [
      {"hooks": [{"type": "command", "command": ".hxsk/hooks/pre-compact-save.sh", "timeout": 10}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": ".hxsk/hooks/stop-context-save.sh", "timeout": 15}]}
    ],
    "SessionEnd": [
      {"hooks": [{"type": "command", "command": ".hxsk/hooks/save-session-changes.sh", "timeout": 10}]}
    ]
  }
}
```

### 5.2 Personal (`.claude/settings.local.json`)
개인 환경 설정. gitignored. 예시:
```json
{
  "model": "claude-opus-4-7",
  "theme": "dark",
  "permissions": {
    "allowed_tools": ["Bash(git:*)", "Bash(npm:*)"]
  }
}
```

## 6. Harness Adapters

### 6.1 Gemini CLI (`.hxsk/adapters/gemini-settings.json`)
```json
{
  "hooks": {
    "SessionEnd": {"command": "bash .hxsk/hooks/save-session-changes.sh"},
    "PreCompress": {"command": "bash .hxsk/hooks/pre-compact-save.sh"}
  }
}
```
설치: `cp .hxsk/adapters/gemini-settings.json ~/.config/gemini/settings.json`

### 6.2 Cursor (`.hxsk/adapters/cursor-hooks.json`)
```json
{
  "hooks": {
    "stop": "bash .hxsk/hooks/stop-context-save.sh",
    "preCompact": "bash .hxsk/hooks/pre-compact-save.sh"
  }
}
```
설치: `cp .hxsk/adapters/cursor-hooks.json .cursor/hooks.json`

### 6.3 Copilot CLI (`.hxsk/adapters/copilot-hooks.json`)
```json
{
  "sessionEnd": "bash .hxsk/hooks/save-session-changes.sh",
  "agentStop": "bash .hxsk/hooks/stop-context-save.sh"
}
```

### 6.4 Windsurf Cascade (`.hxsk/adapters/windsurf-hooks.json`)
```json
{
  "post_cascade_response": "bash .hxsk/hooks/stop-context-save.sh"
}
```

### 6.5 OpenCode (`.hxsk/adapters/opencode-plugin.ts`)
TypeScript 플러그인 (JS 런타임):
```typescript
export default {
  hooks: {
    "session.idle": () => exec("bash .hxsk/hooks/stop-context-save.sh"),
    "session.compacting": () => exec("bash .hxsk/hooks/pre-compact-save.sh"),
  }
};
```

### 6.6 OpenAI Codex (`.hxsk/adapters/codex-hooks.json`)
```json
{
  "skills_dir": ".agents/skills/",
  "invocation": "$autoresearch"
}
```

### 6.7 Git Hook Fallback (Aider/Continue/Antigravity)
`.hxsk/githooks/post-commit`:
```bash
#!/usr/bin/env bash
bash "$(dirname "$0")/../scripts/prune-tick.sh" >/dev/null 2>&1 &
```

활성화:
```bash
git config core.hooksPath .hxsk/githooks
```

## 7. Skill Frontmatter (`.hxsk/skills/{name}/SKILL.md`)

표준 스킬 frontmatter 필드:
```yaml
---
name: skill-name                   # 필수 — 디렉토리명과 일치
description: "CSO trigger text"    # 필수 — Claude가 보는 선택 근거
trigger: "한글 트리거 + English"    # 선택 — 사용자 의도 매칭
allowed-tools:                     # 선택 — 스킬이 사용 가능한 도구 제한
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Agent
version: 1.0.0                     # 선택 — 스킬 자체 버전
model: opus                        # 선택 — 선호 모델 힌트
---
```

## 8. Agent Frontmatter (`.hxsk/agents/{name}.md`)

```yaml
---
name: agent-name                   # 필수
description: "When/With What 설명"  # 필수
model: sonnet                      # 선택 — haiku/sonnet/opus
tools:                             # 선택
  - Read
  - Write
  - Bash
  - Agent
---
```

## 9. PLAN.md Frontmatter

`.hxsk/templates/PLAN.md` 참조. 핵심 필드:
```yaml
---
phase: 1
plan: phase-1-discipline
branch: feat/plan-discipline
parent_issue: 42
tasks:
  - id: T1
    wave: 1
    files: [path/to/file1.sh, path/to/file2.md]
    parallel: true
    sub_issue: 43
  - id: T2
    wave: 2
    files: [path/to/file3.sh]
    depends_on: [T1]
    parallel: true
must_haves:
  - all sub-issues closed
  - verifier skill passes
cross_phase_invariants:
  - no breaking change to public API
---
```

## 10. Memory File Frontmatter

`.hxsk/memories/{type}/{YYYY-MM-DD}_{slug}.md`:
```yaml
---
name: title-slug
type: root-cause                   # 15 타입 중 하나
keywords: [specific, terms]        # grep 타겟
contextual_description: "≤200자 요약"
related: [other-memory-slug-1, ...]  # 2-hop 링크
created: 2026-04-21
tags: [decision, value-tag]        # 승격 판정
---
```

## 11. Issue Frontmatter (`.hxsk/issues/`)

```yaml
---
id: MASTER-042
title: "Phase 2 Discipline"
type: master                       # master | work
priority: high
status: open                       # open | in_progress | closed
wave: 1
assignee: executor
files: [.hxsk/skills/executor/, .hxsk/agents/executor.md]
---
```

## 12. STATE.md 스키마

현재 활성 작업 상태:
```yaml
## Active Gate
plan: feat/plan-name
parent_issue: 42
current_gate: GATE-P3
sub_issues: [43, 44, 45]
forge: github

## Active Dispatcher
master: dispatch-1
status: running
tasks:
  - id: T1
    sub_issue: 43
    branch: feat/plan-name/work-1
    status: in_progress
```

## 13. llms.txt (Self-Configure 진입점)

루트의 `llms.txt`는 `llms.txt v1.0` 스펙 준수. HXSK 버전이 포함:
```
> Last Updated: 2026-04-02 · Format: llms.txt v1.0 · HXSK v5.2.0
```

주요 섹션:
- **Setup** — `.hxsk/prompts/setup.md` 링크
- **Agent Instructions** — AGENTS.md/CLAUDE.md/GEMINI.md
- **Skills/Hooks/Agents/Templates** — INDEX.md 링크
- **Architecture** — ARCHITECTURE.md, research/INDEX.md
- **Optional** — 심화 문서

## 14. Version File (`.hxsk/.bootstrap-version`)

```yaml
version: 5.5.0
last_run: 2026-04-16
components:
  skills: 22
  agents: 18
  hooks: 21
  memories: 15
```

`setup.md` Step 0이 이 파일을 읽어 FRESH/VERIFY/UPGRADE 분기.

## 15. Direnv (`.envrc`)

```bash
# .envrc — direnv 사용 시
dotenv                    # .env 자동 로드
export CLAUDE_PROJECT_DIR=$(pwd)
```

활성화: `direnv allow`

## 16. Git Ignore Recommendations

`.gitignore`에 포함되어야 할 항목:
```gitignore
# HXSK 런타임
.hxsk/memories/local/
.hxsk/.prune-tick.lock
.hxsk/.prune-config
.hxsk/.session-active
.hxsk/.modified-this-session
.hxsk/*.log
.hxsk/CURRENT.md.pre-compact.bak
.hxsk/PATTERNS.md.pre-compact.bak

# Claude Code
.claude/settings.local.json
.claude/worktrees/

# 환경
.env

# macOS/IDE
.DS_Store
*.swp
```

## 17. Configuration Precedence

값 해결 순서 (높은 우선순위 → 낮은):
1. **Shell 환경 변수** (세션 내 `export`)
2. **`.env`** (direnv로 자동 로드)
3. **`.hxsk/.prune-config`** (shell-sourceable)
4. **`.hxsk/context-config.yaml`** (YAML, 스크립트가 파싱)
5. **스크립트 내부 기본값**

## See Also

- [Deployment Guide](deployment-guide.md) — 설치 단계
- [Testing Guide](testing-guide.md) — 설정 검증
- `.hxsk/templates/prune-config.sample` — prune-config 전체 예시
- `.hxsk/adapters/README.md` — 어댑터 상세
- `.hxsk/prompts/setup.md` — Self-Configure 스크립트
