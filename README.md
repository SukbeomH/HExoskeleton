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
| **Hooks** | 10 | 이벤트 기반 자동화 스크립트 |
| **MCP Servers** | 2 | 코드 분석 + 에이전트 기억 |

### 상세 문서

각 구성요소의 상세 구현은 `docs/` 디렉토리에서 확인할 수 있습니다:

| 문서 | 설명 |
|------|------|
| [Agents](docs/AGENTS.md) | 13개 서브에이전트 상세 (역할, capabilities, 실행 흐름) |
| [Skills](docs/SKILLS.md) | 15개 스킬 상세 (트리거 조건, MCP 도구 연동) |
| [Hooks](docs/HOOKS.md) | 10개 훅 이벤트 상세 (이벤트, 코드, 작동 예시) |
| [Workflows](docs/WORKFLOWS.md) | 31개 명령어 상세 (GSD 사이클, 인자, 출력 형식) |
| [MCP](docs/MCP.md) | MCP 서버 상세 (graph-code 19도구, mcp-memory-service 8도구) |
| [Linting](docs/LINTING.md) | Ruff/Mypy 설정 상세 (규칙, 제한, 자동 포맷) |
| [GitHub Workflow](docs/GITHUB-WORKFLOW.md) | CI/CD 파이프라인 상세 (jobs, 캐싱, Issue 템플릿) |
| [Build](docs/BUILD.md) | 빌드 가이드 (Claude Code Plugin, Google Antigravity) |

---

## 디렉토리 구조

```
.
├── .agent/                    # GSD 워크플로우 (31 commands)
│   └── workflows/*.md
├── .claude/                   # Claude Code 설정
│   ├── agents/                # 서브에이전트 정의 (13)
│   ├── skills/                # 스킬 정의 (15)
│   ├── hooks/                 # 훅 스크립트 (10 이벤트)
│   └── settings.json          # 훅 설정
├── .gsd/                      # GSD 작업 문서
│   ├── SPEC.md                # 프로젝트 명세
│   ├── ROADMAP.md             # 마일스톤/페이즈 로드맵
│   ├── STATE.md               # 현재 작업 상태
│   ├── DECISIONS.md           # 아키텍처 결정 기록
│   ├── JOURNAL.md             # 개발 저널
│   ├── ARCHITECTURE.md        # 코드베이스 아키텍처 분석
│   ├── PATTERNS.md            # 컨텍스트 패턴 (2KB 제한)
│   ├── STACK.md               # 기술 스택 문서
│   ├── context-config.yaml    # 컨텍스트 관리 설정
│   ├── templates/             # 문서 템플릿 (24)
│   ├── examples/              # 예제 (3)
│   ├── research/              # 연구 문서 (RESEARCH-*.md)
│   ├── reports/               # 분석 보고서 (REPORT-*.md)
│   └── archive/               # 월별 아카이브
├── docs/                      # 상세 문서
│   ├── AGENTS.md              # 에이전트 상세
│   ├── SKILLS.md              # 스킬 상세
│   ├── HOOKS.md               # 훅 상세
│   ├── WORKFLOWS.md           # 워크플로우 상세
│   ├── MCP.md                 # MCP 서버 상세
│   ├── LINTING.md             # 린팅 설정 상세
│   └── GITHUB-WORKFLOW.md     # CI/CD 파이프라인 상세
├── src/                       # 예제 애플리케이션
│   └── gsd_stat/              # 프로젝트 통계 CLI 도구
├── tests/                     # 테스트
├── .mcp.json                  # MCP 서버 설정
├── scripts/                   # 유틸리티 스크립트
│   ├── build-plugin.sh        # GSD 플러그인 빌드
│   ├── build-antigravity.sh   # Antigravity 워크스페이스 빌드
│   ├── bootstrap.sh           # 프로젝트 부트스트랩
│   ├── compact-context.sh     # 컨텍스트 압축
│   └── organize-docs.sh       # 문서 정리
├── gsd-plugin/                # 빌드된 플러그인 (Claude Code)
├── antigravity-boilerplate/   # 빌드된 워크스페이스 (Antigravity IDE)
├── Makefile                   # 개발 명령어
├── pyproject.toml             # Python 설정 (uv + hatchling)
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
1. **mcp-memory-service** 설치 (pipx)
2. `.env` 파일 생성
3. 코드베이스 **인덱싱** (Tree-sitter → SQLite)

### 3. 시작하기

```bash
# Claude Code 재시작 후
/gsd:help              # 전체 명령어 확인
/gsd:new-project       # 새 프로젝트 시작
```

---

## 예제 CLI 도구 (gsd-stat)

프로젝트 통계를 분석하는 예제 CLI 도구가 포함되어 있습니다.

### 사용법

```bash
# 현재 디렉토리 분석
uv run gsd-stat

# 특정 경로 분석
uv run gsd-stat src/

# JSON 출력
uv run gsd-stat --json
```

### 출력 예시

```
Project Statistics
========================================
Total files: 4
Total lines: 192

Lines by Language:
--------------------
  Python            192 (100.0%)

Markers:
--------------------
  TODO:  10
  FIXME: 10
```

### 구조

```
src/gsd_stat/
├── __init__.py      # 버전 정보
├── analyzer.py      # 파일 분석 로직
├── reporter.py      # 결과 포맷팅
└── cli.py           # CLI 엔트리포인트
```

이 예제는 GSD 워크플로우와 테스트 작성 패턴을 데모합니다.

---

## 실행 흐름 & 의사결정

플러그인의 각 컴포넌트(Skills, Agents, Hooks)가 언제, 어떻게 실행되는지 설명합니다.

### 세션 라이프사이클

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SESSION LIFECYCLE                               │
└─────────────────────────────────────────────────────────────────────────────┘

  [Claude Code 시작]
         │
         ▼
  ┌──────────────┐
  │ SessionStart │ ─────▶ session-start.sh
  │    Hook      │        • .gsd/STATE.md 로드
  └──────────────┘        • git status 주입
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                           MAIN LOOP                                       │
  │  ┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐ │
  │  │사용자 입력 │────▶│ 의사결정   │────▶│ 도구 실행  │────▶│ 결과 반환  │ │
  │  └────────────┘     └────────────┘     └────────────┘     └────────────┘ │
  │        ▲                                                         │        │
  │        └─────────────────────────────────────────────────────────┘        │
  └──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │  SessionEnd  │ ─────▶ save-session-changes.sh
  │    Hook      │        save-transcript.sh
  └──────────────┘        • 변경사항 추적
                          • 대화 기록 저장
```

### 의사결정 흐름

사용자 입력을 받으면 Claude는 다음 순서로 처리 방식을 결정합니다:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DECISION FLOW                                      │
└─────────────────────────────────────────────────────────────────────────────┘

  [사용자 입력]
         │
         ▼
  ┌──────────────────┐
  │ 워크플로우 명령어? │──── Yes ───▶ /plan, /execute, /verify 등
  │   (/gsd:*)       │              해당 워크플로우 실행
  └──────────────────┘
         │ No
         ▼
  ┌──────────────────┐
  │ 스킬 트리거 조건? │──── Yes ───▶ 매칭되는 스킬 자동 호출
  │                  │              (description 기반 판단)
  └──────────────────┘
         │ No
         ▼
  ┌──────────────────┐
  │ 복잡한 작업?     │──── Yes ───▶ 서브에이전트 위임
  │ (멀티스텝/전문)  │              (Task tool 사용)
  └──────────────────┘
         │ No
         ▼
  [직접 처리]
```

### 스킬 트리거 조건

| 스킬 | 트리거 조건 | 트리거 예시 |
|------|-------------|-------------|
| `planner` | 계획 수립 요청 | "이 기능 어떻게 구현하지?", `/plan` |
| `plan-checker` | 계획 검증 필요 | 계획 생성 직후 자동 호출 |
| `executor` | 계획 실행 요청 | `/execute`, "이 계획 실행해줘" |
| `verifier` | 구현 검증 요청 | `/verify`, "제대로 동작하는지 확인해줘" |
| `debugger` | 버그 조사 | "왜 안 되지?", "에러 원인 찾아줘" |
| `impact-analysis` | 코드 수정 전 | 리팩토링, 삭제, 대규모 수정 전 |
| `arch-review` | 구조 변경 시 | 새 모듈 추가, 아키텍처 변경 |
| `codebase-mapper` | 코드베이스 파악 | "프로젝트 구조 알려줘", `/map` |
| `commit` | 커밋 요청 | "커밋해줘", 작업 완료 후 |
| `create-pr` | PR 생성 요청 | "PR 만들어줘" |
| `pr-review` | PR 리뷰 요청 | "이 PR 리뷰해줘" |
| `clean` | 코드 품질 체크 | "린트 돌려줘", "코드 정리해줘" |
| `context-health-monitor` | 긴 세션 | 자동 모니터링 (복잡도 감지) |
| `empirical-validation` | 완료 확인 | "다 됐어?" → 증거 요구 |
| `bootstrap` | 프로젝트 초기화 | `/bootstrap`, "프로젝트 셋업해줘" |

### 도구 실행과 Hook 체인

도구가 실행될 때 Hook이 자동으로 개입합니다:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TOOL EXECUTION CHAIN                               │
└─────────────────────────────────────────────────────────────────────────────┘

  [도구 호출 요청]
         │
         ▼
  ┌──────────────┐
  │ PreToolUse   │ ─────▶ 도구별 검증
  │    Hook      │
  └──────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 [허용]     [차단]
    │         │
    ▼         └──▶ "차단됨: {reason}" 반환
  ┌──────────────┐
  │  도구 실행   │
  └──────────────┘
         │
         ▼
  ┌──────────────┐
  │ PostToolUse  │ ─────▶ 후처리 (포맷팅 등)
  │    Hook      │
  └──────────────┘
         │
         ▼
  ┌──────────────┐
  │    Stop      │ ─────▶ 턴 종료 시 처리
  │    Hook      │        (인덱싱, 검증)
  └──────────────┘
```

### Hook 트리거 조건

| Hook | 이벤트 | 트리거 조건 | 동작 |
|------|--------|-------------|------|
| `session-start.sh` | SessionStart | Claude Code 시작 | STATE.md 로드, git status 주입 |
| `file-protect.py` | PreToolUse | Edit/Write/Read 도구 사용 시 | .env, 시크릿 파일 차단 |
| `bash-guard.py` | PreToolUse | Bash 도구 사용 시 | rm -rf, 위험 명령 차단 |
| `auto-format-py.sh` | PostToolUse | Python 파일 Edit/Write 후 | ruff format 자동 실행 |
| `pre-compact-save.sh` | PreCompact | 컨텍스트 압축 전 | 상태 백업 |
| `post-turn-index.sh` | Stop | 매 턴 종료 시 | 변경된 코드 인덱싱 |
| `post-turn-verify.sh` | Stop | 매 턴 종료 시 | 작업 검증 |
| `save-session-changes.sh` | SessionEnd | 세션 종료 시 | 변경사항 추적 |
| `save-transcript.sh` | SessionEnd | 세션 종료 시 | 대화 기록 저장 |

### 에이전트 위임 조건

Claude가 서브에이전트를 spawning하는 조건:

| 조건 | 위임 대상 | 이유 |
|------|-----------|------|
| 복잡한 멀티스텝 작업 | `executor` | 별도 컨텍스트에서 집중 실행 |
| 대규모 코드 분석 | `codebase-mapper` | 전체 코드베이스 탐색 필요 |
| 체계적 디버깅 | `debugger` | 상태 추적 + 3-strike rule |
| 영향 분석 | `impact-analysis` | 의존성 그래프 탐색 |
| 아키텍처 검토 | `arch-review` | 전문적 관점 필요 |

### 완전한 워크플로우 예시

`/execute` 명령 실행 시 전체 흐름:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    /execute WORKFLOW EXAMPLE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  [사용자: /execute 1]
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 1. 워크플로우 로드                                                        │
  │    .agent/workflows/execute.md 읽기                                       │
  └──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 2. executor 스킬 호출                                                     │
  │    .claude/skills/executor/SKILL.md 로드                                  │
  │    • Deviation Rules 적용                                                 │
  │    • Checkpoint Protocol 준수                                             │
  └──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 3. Task 실행 루프                                                         │
  │    ┌────────────────────────────────────────────────────────────────┐    │
  │    │ For each task:                                                  │    │
  │    │   a. 코드 수정 (Edit/Write)                                     │    │
  │    │      └─▶ PreToolUse: file-protect.py 검증                       │    │
  │    │      └─▶ PostToolUse: auto-format-py.sh 포맷팅                  │    │
  │    │   b. 테스트 실행 (Bash)                                         │    │
  │    │      └─▶ PreToolUse: bash-guard.py 검증                         │    │
  │    │   c. 검증 통과 시 커밋                                           │    │
  │    │      └─▶ commit 스킬 호출                                        │    │
  │    │   d. PRD 업데이트                                                │    │
  │    │      └─▶ update_prd.py complete-plan                            │    │
  │    └────────────────────────────────────────────────────────────────┘    │
  └──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 4. 턴 종료                                                                │
  │    └─▶ Stop Hook: post-turn-index.sh (코드 인덱싱)                       │
  │    └─▶ Stop Hook: post-turn-verify.sh (작업 검증)                        │
  └──────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 5. SUMMARY.md 생성                                                        │
  │    .gsd/phases/{N}/{plan}-SUMMARY.md                                      │
  └──────────────────────────────────────────────────────────────────────────┘
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
| `/init` | GSD 문서 시스템 초기화 + 인프라 비교 |
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

## Hooks (10)

**Hooks**는 Claude Code 이벤트에 자동으로 응답하는 스크립트입니다.

### 훅 이벤트 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ SessionStart│────▶│  작업 수행   │────▶│ SessionEnd  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
  session-start.sh    PreToolUse         memory 저장
  (상태 로드)         PostToolUse        save-session-changes.sh
                      PreCompact         save-transcript.sh
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
| **SessionEnd** | `save-session-changes.sh` | 세션 변경사항 추적 |
| **SessionEnd** | `save-transcript.sh` | 대화 기록 저장 |

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

### MCP 의사결정 흐름

Claude는 작업 유형에 따라 적절한 MCP 도구를 선택합니다:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MCP DECISION FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

  [작업 요청]
         │
         ▼
  ┌──────────────────┐
  │ 코드 분석 필요?  │──── Yes ───▶ code-graph-rag
  │ (구조/의존성/영향)│              (AST 기반 분석)
  └──────────────────┘
         │ No
         ▼
  ┌──────────────────┐
  │ 과거 컨텍스트    │──── Yes ───▶ memory-graph
  │ 필요?            │              (기억 검색/저장)
  └──────────────────┘
         │ No
         ▼
  [기본 도구 사용]
  (Read, Grep, Glob)
```

### code-graph-rag 도구 선택

코드 분석 요청 시 상황에 맞는 도구를 선택합니다:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      code-graph-rag TOOL SELECTION                           │
└─────────────────────────────────────────────────────────────────────────────┘

  [코드 분석 요청]
         │
         ├─── "이 함수 수정하면 뭐가 영향받아?" ───▶ analyze_code_impact
         │
         ├─── "비슷한 코드 있어?" ─────────────────▶ find_similar_code
         │                                          detect_code_clones
         │
         ├─── "이 클래스가 뭘 사용해?" ────────────▶ list_entity_relationships
         │
         ├─── "이 파일에 뭐가 있어?" ──────────────▶ list_file_entities
         │
         ├─── "복잡한 코드 어디야?" ───────────────▶ analyze_hotspots
         │
         ├─── "리팩토링 어떻게 해?" ───────────────▶ suggest_refactoring
         │
         └─── "XXX 관련 코드 찾아줘" ──────────────▶ semantic_search
                                                    query
```

| 도구 | 트리거 상황 | 예시 요청 |
|------|-------------|-----------|
| `analyze_code_impact` | 수정/삭제 전 영향 분석 | "이 함수 삭제하면?", 리팩토링 전 |
| `semantic_search` | 개념/기능 기반 검색 | "인증 처리하는 코드", "에러 핸들링" |
| `query` | 자연어 코드 질문 | "User 모델의 관계는?", "API 엔드포인트 목록" |
| `find_similar_code` | 패턴 찾기 | "이거랑 비슷한 코드 있어?" |
| `detect_code_clones` | 중복 제거 | "중복 코드 찾아줘" |
| `list_file_entities` | 파일 구조 파악 | "이 파일에 뭐 정의돼 있어?" |
| `list_entity_relationships` | 의존성 파악 | "이 클래스가 뭘 import해?" |
| `analyze_hotspots` | 복잡도 분석 | "리팩토링 필요한 곳", "복잡한 코드" |
| `suggest_refactoring` | 개선 제안 | "이 코드 어떻게 개선해?" |

### memory-graph 도구 선택

세션 간 학습과 기억 관리:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      memory-graph TOOL SELECTION                             │
└─────────────────────────────────────────────────────────────────────────────┘

  [기억 관련 요청]
         │
         ├─── "저번에 어떻게 했더라?" ────────────▶ recall_memories
         │                                          search_memories
         │
         ├─── "이 패턴 기억해둬" ──────────────────▶ store_memory
         │
         ├─── "관련된 결정들 뭐 있어?" ────────────▶ get_related_memories
         │
         └─── "이전 기억 수정해줘" ────────────────▶ update_memory
                                                    delete_memory
```

| 도구 | 트리거 상황 | 예시 |
|------|-------------|------|
| `store_memory` | 중요 패턴/결정 발견 | 아키텍처 결정, 버그 해결 패턴, 학습 내용 |
| `recall_memories` | 자연어로 기억 검색 | "인증 관련 결정", "이전 버그 수정" |
| `search_memories` | 태그/필터로 검색 | `tags: ["architecture"]`, `type: "decision"` |
| `get_related_memories` | 연관 기억 탐색 | 특정 결정과 관련된 다른 결정들 |
| `create_relationship` | 기억 간 연결 | "이 버그 수정은 저 아키텍처 결정과 관련" |
| `update_memory` | 기억 갱신 | 결정 변경, 패턴 업데이트 |
| `delete_memory` | 기억 삭제 | 더 이상 유효하지 않은 정보 |

### MCP 통합 워크플로우 예시

코드 수정 작업 시 MCP 도구 활용 흐름:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MCP INTEGRATION EXAMPLE                                   │
│                    "UserService 리팩토링해줘"                                 │
└─────────────────────────────────────────────────────────────────────────────┘

  [1. 과거 기억 검색]
         │
         ▼
  memory-graph: recall_memories("UserService 관련 결정")
         │
         └──▶ "2024-01에 인증 로직 분리 결정함" 발견
         │
         ▼
  [2. 영향 분석]
         │
         ▼
  code-graph-rag: analyze_code_impact("UserService")
         │
         └──▶ AuthController, OrderService, 테스트 12개 영향
         │
         ▼
  [3. 유사 코드 확인]
         │
         ▼
  code-graph-rag: find_similar_code("UserService.authenticate")
         │
         └──▶ AdminService에 중복 로직 발견
         │
         ▼
  [4. 리팩토링 제안]
         │
         ▼
  code-graph-rag: suggest_refactoring("UserService")
         │
         └──▶ "인증 로직을 AuthService로 추출 권장"
         │
         ▼
  [5. 실행 후 기억 저장]
         │
         ▼
  memory-graph: store_memory({
    type: "decision",
    title: "UserService 리팩토링",
    content: "인증 로직을 AuthService로 분리",
    tags: ["architecture", "refactoring"]
  })
```

### MCP vs 기본 도구 선택 기준

| 상황 | 선택 | 이유 |
|------|------|------|
| 단일 파일 읽기 | `Read` | 간단한 작업엔 기본 도구 |
| 텍스트 패턴 검색 | `Grep` | 정규식 기반 빠른 검색 |
| 파일명 패턴 검색 | `Glob` | 파일 시스템 탐색 |
| **의존성/영향 분석** | `code-graph-rag` | AST 기반 정확한 분석 필요 |
| **의미 기반 코드 검색** | `code-graph-rag` | "인증 처리" 같은 개념 검색 |
| **과거 결정/패턴 검색** | `memory-graph` | 세션 간 컨텍스트 유지 |
| **학습 내용 저장** | `memory-graph` | 영구 기억으로 축적 |

---

## Context Management

긴 세션에서 컨텍스트 품질을 유지하기 위한 시스템입니다.

### 핵심 파일

| 파일 | 용도 | 제한 |
|------|------|------|
| `.gsd/PATTERNS.md` | 핵심 패턴/학습 저장 | 2KB |
| `.gsd/context-config.yaml` | 컨텍스트 관리 설정 | - |
| `.gsd/STATE.md` | 현재 작업 상태 | - |

### 유틸리티 스크립트

```bash
# 컨텍스트 압축 (긴 세션 후)
./scripts/compact-context.sh

# 문서 정리 (research/, reports/ 아카이브)
./scripts/organize-docs.sh
```

### 컨텍스트 흐름

```
작업 진행
    │
    ▼
context-health-monitor 스킬
    │ (복잡도 감지)
    ▼
pre-compact-save.sh 훅
    │ (상태 백업)
    ▼
compact-context.sh
    │ (PATTERNS.md 추출)
    ▼
Fresh Session (PATTERNS.md 로드)
```

### Research & Reports

프로젝트 연구 및 분석 결과물:

| 디렉토리 | 내용 |
|----------|------|
| `.gsd/research/` | 기술 리서치 문서 (RESEARCH-*.md) |
| `.gsd/reports/` | 분석 보고서 (REPORT-*.md) |
| `.gsd/archive/` | 월별 아카이브 (journal, changelog) |

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
| **mcp-memory-service** | `MCP_MEMORY_SQLITE_PATH` | 커스텀 DB 경로 (선택) |

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

## 빌드

이 보일러플레이트를 다른 형식으로 빌드할 수 있습니다. 상세 내용은 [Build Guide](docs/BUILD.md)를 참조하세요.

| 타겟 | 명령어 | 출력 |
|------|--------|------|
| Claude Code Plugin | `make build-plugin` | `gsd-plugin/` |
| Google Antigravity | `make build-antigravity` | `antigravity-boilerplate/` |

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
├── commands/                    # 31 명령어
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

## GSD Plugin 자동 릴리즈

플러그인은 **release-please** 기반 GitHub Actions로 자동 릴리즈됩니다.

### 릴리즈 플로우

```
feat(gsd-plugin): 새 기능 추가
        ↓
    push to master
        ↓
release-please가 Release PR 자동 생성
  - plugin.json 버전 업데이트
  - CHANGELOG.md 자동 생성
        ↓
    PR 리뷰 → 머지
        ↓
자동 릴리즈:
  - Git 태그 (gsd-plugin-v1.1.0)
  - GitHub Release
  - gsd-plugin-1.1.0.zip 첨부
```

### Conventional Commits 규칙

플러그인 변경 시 다음 커밋 형식을 사용합니다:

| 커밋 타입 | 버전 변경 | 예시 |
|----------|----------|------|
| `fix(gsd-plugin):` | 패치 (1.0.1) | 버그 수정 |
| `feat(gsd-plugin):` | 마이너 (1.1.0) | 새 기능 |
| `feat(gsd-plugin)!:` | 메이저 (2.0.0) | Breaking change |

```bash
# 예시
git commit -m "feat(gsd-plugin): 새로운 /gsd:analyze 명령 추가"
git commit -m "fix(gsd-plugin): hook 스크립트 경로 수정"
```

### 릴리즈 설정 파일

| 파일 | 용도 |
|------|------|
| `.github/workflows/release-plugin.yml` | 릴리즈 워크플로우 |
| `release-please-config.json` | release-please 설정 |
| `.release-please-manifest.json` | 버전 추적 |
| `gsd-plugin/CHANGELOG.md` | 변경 이력 (자동 생성) |
| `gsd-plugin/RELEASE.md` | 릴리즈 가이드 |

### GitHub Release에서 설치

```bash
# 최신 버전
curl -L https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/latest/download/gsd-plugin-*.zip -o gsd-plugin.zip
unzip gsd-plugin.zip -d ~/.claude/plugins/gsd

# 특정 버전
VERSION="1.2.0"
curl -L "https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/download/gsd-plugin-v${VERSION}/gsd-plugin-${VERSION}.zip" -o gsd-plugin.zip
```

---

## Antigravity 빌드

이 보일러플레이트를 Google Antigravity IDE 워크스페이스로 변환할 수 있습니다.

### 빌드

```bash
make build-antigravity
```

### 빌드 산출물

```
antigravity-boilerplate/
├── .agent/
│   ├── skills/              # 15개 스킬 (SKILL.md format)
│   ├── workflows/           # 30개 워크플로우 (// turbo 지원)
│   └── rules/               # 3개 패시브 규칙
│       ├── code-style.md    # Python 코드 스타일
│       ├── safety.md        # 안전 규칙
│       └── gsd-workflow.md  # GSD 방법론 규칙
├── templates/gsd/           # GSD 템플릿
├── scripts/                 # 유틸리티 스크립트
├── mcp-settings.json        # MCP 서버 설정 (Antigravity 표준)
└── README.md
```

### Antigravity 주요 개념

| 컴포넌트 | 설명 | 트리거 |
|----------|------|--------|
| **Workflows** | 표준화된 작업 레시피 | `/` 슬래시 커맨드 또는 자연어 |
| **Rules** | 패시브 가이드라인 (항상 적용) | 자동 |
| **Skills** | 전문화된 에이전트 기능 | 에이전트가 자동 인식 |

### Turbo Mode

워크플로우에서 `// turbo` 주석으로 명령어 자동 실행:

```markdown
1. 테스트 실행
// turbo
2. `npm run test`
```

또는 `// turbo-all`로 모든 명령어 자동 실행.

### 사용 방법

**독립 워크스페이스로 사용:**
```bash
antigravity antigravity-boilerplate/
```

**기존 프로젝트에 적용:**
```bash
cp -r antigravity-boilerplate/.agent /path/to/project/
cp antigravity-boilerplate/mcp-settings.json /path/to/project/
```

**MCP 서버 설정:**

*옵션 1: 프로젝트 레벨 (권장)*
1. Antigravity에서 Agent panel "..." → MCP Servers
2. Manage MCP Servers → View raw config
3. `mcp-settings.json` 내용 추가

*옵션 2: 글로벌*
```bash
mkdir -p ~/.gemini/antigravity
cp mcp-settings.json ~/.gemini/antigravity/
```

### Claude Code → Antigravity 마이그레이션

| Claude Code | Antigravity |
|-------------|-------------|
| `CLAUDE.md` | `.agent/rules/*.md` |
| `.claude/skills/` | `.agent/skills/` |
| Claude Hooks | `.agent/workflows/` (`// turbo` 사용) |
| `.mcp.json` | `mcp-settings.json` |

상세 내용은 [Build Guide](docs/BUILD.md)를 참조하세요.

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
| `make build-plugin` | Claude Code 플러그인 빌드 |
| `make build-antigravity` | Antigravity 워크스페이스 빌드 |

---

## Troubleshooting

### MCP 서버 연결 실패

```bash
# code-graph-rag
npx -y @er77/code-graph-rag-mcp --version

# mcp-memory-service
which memory
memory --version
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
| uv (Python 패키지 매니저) | [astral.sh/uv](https://astral.sh/uv/install.sh) |

### 커뮤니티 리소스

| 리소스 | 설명 |
|--------|------|
| [Claude Code Plugins 완벽 가이드](https://jangwook.net/en/blog/en/claude-code-plugins-complete-guide/) | 플러그인 개발 종합 블로그 |
| [claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) | 플러그인 예시 저장소 |
| [Claude Code Issues](https://github.com/anthropics/claude-code/issues) | 버그 리포트 및 기능 요청 |

### Awesome Lists & 큐레이션

| 리소스 | 설명 |
|--------|------|
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Claude Code 리소스 큐레이션 |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | Claude Code 종합 가이드 |
| [claude-code-tips](https://github.com/ykdojo/claude-code-tips) | Claude Code 팁 모음 |
| [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) | MCP 서버 큐레이션 목록 |

### AI Agent & LLM 표준

| 리소스 | 설명 |
|--------|------|
| [Agent Skills](https://agentskills.io/home) | AI 에이전트 스킬 마켓플레이스 |
| [llms.txt](https://llmstxt.org/) | LLM을 위한 웹사이트 정보 표준 |

### 코드 스니펫 & 린팅

| 리소스 | 설명 |
|--------|------|
| [Ruff Rules](https://docs.astral.sh/ruff/rules/) | Ruff 린터 규칙 전체 목록 |
| [python-snippets](https://github.com/DevelopersToolbox/python-snippets) | Python 코드 스니펫 모음 |
| [bash-snippets](https://github.com/DevelopersToolbox/bash-snippets) | Bash 스크립트 스니펫 모음 |
| [GitHub Snippets Topic](https://github.com/topics/snippets) | 스니펫 관련 저장소 탐색 |

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
