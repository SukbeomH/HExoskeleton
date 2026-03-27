<p align="center">
  <img src="logo.png" alt="HExoskeleton Logo" width="200" />
</p>

<h1 align="center">HExoskeleton</h1>

<p align="center">
  <strong>Get Shit Done</strong> — 추상화의 늪 없이, 실제 결과물을 내는 AI 에이전트 개발 프레임워크
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#왜-hexoskeleton인가">Why</a> &middot;
  <a href="#핵심-구성요소">Components</a> &middot;
  <a href="#멀티-에이전트-하나의-프로젝트">Multi-Agent</a> &middot;
  <a href="#메모리-시스템">Memory</a> &middot;
  <a href="docs/">Docs</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue?style=flat-square" alt="Bash + Markdown" />
  <img src="https://img.shields.io/badge/multi--agent-5%20platforms-blueviolet?style=flat-square" alt="Multi-Agent" />
  <img src="https://img.shields.io/badge/19%20skills%20%C2%B7%2017%20agents%20%C2%B7%2017%20hooks-orange?style=flat-square" alt="Components" />
  <img src="https://img.shields.io/github/license/SukbeomH/HExoskeleton?style=flat-square" alt="License" />
</p>

---

## Quick Start

AI 에이전트에게 setup 프롬프트를 전달하면 자동으로 프로젝트에 HXSK를 구성합니다.

**[setup.md](.hxsk/prompts/setup.md)** — 에이전트 유형을 자동 감지하여 Claude Code, Gemini, Copilot, Cursor, Windsurf 등 모두 지원합니다.

> **외부 종속성 없음** — 초기 설치/업데이트 자동 감지. `SPEC → PLAN → EXECUTE → VERIFY`

<details>
<summary><strong>직접 코드를 받고 싶다면</strong></summary>
<br>

```bash
git clone https://github.com/SukbeomH/HExoskeleton.git
cd HExoskeleton
make setup
```

| 명령어 | 설명 |
|--------|------|
| `/bootstrap` | 프로젝트 분석 및 메모리 초기화 |
| `/planner` | SPEC 기반 실행 계획 수립 |
| `/executor` | 계획 실행 (atomic commits) |
| `/verifier` | 경험적 증거 기반 결과 검증 |

> `make help`로 전체 명령어를 확인할 수 있습니다.

</details>

---

## 왜 HExoskeleton인가

대부분의 AI 에이전트 프레임워크는 Python, Node.js, 벡터 DB, MCP 서버 등 복잡한 스택을 요구합니다. HExoskeleton은 반대 방향을 선택했습니다.

| 구분 | HExoskeleton | 일반 AI 프레임워크 |
|------|-----------------|-------------------|
| **의존성** | 없음 (Bash + Markdown) | 높음 (Python, Node.js, DB) |
| **메모리** | 파일 기반 2-Hop 그래프 검색 | 벡터 DB 유사도 검색 |
| **감사(Audit)** | Git 추적 가능 (Markdown) | 블랙박스 |
| **학습 곡선** | 낮음 (파일 수정 위주) | 높음 (SDK/API 학습 필요) |
| **환경** | 5개 에이전트 네이티브 지원 | 범용, 별도 래퍼 필요 |

**핵심 원칙:** 에이전트의 네이티브 도구(`Grep`, `Glob`, `Read`)가 이미 강력한 검색 엔진입니다. 파일 시스템이 곧 데이터베이스입니다.

---

## 핵심 구성요소

| 구성요소 | 개수 | 설명 | 상세 |
|----------|------|------|------|
| **Skills** | 19 | Claude가 자율 호출하는 기능 단위 (How) | [docs/SKILLS.md](.hxsk/docs/SKILLS.md) |
| **Agents** | 17 | 스킬을 조합하는 서브에이전트 (When/With What) | [docs/AGENTS.md](.hxsk/docs/AGENTS.md) |
| **Hooks** | 17 | 이벤트 기반 자동화 (가드레일, 상태 저장) | [docs/HOOKS.md](.hxsk/docs/HOOKS.md) |
| **Memory** | 14 types | A-Mem 확장 파일 기반 메모리 (2-hop) | [docs/MEMORY.md](.hxsk/docs/MEMORY.md) |

**Skill**(How)과 **Agent**(When/With What)를 분리하여 유지보수성과 자율성을 동시에 확보합니다.

<details>
<summary><strong>상세 문서</strong></summary>
<br>

| 문서 | 설명 |
|------|------|
| [Build](.hxsk/docs/BUILD.md) | Self-Configure 배포 가이드 |
| [Workflows](.hxsk/docs/WORKFLOWS.md) | 워크플로우 상세 |
| [Conventions](.hxsk/docs/CONVENTIONS.md) | 개발 컨벤션 (Issue, Branch, Commit, PR) |
| [Linting](.hxsk/docs/LINTING.md) | 린팅 설정 |
| [MCP](.hxsk/docs/MCP.md) | MCP 서버 통합 |
| [Research](.hxsk/research/INDEX.md) | 리서치 문서 카탈로그 (30개, 6개 카테고리) |

</details>

---

## 멀티 에이전트, 하나의 프로젝트

HExoskeleton은 **하나의 프로젝트를 여러 AI 에이전트가 동시에 관리**할 수 있도록 설계되었습니다. 에이전트 지침은 분리하되, 워킹 상태(`.hxsk/`)는 공유합니다.

```
┌─────────────────────────────────────────────────────┐
│                    프로젝트                           │
│                                                     │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
│  │ Claude    │  │ Gemini    │  │ Cursor    │       │
│  │ CLAUDE.md │  │ GEMINI.md │  │ AGENTS.md │       │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │
│        └───────────────┼───────────────┘             │
│                        ▼                             │
│              ┌──────────────────┐                    │
│              │     .hxsk/       │                    │
│              │  STATE · SPEC    │                    │
│              │  memories        │                    │
│              │  skills · hooks  │                    │
│              └──────────────────┘                    │
└─────────────────────────────────────────────────────┘
```

- **에이전트 간 인수인계** — Claude Code로 디버깅 → Cursor로 UI 작업. `.hxsk/STATE.md`와 메모리가 컨텍스트 유지.
- **Lock-in 없음** — 순수 마크다운이므로 어떤 에이전트든 읽고 쓸 수 있음.
- **동시 사용** — 백엔드(Claude Code) + 프론트엔드(Cursor) 동시 작업 가능.

### 에이전트별 자동 로드

`AGENTS.md`를 각 에이전트의 자동 로드 경로에 심볼릭 링크로 연결합니다.

| 에이전트 | 자동 로드 경로 | 방식 |
|----------|--------------|------|
| Claude Code | `CLAUDE.md` | 루트 자동 로드 |
| Gemini CLI | `GEMINI.md` | 루트 자동 로드 |
| GitHub Copilot | `.github/copilot-instructions.md` | → `AGENTS.md` symlink |
| Cursor | `.cursorrules` | → `AGENTS.md` symlink |
| Windsurf | `.windsurfrules` | → `AGENTS.md` symlink |

### 새 프로젝트에 적용

상단 [Quick Start](#quick-start)의 setup 프롬프트를 에이전트에게 전달하세요. 두 프롬프트를 **동시에 적용**할 수 있습니다. Claude Code 전용 훅은 `.claude/settings.json`에만 등록되므로 다른 에이전트에 영향을 주지 않습니다.

---

## 메모리 시스템

순수 bash + 마크다운 파일 기반 에이전트 메모리. [A-Mem](https://arxiv.org/html/2502.12110v11), [Nemori](https://arxiv.org/html/2508.03341v3), ReWOO 논문의 핵심 개념을 파일 시스템 위에 구현했습니다.

- **2-Hop 그래프 검색** — `related` 필드로 메모리 간 연결, 관련 메모리까지 자동 추적
- **중복 방지** — 동일 제목 저장 시 자동 스킵 (`[SKIP:DUPLICATE]`)
- **토큰 최적화** — `compact` 모드로 제목 + 1줄 요약만 반환
- **완전한 감사 추적** — 모든 메모리가 Markdown 파일, Git diff 가능

```bash
# 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그1,태그2" "타입"

# 검색 (compact)
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact

# 2-hop 검색
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact 2
```

<details>
<summary><strong>메모리 타입 (14개)</strong></summary>
<br>

| 카테고리 | 타입 | 용도 |
|----------|------|------|
| **디버깅** | `root-cause` | 근본 원인 분석 |
| | `debug-eliminated` | 배제된 가설 |
| | `debug-blocked` | 3-strike 차단 |
| **아키텍처** | `architecture-decision` | 아키텍처 결정 사항 |
| | `pattern-discovery` | 발견된 패턴/학습 |
| **실행** | `execution-summary` | 실행 결과 요약 |
| | `deviation` | 계획 대비 이탈 |
| **세션** | `session-summary` | 세션 종료 요약 (자동) |
| | `session-snapshot` | Pre-compact 스냅샷 |
| | `session-handoff` | 세션 인수인계 |
| **시스템** | `health-event` | 컨텍스트 건강 이벤트 |
| | `bootstrap` | 프로젝트 초기 설정 |
| | `security-finding` | 보안 발견 사항 |
| | `general` | 기타 |

</details>

> 상세: [docs/MEMORY.md](.hxsk/docs/MEMORY.md)

---

<details>
<summary><strong>디렉토리 구조</strong></summary>
<br>

```
.
├── CLAUDE.md                  # Claude Code 지침
├── AGENTS.md                  # 공통 에이전트 지침
├── GEMINI.md                  # Gemini 지침
├── .cursorrules → AGENTS.md   # Cursor symlink
├── .windsurfrules → AGENTS.md # Windsurf symlink
├── llms.txt                   # LLM 진입점
├── .claude/settings.json      # 훅 설정
├── .hxsk/                     # HXSK 핵심 (Single Source of Truth)
│   ├── skills/                # 스킬 정의 (19)
│   ├── agents/                # 서브에이전트 정의 (17)
│   ├── hooks/                 # 훅 스크립트 (17)
│   ├── memories/              # 파일 기반 메모리 (14 타입)
│   ├── research/              # 리서치 문서 (30개, 6 카테고리)
│   ├── STATE.md               # 현재 작업 상태
│   └── PATTERNS.md            # 핵심 패턴/학습
│   ├── prompts/              # Setup 프롬프트
│   ├── docs/                 # 상세 문서
│   └── scripts/              # 유틸리티 스크립트
```

</details>

<details>
<summary><strong>참고 문서</strong></summary>
<br>

| 구분 | 링크 | 설명 |
|------|------|------|
| Claude Code | [Hooks](https://code.claude.com/docs/en/hooks.md) | 이벤트 훅 설정 |
| Claude Code | [Skills](https://code.claude.com/docs/en/skills.md) | 스킬 정의 및 활용 |
| Claude Code | [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | 에이전트 frontmatter |
| Community | [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Claude Code 리소스 큐레이션 |
| Community | [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) | MCP 서버 목록 |

</details>

---

<details>
<summary><strong>설계 배경 (Design Rationale)</strong></summary>
<br>

현재 아키텍처는 최신 에이전트 메모리 및 추론 최적화 연구들을 분석하고 선택적으로 적용한 결과입니다.

#### 왜 순수 bash + 마크다운인가?

| 대안 | 채택하지 않은 이유 |
|------|-------------------|
| 벡터 DB (Qdrant, Weaviate) | 외부 서비스 의존, 설정 복잡도 증가 |
| MCP 서버 | 추가 프로세스 필요, 네트워크 오버헤드 |
| SQLite/JSON | 파일 수준 가독성 저하, Git diff 불가 |

#### 연구 기반

| 출처 | 적용 |
|------|------|
| [A-Mem](https://arxiv.org/html/2502.12110v11) | frontmatter 필드, `related`, 2-hop 검색, compact 모드 |
| [Nemori](https://arxiv.org/html/2508.03341v3) | 타입 분리, `[SKIP:DUPLICATE]`, contextual_description |
| [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) | SPEC → PLAN → EXECUTE 분리 |
| [RLM](https://arxiv.org/html/2512.24601v2) | Agent-Skill 래핑, Phase → Plan → Task |

#### 왜 에이전트 정의는 간결하게?

에이전트 정의(`.hxsk/agents/*.md`)는 ~20-30줄로 유지하고, 절차적 상세는 스킬에 위임합니다.

| 근거 | 출처 |
|------|------|
| 시스템 프롬프트 ~1,800 토큰이 최적 구간 | Anthropic 내부 테스트 (2차 출처) |
| 2,500 토큰 초과 시 환각 34% 증가 | Microsoft/Stanford 연구 |
| "가장 작은 고신호 토큰 집합" 권장 | [Anthropic Context Engineering Guide](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) |
| description 품질 > 길이 | [Claude Code Sub-agents Docs](https://code.claude.com/docs/en/sub-agents) |
| 외부 파일 위임 패턴 | Deep Agents 연구 |

**채택하지 않은 것:** Memory Evolution (A-Mem), Predict-Calibrate (Nemori), Persistent REPL (RLM), 상세 에이전트 프롬프트 (100+줄)

> 상세: [.hxsk/research/INDEX.md](.hxsk/research/INDEX.md)

</details>

---

<p align="center">
  <img src="logo.gif" alt="HExoskeleton 워크플로우 데모" width="480" />
  <br><sub>SPEC → PLAN → EXECUTE → VERIFY 워크플로우</sub>
  <br><br>
  MIT License
</p>
