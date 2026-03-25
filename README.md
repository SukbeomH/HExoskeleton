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
  <a href="#메모리-시스템">Memory</a> &middot;
  <a href="docs/">Docs</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue?style=flat-square" alt="Bash + Markdown" />
  <img src="https://img.shields.io/badge/optimized%20for-Claude%20Code-blueviolet?style=flat-square" alt="Claude Code" />
  <img src="https://img.shields.io/github/license/SukbeomH/HExoskeleton?style=flat-square" alt="License" />
</p>

---

## Quick Start

### 1. Setup Prompt로 새 프로젝트에 적용

에이전트에게 setup 프롬프트를 전달하면 스킬, 훅, 문서 구조가 자동 구성됩니다.

| 프롬프트 | 대상 | 설명 |
|----------|------|------|
| [setup-claude.md](prompts/setup-claude.md) | Claude Code | Claude Code 전용 setup |
| [setup.md](prompts/setup.md) | 범용 | 다른 AI 에이전트용 setup |

### 2. 또는 이 레포를 직접 사용

```bash
git clone https://github.com/SukbeomH/HExoskeleton.git
cd HExoskeleton
make setup
```

### 3. 워크플로우 시작

```
SPEC → PLAN → EXECUTE → VERIFY
```

```
/bootstrap    # 프로젝트 분석 및 메모리 초기화
/planner      # SPEC 기반 실행 계획 수립
/executor     # 계획 실행 (atomic commits)
/verifier     # 경험적 증거 기반 결과 검증
```

> **외부 종속성 없음** — Node.js, Python 환경, MCP 서버, 벡터 DB 불필요.

---

## 왜 HExoskeleton인가

대부분의 AI 에이전트 프레임워크는 Python, Node.js, 벡터 DB, MCP 서버 등 복잡한 스택을 요구합니다. HExoskeleton은 반대 방향을 선택했습니다.

| 구분 | HExoskeleton | 일반 AI 프레임워크 |
|------|-----------------|-------------------|
| **의존성** | 없음 (Bash + Markdown) | 높음 (Python, Node.js, DB) |
| **메모리** | 파일 기반 2-Hop 그래프 검색 | 벡터 DB 유사도 검색 |
| **감사(Audit)** | Git 추적 가능 (Markdown) | 블랙박스 |
| **학습 곡선** | 낮음 (파일 수정 위주) | 높음 (SDK/API 학습 필요) |
| **환경** | Claude Code 네이티브 최적화 | 범용, 별도 래퍼 필요 |

**핵심 원칙:** Claude Code의 네이티브 도구(`Grep`, `Glob`, `Read`)가 이미 강력한 검색 엔진입니다. 파일 시스템이 곧 데이터베이스입니다.

---

## 핵심 구성요소

| 구성요소 | 개수 | 설명 | 상세 |
|----------|------|------|------|
| **Skills** | 18 | Claude가 자율 호출하는 기능 단위 (How) | [docs/SKILLS.md](docs/SKILLS.md) |
| **Agents** | 16 | 스킬을 조합하는 서브에이전트 (When/With What) | [docs/AGENTS.md](docs/AGENTS.md) |
| **Hooks** | 11 | 이벤트 기반 자동화 (가드레일, 상태 저장) | [docs/HOOKS.md](docs/HOOKS.md) |
| **Memory** | 14 types | A-Mem 확장 파일 기반 메모리 (2-hop) | [docs/MEMORY.md](docs/MEMORY.md) |

### Agent-Skill 아키텍처

```
┌─────────────────────────────────────────────────┐
│  Agent (When / With What)                       │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐     │
│  │  Skill A  │ │  Skill B  │ │  Skill C  │     │
│  │  (How)    │ │  (How)    │ │  (How)    │     │
│  └───────────┘ └───────────┘ └───────────┘     │
└─────────────────────────────────────────────────┘
```

- **Skill**: 재사용 가능한 최소 기능 단위. 절차와 규칙을 정의.
- **Agent**: 스킬을 탑재하고 오케스트레이션. 상황에 맞는 스킬을 자율 선택.

### 문서

| 문서 | 설명 |
|------|------|
| [Build](docs/BUILD.md) | Self-Configure 배포 가이드 |
| [Workflows](docs/WORKFLOWS.md) | 워크플로우 상세 |
| [Conventions](docs/CONVENTIONS.md) | 개발 컨벤션 (Issue, Branch, Commit, PR) |
| [Linting](docs/LINTING.md) | 린팅 설정 |
| [MCP](docs/MCP.md) | MCP 서버 통합 |
| [Research](.hxsk/research/INDEX.md) | 리서치 문서 카탈로그 (30개, 6개 카테고리) |

---

## 메모리 시스템

순수 bash + 마크다운 파일 기반 에이전트 메모리. [A-Mem](https://arxiv.org/html/2502.12110v11), [Nemori](https://arxiv.org/html/2508.03341v3), ReWOO 논문의 핵심 개념을 파일 시스템 위에 구현했습니다.

```
┌──────────────┐     related     ┌──────────────┐
│  Memory A    │ ──────────────→ │  Memory B    │
│  (root-cause)│                 │  (pattern)   │
└──────┬───────┘                 └──────┬───────┘
       │            2-hop               │
       └────────────────────────────────┘
```

### 특징

- **2-Hop 그래프 검색** — `related` 필드로 메모리 간 연결, 관련 메모리까지 자동 추적
- **중복 방지** — 동일 제목 저장 시 자동 스킵 (`[SKIP:DUPLICATE]`)
- **토큰 최적화** — `compact` 모드로 제목 + 1줄 요약만 반환
- **완전한 감사 추적** — 모든 메모리가 Markdown 파일, Git diff 가능

### 사용법

```bash
# 저장
bash scripts/md-store-memory.sh "제목" "내용" "태그1,태그2" "타입"

# 검색 (compact)
bash scripts/md-recall-memory.sh "검색어" "." 5 compact

# 2-hop 검색
bash scripts/md-recall-memory.sh "검색어" "." 5 compact 2
```

### 메모리 타입 (14개)

| 타입 | 용도 | | 타입 | 용도 |
|------|------|-|------|------|
| `architecture-decision` | 아키텍처 결정 | | `session-summary` | 세션 종료 요약 (자동) |
| `root-cause` | 디버깅 근본 원인 | | `session-snapshot` | Pre-compact 스냅샷 |
| `debug-eliminated` | 배제된 가설 | | `session-handoff` | 세션 인수인계 |
| `debug-blocked` | 3-strike 차단 | | `health-event` | 컨텍스트 건강 이벤트 |
| `pattern-discovery` | 발견된 패턴 | | `bootstrap` | 프로젝트 초기 설정 |
| `deviation` | 계획 대비 이탈 | | `security-finding` | 보안 발견 사항 |
| `execution-summary` | 실행 결과 요약 | | `general` | 기타 |

> 상세: [docs/MEMORY.md](docs/MEMORY.md)

---

## 디렉토리 구조

```
.
├── .claude/                   # Claude Code 설정
│   └── settings.json          # 훅 설정
├── .hxsk/                     # HXSK 핵심 (Single Source of Truth)
│   ├── skills/                # 스킬 정의 (18)
│   ├── agents/                # 서브에이전트 정의 (16)
│   ├── hooks/                 # 훅 스크립트 (11) + 유틸리티
│   ├── memories/              # 파일 기반 메모리 (14 타입)
│   ├── STATE.md               # 현재 작업 상태
│   └── PATTERNS.md            # 핵심 패턴/학습
├── prompts/                   # Setup 프롬프트
├── docs/                      # 상세 문서
├── scripts/                   # 유틸리티 스크립트
├── CLAUDE.md                  # Claude Code 지침
├── AGENTS.md                  # 공통 에이전트 지침
├── GEMINI.md                  # Gemini 지침
└── llms.txt                   # LLM 진입점
```

---

## Make 명령어

```bash
make help                   # 전체 명령어 목록
make setup                  # 전체 초기 설정 (의존성 확인 + 환경)
make status                 # 환경 상태 확인
make check-deps             # 필수 도구 설치 확인
```

---

## 참고 문서

| 구분 | 링크 | 설명 |
|------|------|------|
| Claude Code | [Hooks](https://code.claude.com/docs/en/hooks.md) | 이벤트 훅 설정 |
| Claude Code | [Skills](https://code.claude.com/docs/en/skills.md) | 스킬 정의 및 활용 |
| Claude Code | [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | 에이전트 frontmatter |
| Community | [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Claude Code 리소스 큐레이션 |
| Community | [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) | MCP 서버 목록 |

---

<details>
<summary><strong>설계 배경 (Design Rationale)</strong></summary>

현재 아키텍처는 최신 에이전트 메모리 및 추론 최적화 연구들을 분석하고 선택적으로 적용한 결과입니다.

### 왜 순수 bash + 마크다운인가?

| 대안 | 장점 | 채택하지 않은 이유 |
|------|------|-------------------|
| 벡터 DB (Qdrant, Weaviate) | 의미적 유사도 검색 | 외부 서비스 의존, 설정 복잡도 증가 |
| MCP 서버 | 표준화된 인터페이스 | 추가 프로세스 필요, 네트워크 오버헤드 |
| SQLite/JSON | 구조화된 쿼리 | 파일 수준 가독성 저하, Git diff 불가 |

### 연구 기반

| 출처 | 채택한 것 | 적용 |
|------|----------|------|
| [A-Mem](https://arxiv.org/html/2502.12110v11) | 7-속성 노트, Link Generation, 그래프 탐색, 토큰 절감 | frontmatter 필드, `related`, 2-hop 검색, compact 모드 |
| [Nemori](https://arxiv.org/html/2508.03341v3) | Episodic+Semantic 이중 메모리, 중복 제거, 서사화 | 타입 분리, `[SKIP:DUPLICATE]`, contextual_description |
| [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) | 계획-실행 분리 (5x 효율) | SPEC → PLAN → EXECUTE 분리 |
| [RLM](https://arxiv.org/html/2512.24601v2) | Root/Sub-LLM 분리, 재귀적 분할 | Agent-Skill 래핑, Phase → Plan → Task |

**채택하지 않은 것:**
- Memory Evolution (A-Mem) — write-once로 감사 추적성 유지
- Predict-Calibrate (Nemori) — LLM 추가 호출 비용 대비 효용 불확실
- Persistent REPL (RLM) — 현재 사용 사례에서 필요성 낮음

```
┌─────────────────────────────────────────────────────────────┐
│  최소 종속성 원칙                                             │
│  외부 서비스 = 0 │ MCP 서버 = 선택적 │ 순수 bash + 마크다운    │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   A-Mem 스타일          Nemori 스타일         토큰 최적화
   연결 그래프           이중 메모리 분류       계획-실행 분리
   2-hop 검색            중복 제거             적응적 탐색
```

> 상세 리서치 문서: `.hxsk/research/`

</details>

---

<p align="center">
  <img src="logo.gif" alt="HExoskeleton Demo" width="480" />
</p>

<p align="center">
  MIT License
</p>
