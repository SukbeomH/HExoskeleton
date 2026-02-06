# GSD Boilerplate

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트.

**GSD (Get Shit Done)** 방법론 + **순수 bash 기반 메모리 시스템** + **네이티브 Claude Code 도구**를 결합하여 외부 종속성 없는 구조화된 개발 워크플로우를 제공합니다.

---

## 핵심 구성요소

| 구성요소 | 개수 | 설명 |
|----------|------|------|
| **Skills** | 16 | Claude가 자율적으로 호출하는 전문 기능 |
| **Agents** | 14 | 특정 작업을 위한 서브에이전트 |
| **Hooks** | 14 | 이벤트 기반 자동화 스크립트 |
| **Memory System** | - | 순수 bash + 마크다운 파일 기반 |

### 상세 문서

각 구성요소의 상세 구현은 `docs/` 디렉토리에서 확인할 수 있습니다:

| 문서 | 설명 |
|------|------|
| [Agents](docs/AGENTS.md) | 14개 서브에이전트 상세 (역할, capabilities, 실행 흐름) |
| [Skills](docs/SKILLS.md) | 16개 스킬 상세 (트리거 조건, 도구 연동) |
| [Hooks](docs/HOOKS.md) | 14개 훅 이벤트 상세 (이벤트, 코드, 작동 예시) |
| [Memory](docs/MEMORY.md) | 파일 기반 메모리 시스템 상세 |
| [Build](docs/BUILD.md) | 빌드 가이드 (Claude Code Plugin, Google Antigravity, OpenCode) |
| [GitHub Workflow](docs/GITHUB-WORKFLOW.md) | CI/CD 파이프라인 상세 (release-please) |

---

## 디렉토리 구조

```
.
├── .claude/                   # Claude Code 설정 (Single Source of Truth)
│   ├── agents/                # 서브에이전트 정의 (14)
│   ├── skills/                # 스킬 정의 (16)
│   ├── hooks/                 # 훅 스크립트 (14 이벤트)
│   └── settings.json          # 훅 설정
├── .gsd/                      # GSD 작업 문서
│   ├── STATE.md               # 현재 작업 상태 (git 추적)
│   ├── PATTERNS.md            # 핵심 패턴/학습 (2KB, git 추적)
│   ├── SPEC.md                # 프로젝트 명세
│   ├── PLAN.md                # 실행 계획
│   ├── DECISIONS.md           # 아키텍처 결정 기록
│   ├── memories/              # 파일 기반 메모리 (14 타입)
│   │   ├── _schema/           # JSON Schema + 타입 관계
│   │   ├── architecture-decision/
│   │   ├── root-cause/
│   │   ├── session-summary/
│   │   └── ...
│   ├── templates/             # 문서 템플릿 (git 추적)
│   └── examples/              # 예제 (git 추적)
├── .github/                   # GitHub 설정
│   ├── agents/                # GitHub Agent spec
│   └── workflows/             # CI/CD (release-please)
├── docs/                      # 상세 문서
├── scripts/                   # 빌드 및 유틸리티 스크립트
│   ├── build-plugin.sh        # GSD 플러그인 빌드
│   ├── build-antigravity.sh   # Antigravity 워크스페이스 빌드
│   ├── build-opencode.sh      # OpenCode 워크스페이스 빌드
│   └── bootstrap.sh           # 프로젝트 부트스트랩
├── Makefile                   # 개발 명령어
└── CLAUDE.md                  # Claude Code 지침
```

---

## Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/SukbeomH/LLM_Bolierplate_Pack.git
cd LLM_Bolierplate_Pack

# GSD 문서 초기화
make setup
```

### 2. 시작하기

```bash
# Claude Code에서 바로 사용
# 스킬이 자동으로 로드됨
```

**외부 종속성 없음** - Node.js, Python 환경, MCP 서버 설치 불필요.

---

## 메모리 시스템

순수 bash + 마크다운 파일 기반 에이전트 메모리.

### 저장

```bash
bash .claude/hooks/md-store-memory.sh \
  "제목" \
  "내용" \
  "태그1,태그2" \
  "타입" \
  "키워드1,키워드2" \
  "1줄 요약" \
  "관련파일.md"
```

### 검색

```bash
# compact 모드 (요약)
bash .claude/hooks/md-recall-memory.sh "검색어" "." 5 compact

# full 모드 (전체 내용)
bash .claude/hooks/md-recall-memory.sh "검색어" "." 5 full

# 2-hop 검색 (related 필드 추적)
bash .claude/hooks/md-recall-memory.sh "검색어" "." 5 compact 2
```

### 메모리 타입 (14개)

| 타입 | 용도 |
|------|------|
| `architecture-decision` | 아키텍처 결정 사항 |
| `root-cause` | 디버깅 근본 원인 |
| `debug-eliminated` | 배제된 가설 |
| `debug-blocked` | 3-strike 차단 |
| `pattern-discovery` | 발견된 패턴/학습 |
| `deviation` | 계획 대비 이탈 |
| `execution-summary` | 실행 결과 요약 |
| `session-summary` | 세션 종료 요약 (자동) |
| `session-snapshot` | Pre-compact 스냅샷 |
| `session-handoff` | 세션 인수인계 |
| `health-event` | 컨텍스트 건강 이벤트 |
| `bootstrap` | 프로젝트 초기 설정 |
| `security-finding` | 보안 발견 사항 |
| `general` | 기타 |

### A-Mem 확장 필드

```yaml
---
title: "메모리 제목"
tags: [tag1, tag2]
type: architecture-decision
created: 2026-02-06T00:00:00Z
contextual_description: "1줄 요약 (검색 압축용)"
keywords: [키워드1, 키워드2]
related: [다른메모리.md]
---
```

---

## Skills (16)

**Skills**는 Claude가 작업 컨텍스트를 기반으로 **자율적으로 호출**하는 전문 기능입니다.

| Skill | 설명 | 트리거 상황 |
|-------|------|-------------|
| `planner` | 실행 가능한 페이즈 계획 생성 | 계획 수립 요청 시 |
| `plan-checker` | 계획 검증 (6차원 분석) | 계획 생성 후 |
| `executor` | 계획 실행 + atomic commits | 실행 요청 시 |
| `verifier` | spec 대비 검증 + 증거 수집 | 검증 요청 시 |
| `debugger` | 체계적 디버깅 (3-strike rule) | 버그 조사 시 |
| `impact-analysis` | 변경 영향 분석 | 코드 수정 전 |
| `arch-review` | 아키텍처 규칙 검증 | 구조 변경 시 |
| `codebase-mapper` | 코드베이스 구조 분석 | 온보딩/리팩토링 전 |
| `commit` | conventional commit 생성 | 커밋 요청 시 |
| `create-pr` | PR 생성 (gh CLI) | PR 요청 시 |
| `pr-review` | 다중 페르소나 코드 리뷰 | PR 리뷰 요청 시 |
| `clean` | 코드 품질 도구 실행 (shellcheck) | 품질 체크 요청 시 |
| `context-health-monitor` | 컨텍스트 복잡도 모니터링 | 긴 세션 중 |
| `empirical-validation` | 경험적 증거 요구 | 완료 확인 시 |
| `bootstrap` | 프로젝트 초기 설정 | 부트스트랩 요청 시 |
| `memory-protocol` | 메모리 검색/저장 프로토콜 | 메모리 작업 시 |

---

## Agents (14)

**Agents**는 특정 작업에 특화된 **서브에이전트**입니다.

| Agent | 역할 | 탑재 Skills |
|-------|------|-------------|
| `planner` | 페이즈 계획 설계 | planner, memory-protocol |
| `plan-checker` | 계획 검증 | plan-checker |
| `executor` | 계획 실행 | executor, memory-protocol |
| `verifier` | 구현 검증 | verifier |
| `debugger` | 체계적 디버깅 | debugger, context-health-monitor, memory-protocol |
| `impact-analysis` | 변경 영향 분석 | impact-analysis |
| `arch-review` | 아키텍처 검증 | arch-review, memory-protocol |
| `codebase-mapper` | 코드베이스 분석 | codebase-mapper |
| `commit` | 커밋 생성 | commit |
| `create-pr` | PR 생성 | create-pr |
| `pr-review` | PR 리뷰 | pr-review |
| `clean` | 코드 품질 | clean |
| `context-health-monitor` | 컨텍스트 모니터링 | context-health-monitor |
| `bootstrap` | 프로젝트 초기화 | bootstrap, memory-protocol |

---

## Hooks (14)

**Hooks**는 Claude Code 이벤트에 자동으로 응답하는 스크립트입니다.

| 이벤트 | 스크립트 | 기능 |
|--------|----------|------|
| **SessionStart** | `session-start.sh` | STATE.md 로드, git status 주입 |
| **PreToolUse** | `bash-guard.py` | 위험한 명령어 차단 |
| **PreToolUse** | `file-protect.py` | .env, 시크릿 파일 보호 |
| **PostToolUse** | `auto-format.sh` | Python 파일 자동 포맷 |
| **PreCompact** | `pre-compact-save.sh` | 컴팩트 전 상태 저장 |
| **Stop** | `stop-context-save.sh` | 세션 컨텍스트 저장 |
| **Stop** | `post-turn-verify.sh` | 작업 검증 |
| **SessionEnd** | `save-session-changes.sh` | 세션 변경사항 추적 |
| **SessionEnd** | `save-transcript.sh` | 대화 기록 저장 |

### 유틸리티 스크립트

| 스크립트 | 기능 |
|----------|------|
| `md-store-memory.sh` | 파일 기반 메모리 저장 |
| `md-recall-memory.sh` | 파일 기반 메모리 검색 |
| `scaffold-gsd.sh` | GSD 문서 초기화 |
| `compact-context.sh` | 컨텍스트 압축 |
| `organize-docs.sh` | 문서 정리/아카이브 |

---

## GSD 워크플로우

### 핵심 사이클

```
SPEC → PLAN → EXECUTE → VERIFY
```

| 단계 | 설명 |
|------|------|
| **SPEC** | 딥 질문 → SPEC.md 생성 |
| **PLAN** | 페이즈 계획 생성 |
| **EXECUTE** | 웨이브 단위 구현 + atomic commits |
| **VERIFY** | must-haves 검증 + 증거 수집 |

---

## 빌드

이 보일러플레이트를 다양한 형식으로 빌드할 수 있습니다.

| 타겟 | 명령어 | 출력 |
|------|--------|------|
| Claude Code Plugin | `make build-plugin` | `gsd-plugin/` |
| Google Antigravity | `make build-antigravity` | `antigravity-boilerplate/` |
| OpenCode | `make build-opencode` | `opencode-boilerplate/` |

### 자동 릴리즈

**release-please** 기반 GitHub Actions로 자동 릴리즈됩니다.

```
feat: 새 기능 추가 → push to master → Release PR 생성 → 머지 → 자동 릴리즈
```

### GitHub Release에서 설치

```bash
# 최신 버전
VERSION=$(gh release view --json tagName -q .tagName | sed 's/gsd-plugin-v//')
curl -L "https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/latest/download/gsd-plugin-${VERSION}.zip" -o gsd-plugin.zip
unzip gsd-plugin.zip -d ~/.claude/plugins/gsd
```

---

## Make 명령어

```bash
make help                   # 전체 명령어 목록
```

| 명령어 | 설명 |
|--------|------|
| `make setup` | GSD 문서 초기화 |
| `make status` | 환경 상태 확인 |
| `make build` | 3개 빌드 아티팩트 생성 |
| `make build-plugin` | Claude Code 플러그인 빌드 |
| `make build-antigravity` | Antigravity 워크스페이스 빌드 |
| `make build-opencode` | OpenCode 워크스페이스 빌드 |
| `make clean` | 빌드 결과물 삭제 |

---

## 참고 문서

### Claude Code 공식 문서

| 문서 | 설명 |
|------|------|
| [Plugins](https://code.claude.com/docs/en/plugins.md) | 플러그인 생성 가이드 |
| [Hooks](https://code.claude.com/docs/en/hooks.md) | 이벤트 훅 설정 |
| [Skills](https://code.claude.com/docs/en/skills.md) | 스킬 정의 및 활용 |
| [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | 에이전트 frontmatter |

### 커뮤니티 리소스

| 리소스 | 설명 |
|--------|------|
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Claude Code 리소스 큐레이션 |
| [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) | MCP 서버 목록 |

---

## 라이선스

MIT
