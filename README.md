# GSD Boilerplate

AI 에이전트 기반 개발을 위한 프로젝트 보일러플레이트.

**GSD (Get Shit Done)** 방법론 + **code-graph-rag** (AST 코드 분석) + **memory-graph** (에이전트 기억)를 결합하여 구조화된 개발 워크플로우를 제공합니다.

---

## 핵심 구성요소

| 구성요소 | 개수 | 설명 |
|----------|------|------|
| **Commands** | 31 | GSD 워크플로우 슬래시 명령어 |
| **Skills** | 15 | Claude가 자율적으로 호출하는 전문 기능 |
| **Agents** | 13 | 특정 작업을 위한 서브에이전트 |
| **Hooks** | 7 | 이벤트 기반 자동화 스크립트 |
| **MCP Servers** | 2 | 코드 분석 + 에이전트 기억 |

---

## 디렉토리 구조

```
.
├── .agent/                    # GSD 워크플로우 (30 commands)
│   └── workflows/*.md
├── .claude/                   # Claude Code 설정
│   ├── agents/                # 서브에이전트 정의 (13)
│   ├── skills/                # 스킬 정의 (15)
│   ├── hooks/                 # 훅 스크립트 (7)
│   └── settings.json          # 훅 설정
├── .gsd/                      # GSD 작업 문서
│   ├── SPEC.md                # 프로젝트 명세
│   ├── ROADMAP.md             # 마일스톤/페이즈 로드맵
│   ├── STATE.md               # 현재 작업 상태
│   ├── DECISIONS.md           # 아키텍처 결정 기록
│   ├── JOURNAL.md             # 개발 저널
│   ├── templates/             # 문서 템플릿 (22)
│   └── examples/              # 예제 (3)
├── .mcp.json                  # MCP 서버 설정
├── scripts/                   # 유틸리티 스크립트
│   └── build-plugin.sh        # GSD 플러그인 빌드
├── gsd-plugin/                # 빌드된 플러그인 (배포용)
├── Makefile                   # 개발 명령어
├── pyproject.toml             # Python 설정 (uv)
└── CLAUDE.md                  # Claude Code 지침
```

---

## Quick Start

### 1. Prerequisites

```bash
# 필수 도구 확인
make check-deps
```

| 도구 | 용도 | 설치 |
|------|------|------|
| Node.js 18+ | code-graph-rag MCP | [nodejs.org](https://nodejs.org/) |
| uv | Python 패키지 관리 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| pipx | CLI 도구 설치 | `brew install pipx && pipx ensurepath` |

### 2. Setup

```bash
make setup
```

이 명령이 수행하는 작업:
1. **memorygraph** 설치 (pipx)
2. `.env` 파일 생성
3. 코드베이스 **인덱싱** (Tree-sitter → SQLite)

### 3. 시작하기

```bash
# Claude Code 재시작 후
/gsd:help              # 전체 명령어 확인
/gsd:new-project       # 새 프로젝트 시작
```

---

## GSD 워크플로우

### 핵심 사이클

```
SPEC → PLAN → EXECUTE → VERIFY
```

| 단계 | 명령어 | 설명 |
|------|--------|------|
| **1. 명세** | `/new-project` | 딥 질문 → SPEC.md 생성 |
| **2. 계획** | `/plan [N]` | 페이즈 N의 실행 계획 생성 |
| **3. 실행** | `/execute [N]` | 웨이브 단위 구현 + atomic commits |
| **4. 검증** | `/verify [N]` | must-haves 검증 + 증거 수집 |

### 전체 명령어 (31)

<details>
<summary>Core Workflow</summary>

| 명령어 | 설명 |
|--------|------|
| `/map` | 코드베이스 분석 → ARCHITECTURE.md |
| `/plan [N]` | 페이즈 계획 생성 |
| `/execute [N]` | 웨이브 기반 실행 |
| `/verify [N]` | 검증 + 증거 수집 |
| `/debug [desc]` | 체계적 디버깅 (3-strike rule) |

</details>

<details>
<summary>Project Setup</summary>

| 명령어 | 설명 |
|--------|------|
| `/new-project` | 딥 질문 → SPEC.md |
| `/new-milestone` | 마일스톤 생성 |
| `/complete-milestone` | 마일스톤 완료 처리 |
| `/audit-milestone` | 마일스톤 품질 감사 |
| `/bootstrap` | 전체 프로젝트 부트스트랩 |

</details>

<details>
<summary>Phase Management</summary>

| 명령어 | 설명 |
|--------|------|
| `/add-phase` | 로드맵 끝에 페이즈 추가 |
| `/insert-phase` | 특정 위치에 페이즈 삽입 |
| `/remove-phase` | 페이즈 제거 (안전 체크) |
| `/discuss-phase` | 페이즈 범위 논의 |
| `/research-phase` | 기술 리서치 |
| `/list-phase-assumptions` | 가정 목록화 |
| `/plan-milestone-gaps` | 갭 분석 |

</details>

<details>
<summary>Navigation & State</summary>

| 명령어 | 설명 |
|--------|------|
| `/progress` | 현재 진행 상황 |
| `/pause` | 상태 저장 (full GSD) |
| `/handoff` | 경량 핸드오프 문서 |
| `/resume` | 마지막 세션 복원 |
| `/add-todo` | TODO 추가 |
| `/check-todos` | TODO 목록 확인 |

</details>

<details>
<summary>Utilities</summary>

| 명령어 | 설명 |
|--------|------|
| `/help` | 도움말 |
| `/quick-check` | 빠른 상태 체크 |
| `/update` | GSD 문서 업데이트 |
| `/web-search` | 웹 검색 |
| `/whats-new` | 최근 변경사항 |
| `/feature-dev` | 기능 개발 워크플로우 |
| `/bug-fix` | 버그 수정 워크플로우 |

</details>

---

## Skills (15)

**Skills**는 Claude가 작업 컨텍스트를 기반으로 **자율적으로 호출**하는 전문 기능입니다.

### 스킬 목록

| Skill | 설명 | 트리거 상황 |
|-------|------|-------------|
| `planner` | 실행 가능한 페이즈 계획 생성 | 계획 수립 요청 시 |
| `plan-checker` | 계획 검증 (6차원 분석) | 계획 생성 후 |
| `executor` | 계획 실행 + atomic commits | `/execute` 실행 시 |
| `verifier` | spec 대비 검증 + 증거 수집 | `/verify` 실행 시 |
| `debugger` | 체계적 디버깅 | 버그 조사 시 |
| `impact-analysis` | 변경 영향 분석 | 코드 수정 전 |
| `arch-review` | 아키텍처 규칙 검증 | 구조 변경 시 |
| `codebase-mapper` | 코드베이스 구조 분석 | 온보딩/리팩토링 전 |
| `commit` | conventional commit 생성 | 커밋 요청 시 |
| `create-pr` | PR 생성 (gh CLI) | PR 요청 시 |
| `pr-review` | 다중 페르소나 코드 리뷰 | PR 리뷰 요청 시 |
| `clean` | 코드 품질 도구 실행 | 품질 체크 요청 시 |
| `context-health-monitor` | 컨텍스트 복잡도 모니터링 | 긴 세션 중 |
| `empirical-validation` | 경험적 증거 요구 | 완료 확인 시 |
| `bootstrap` | 프로젝트 초기 설정 | 부트스트랩 요청 시 |

### 스킬 작동 원리

```
┌─────────────────────────────────────────────────┐
│  User: "이 기능 구현해줘"                        │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  Claude: 작업 컨텍스트 분석                      │
│  → impact-analysis 스킬 자동 호출               │
│  → 영향 범위 파악 후 구현 시작                   │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  구현 완료 후                                    │
│  → commit 스킬 자동 호출                         │
│  → conventional commit 생성                     │
└─────────────────────────────────────────────────┘
```

---

## Agents (13)

**Agents**는 특정 작업에 특화된 **서브에이전트**입니다. Claude가 필요 시 자동 호출하거나 수동으로 호출할 수 있습니다.

### 에이전트 목록

| Agent | 역할 | 도구 |
|-------|------|------|
| `planner` | 페이즈 계획 설계 | Read, Grep, Glob |
| `plan-checker` | 계획 검증 | Read, Grep, Glob |
| `executor` | 계획 실행 | Read, Write, Edit, Bash, Grep, Glob |
| `verifier` | 구현 검증 | Read, Bash, Grep, Glob |
| `debugger` | 체계적 디버깅 | Read, Write, Edit, Bash, Grep, Glob |
| `impact-analysis` | 변경 영향 분석 | Read, Grep, Glob |
| `arch-review` | 아키텍처 검증 | Read, Grep, Glob |
| `codebase-mapper` | 코드베이스 분석 | Read, Bash, Grep, Glob |
| `commit` | 커밋 생성 | Read, Bash, Grep, Glob |
| `create-pr` | PR 생성 | Read, Bash, Grep, Glob |
| `pr-review` | PR 리뷰 | Read, Bash, Grep, Glob |
| `clean` | 코드 품질 | Read, Write, Edit, Bash, Grep, Glob |
| `context-health-monitor` | 컨텍스트 모니터링 | Read, Grep, Glob |

### Skills vs Agents

| 구분 | Skills | Agents |
|------|--------|--------|
| **호출 방식** | Claude가 자율적으로 결정 | 명시적 호출 또는 자동 위임 |
| **컨텍스트** | 메인 대화에서 실행 | 별도 서브프로세스 |
| **용도** | 가벼운 전문 기능 | 복잡한 멀티스텝 작업 |

---

## Hooks (7)

**Hooks**는 Claude Code 이벤트에 자동으로 응답하는 스크립트입니다.

### 훅 이벤트 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ SessionStart│────▶│  작업 수행   │────▶│ SessionEnd  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
  session-start.sh    PreToolUse         memory 저장
  (상태 로드)         PostToolUse        (prompt hook)
                      Stop
```

### 훅 목록

| 이벤트 | 스크립트 | 기능 |
|--------|----------|------|
| **SessionStart** | `session-start.sh` | GSD STATE.md 로드, git status 주입 |
| **PreToolUse** (Edit/Write) | `file-protect.py` | .env, 시크릿 파일 보호 |
| **PreToolUse** (Bash) | `bash-guard.py` | 위험한 명령어 차단 |
| **PostToolUse** (Edit/Write) | `auto-format-py.sh` | Python 파일 자동 포맷 (ruff) |
| **PreCompact** | `pre-compact-save.sh` | 컴팩트 전 상태 저장 |
| **Stop** | `post-turn-index.sh` | 변경된 코드 인덱싱 |
| **Stop** | `post-turn-verify.sh` | 작업 검증 |
| **SessionEnd** | (prompt) | memory-graph에 세션 요약 저장 |

### 훅 작동 예시

**file-protect.py** — 민감 파일 보호:
```
User: ".env 파일 읽어줘"
     │
     ▼
PreToolUse(Read) → file-protect.py 실행
     │
     ▼
차단됨: ".env is a protected file"
```

**session-start.sh** — 세션 시작 시 상태 로드:
```
Claude Code 시작
     │
     ▼
SessionStart → session-start.sh 실행
     │
     ▼
.gsd/STATE.md + git status가 컨텍스트에 주입됨
```

---

## MCP Servers (2)

### code-graph-rag

Tree-sitter + SQLite 기반 **AST 코드 분석** 서버.

| 도구 | 용도 |
|------|------|
| `query` | 자연어 코드 그래프 쿼리 |
| `semantic_search` | 의미 기반 코드 검색 |
| `analyze_code_impact` | 변경 영향 분석 |
| `analyze_hotspots` | 복잡도/커플링 핫스팟 |
| `detect_code_clones` | 중복 코드 탐지 |
| `find_similar_code` | 유사 코드 검색 |
| `list_file_entities` | 파일 내 엔티티 |
| `list_entity_relationships` | 엔티티 의존성 |
| `suggest_refactoring` | 리팩토링 제안 |

### memory-graph

에이전트 **영구 기억** 서버.

| 도구 | 용도 |
|------|------|
| `store_memory` | 패턴/결정/학습 저장 |
| `recall_memories` | 자연어 기반 검색 |
| `search_memories` | 필터 기반 검색 |
| `get_memory` / `update_memory` / `delete_memory` | CRUD |
| `create_relationship` | 기억 간 관계 생성 |
| `get_related_memories` | 관련 기억 조회 |

---

## 환경변수

### 필수 환경변수

| 변수 | 용도 | 필수 여부 |
|------|------|-----------|
| `CONTEXT7_API_KEY` | Context7 MCP 서버 (라이브러리 문서 조회) | 선택 (context7 사용 시 필수) |

### 설정 방법

**방법 1: 셸 프로파일에 추가**

```bash
# ~/.zshrc 또는 ~/.bashrc
export CONTEXT7_API_KEY="your-api-key-here"
```

**방법 2: direnv 사용 (권장)**

```bash
# .envrc 파일
export CONTEXT7_API_KEY="your-api-key-here"
```

```bash
direnv allow
```

**방법 3: .env 파일 사용**

```bash
# .env 파일 (프로젝트 루트)
CONTEXT7_API_KEY=your-api-key-here
```

> **주의**: `.env` 파일은 `.gitignore`에 포함되어 있어 커밋되지 않습니다.

### API 키 발급

| 서비스 | 발급 링크 |
|--------|-----------|
| Context7 | https://context7.com |

### MCP 서버별 환경변수

| MCP 서버 | 환경변수 | 설명 |
|----------|----------|------|
| **graph-code** | `MCP_TIMEOUT` | 타임아웃 (기본: 80000ms) |
| **graph-code** | `NODE_OPTIONS` | Node.js 옵션 (기본: `--max-old-space-size=4096`) |
| **context7** | `CONTEXT7_API_KEY` | API 키 (필수) |
| **memorygraph** | - | 환경변수 불필요 |

### 플러그인 사용 시 주의사항

플러그인 빌드 시 **context7은 기본적으로 제외**됩니다 (API 키 필요로 인한 로드 실패 방지).

context7을 포함하려면 빌드 스크립트를 수정하거나, 플러그인 설치 후 프로젝트의 `.mcp.json`에 직접 추가하세요:

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    }
  }
}
```

---

## GSD Plugin 빌드

이 보일러플레이트를 Claude Code 플러그인으로 변환할 수 있습니다.

### 빌드

```bash
./scripts/build-plugin.sh
```

### 빌드 산출물

```
gsd-plugin/
├── .claude-plugin/plugin.json   # 매니페스트 (최소 형식)
├── commands/                    # 31 워크플로우
├── skills/                      # 15 스킬
├── agents/                      # 13 에이전트
├── hooks/hooks.json             # 훅 설정
├── .mcp.json                    # MCP 설정
├── scripts/                     # 훅 스크립트
├── templates/                   # GSD 템플릿
└── references/                  # 인프라 레퍼런스
```

### 플러그인 테스트

```bash
claude --plugin-dir ./gsd-plugin
```

### 플러그인 배포

```bash
# 글로벌 설치
cp -r gsd-plugin ~/.claude/plugins/gsd
```

---

## Make 명령어

```bash
make help                   # 전체 명령어 목록
```

| 명령어 | 설명 |
|--------|------|
| `make setup` | 전체 초기 설정 |
| `make check-deps` | 필수 도구 확인 |
| `make status` | MCP + 환경 상태 |
| `make index` | 코드베이스 인덱싱 |
| `make clean` | 인덱스 데이터 삭제 |
| `make lint` | Ruff 린트 |
| `make lint-fix` | Ruff 자동 수정 |
| `make test` | pytest 실행 |
| `make typecheck` | mypy 타입 체크 |

---

## Troubleshooting

### MCP 서버 연결 실패

```bash
# code-graph-rag
npx -y @er77/code-graph-rag-mcp --version

# memorygraph
which memorygraph
memorygraph --version
```

### 인덱싱 실패

```bash
# 메모리 부족 시
NODE_OPTIONS="--max-old-space-size=4096" npx -y @er77/code-graph-rag-mcp index .
```

### 훅 실행 실패

```bash
# 실행 권한 확인
chmod +x .claude/hooks/*.sh .claude/hooks/*.py

# 수동 테스트
./.claude/hooks/session-start.sh
```

---

## 참고 문서

플러그인 개발 과정에서 참고한 공식 문서 및 리소스입니다.

### Claude Code 공식 문서

| 문서 | 설명 |
|------|------|
| [Plugins - 플러그인 생성 가이드](https://code.claude.com/docs/en/plugins.md) | 플러그인 기본 구조, 생성 방법 |
| [Plugins Reference - 플러그인 레퍼런스](https://code.claude.com/docs/en/plugins-reference.md) | 매니페스트 스키마, 컴포넌트 상세 |
| [플러그인 매니페스트 스키마 (한국어)](https://code.claude.com/docs/ko/plugins-reference#%ED%94%8C%EB%9F%AC%EA%B7%B8%EC%9D%B8-%EB%A7%A4%EB%8B%88%ED%8E%98%EC%8A%A4%ED%8A%B8-%EC%8A%A4%ED%82%A4%EB%A7%88) | plugin.json 스키마 상세 |
| [Hooks - 훅 가이드](https://code.claude.com/docs/en/hooks.md) | 이벤트 훅 설정 및 활용 |
| [Hooks Guide - 훅 상세 가이드](https://code.claude.com/docs/en/hooks-guide.md) | 훅 작성 패턴 및 예시 |
| [Sub-agents - 서브에이전트](https://code.claude.com/docs/en/sub-agents.md) | 에이전트 frontmatter 필드 |
| [Skills - 스킬](https://code.claude.com/docs/en/skills.md) | 스킬 정의 및 활용 |
| [MCP - Model Context Protocol](https://code.claude.com/docs/en/mcp.md) | MCP 서버 설정 |
| [Settings - 설정 레퍼런스](https://code.claude.com/docs/en/settings.md) | settings.json 구조 |
| [CLI Reference - CLI 명령어](https://code.claude.com/docs/en/cli-reference.md) | claude 명령어 옵션 |

### MCP 서버 문서

| 리소스 | 설명 |
|--------|------|
| [code-graph-rag-mcp](https://github.com/er77/code-graph-rag-mcp) | AST 기반 코드 분석 MCP 서버 |
| [Context7](https://context7.com) | 라이브러리 문서 조회 MCP 서버 |

### 도구 설치

| 도구 | 링크 |
|------|------|
| Node.js | [nodejs.org](https://nodejs.org/) |
| uv (Python 패키지 매니저) | [astral.sh/uv](https://astral.sh/uv/install.sh) |

### 커뮤니티 리소스

| 리소스 | 설명 |
|--------|------|
| [Claude Code Plugins 완벽 가이드](https://jangwook.net/en/blog/en/claude-code-plugins-complete-guide/) | 플러그인 개발 종합 블로그 |
| [claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) | 플러그인 예시 저장소 |
| [Claude Code Issues](https://github.com/anthropics/claude-code/issues) | 버그 리포트 및 기능 요청 |

### 핵심 발견사항

플러그인 개발 중 확인된 주요 사항:

1. **plugin.json 최소 형식**: `name`, `version`, `description`만 필수. 기본 디렉토리(`commands/`, `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`)는 자동 검색됨

2. **에이전트 frontmatter**: `tools`/`skills` 대신 `capabilities` 배열 사용
   ```yaml
   ---
   description: 에이전트 설명
   capabilities: ["Read", "Grep", "Glob"]
   ---
   ```

3. **hooks.json 형식**: 플러그인에서는 반드시 `"hooks"` 키로 래핑 필요
   ```json
   {
     "hooks": {
       "PreToolUse": [...]
     }
   }
   ```

4. **경로 변환**: 훅 스크립트 경로는 `${CLAUDE_PLUGIN_ROOT}/scripts/`로, MCP args는 `${CLAUDE_PROJECT_DIR:-.}`로 변환

5. **환경변수 의존 MCP**: API 키가 필요한 MCP 서버(context7)는 빌드에서 제외하고 사용자가 직접 추가하도록 안내

---

## 라이선스

MIT
