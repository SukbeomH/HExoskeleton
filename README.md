<p align="center">
  <img src="logo.png" alt="HExoskeleton Logo" width="200" />
</p>

<h1 align="center">HExoskeleton</h1>

<p align="center">
  <strong>Get Shit Done</strong> — AI 에이전트의 외골격. 추상화의 늪 없이, 실제 결과물을 내는 개발 방법론.
</p>

<p align="center">
  <a href="#설계-사상">Design</a> &middot;
  <a href="#아키텍처">Architecture</a> &middot;
  <a href="#핵심-개념">Concepts</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href=".hxsk/docs/">Docs</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/stack-bash%20%2B%20markdown-blue?style=flat-square" alt="Bash + Markdown" />
  <img src="https://img.shields.io/badge/multi--agent-5%20platforms-blueviolet?style=flat-square" alt="Multi-Agent" />
  <img src="https://img.shields.io/badge/v5.5.x%20%C2%B7%2024%20skills%20%C2%B7%2018%20agents%20%C2%B7%2027%20hooks-orange?style=flat-square" alt="Components" />
  <img src="https://img.shields.io/github/license/SukbeomH/HExoskeleton?style=flat-square" alt="License" />
</p>

---

> Canonical 카운트와 런타임 표면은 `.hxsk/.bootstrap-version`, `.hxsk/skills/INDEX.md`, `.hxsk/agents/INDEX.md`, `.hxsk/hooks/INDEX.md`를 기준으로 관리합니다. README는 그 구조를 설명하는 공개 진입 문서입니다.

## 빠른 시작 — 3선택

> **어떤 AI 에이전트를 사용 중인가?**
>
> | 에이전트 | 시작 명령 |
> |---------|----------|
> | Claude Code | `bash .hxsk/scripts/install.sh --harness claude-code` |
> | Cursor 1.7+ | `bash .hxsk/scripts/install.sh --harness cursor` |
> | GitHub Copilot CLI | `bash .hxsk/scripts/install.sh --harness copilot` |
> | OpenAI Codex CLI | `bash .hxsk/scripts/install.sh --harness codex` |
> | 기타 (Gemini·Windsurf·OpenCode 등) | [Tier 2·3 설치 안내](.hxsk/adapters/README.md) |
>
> 처음이라면: `.hxsk/prompts/setup.md` Step 1(필수) → Step 4(필수) → 위 명령 순서로 실행

---

## 설계 사상

HExoskeleton은 세 가지 관찰에서 출발합니다.

**1. 에이전트의 네이티브 도구가 이미 강력한 검색 엔진이다.**
`Grep`, `Glob`, `Read` — 코딩 에이전트가 기본 탑재한 도구만으로 파일 시스템을 완전히 탐색할 수 있습니다. 벡터 DB나 MCP 서버를 추가하는 건 복잡성 대비 이득이 적습니다.

**2. 파일 시스템이 곧 데이터베이스다.**
마크다운 파일은 사람이 읽을 수 있고, `git diff`로 변경을 추적할 수 있고, 어떤 에이전트든 `Read` 한 번이면 접근할 수 있습니다. 별도 인프라가 필요 없습니다.

**3. 에이전트는 "어떻게(How)"보다 "언제, 무엇으로(When/With What)"가 중요하다.**
절차는 스킬 문서에, 오케스트레이션은 에이전트 정의에 분리합니다. 에이전트 정의는 ~20-30줄로 유지하고, 상세 절차는 스킬에 위임합니다. 시스템 프롬프트가 짧을수록 에이전트는 정확해집니다.

### 왜 순수 bash + 마크다운인가

| 대안 | 채택하지 않은 이유 |
|------|-------------------|
| 벡터 DB (Qdrant, Weaviate) | 외부 서비스 의존, 설정 복잡도 증가 |
| MCP 서버 | 추가 프로세스 필요, 네트워크 오버헤드 |
| SQLite/JSON | 파일 수준 가독성 저하, Git diff 불가 |
| Python/Node 런타임 | 환경 구성 필수, 에이전트 도구만으로 충분 |

> **결론**: 코어 런타임은 외부 패키지 종속성 0. 빌드 산출물도 없다. 레포지토리 자체가 배포 단위이며, `install.sh`는 복사·링크·설정 병합을 돕는 편의 진입점이다.

---

## 아키텍처

### Self-Configure 모델

`llms.txt` → `setup.md` → `bootstrap.sh` 수렴 엔진. **빌드 산출물은 없고**, `install.sh`는 파일 읽기·복사·심볼릭 링크·설정 병합을 자동화하는 편의 명령입니다.

### 멀티 에이전트 수렴

```
Claude · Gemini · Copilot · Cursor · Windsurf (10+ 하네스)
         ↓ 각자의 진입점 (CLAUDE.md / GEMINI.md / symlink)
         ▼
    .hxsk/ (공유 상태)
    STATE · SPEC · PATTERNS · memories · skills · agents · hooks
```

에이전트 지침은 분리, 워킹 상태(`.hxsk/`)는 공유. Lock-in 없음, 동시 사용 가능.

---

## 핵심 개념

### 1. Skill-Agent 분리 패턴

**Skill = How** (재사용 가능한 절차), **Agent = When/With What** (오케스트레이션).

```
┌─────────────────────────────────────────────┐
│  Agent (~20줄)                               │
│  "디버깅 시 systematic-debugging 스킬 사용"  │
│  "도구: Bash, Read, Grep, Agent"             │
└────────────────────┬────────────────────────┘
                     │ 위임
                     ▼
┌─────────────────────────────────────────────┐
│  Skill (~100-300줄)                          │
│  "1. 에러 메시지 수집"                        │
│  "2. 가설 3개 수립"                           │
│  "3. 가설별 검증..."                          │
└─────────────────────────────────────────────┘
```

에이전트 정의가 간결할수록 에이전트는 정확하게 동작합니다.

| 근거 | 출처 |
|------|------|
| 시스템 프롬프트 ~1,800 토큰이 최적 구간 | Anthropic 내부 테스트 |
| 2,500 토큰 초과 시 환각 34% 증가 | Microsoft/Stanford 연구 |
| "가장 작은 고신호 토큰 집합" | [Anthropic Context Engineering Guide](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) |

| 구성요소 | 개수 | 위치 | 상세 |
|----------|------|------|------|
| **Skills** | 24 | `.hxsk/skills/` | [docs/SKILLS.md](.hxsk/docs/SKILLS.md) |
| **Agents** | 18 | `.hxsk/agents/` | [docs/AGENTS.md](.hxsk/docs/AGENTS.md) |

### 2. 7-Event Hook 생명주기

Claude Code의 훅 시스템으로 에이전트 행동을 자동화합니다. 7개 이벤트, 27개 스크립트.


```
SessionStart ──→ [작업 수행] ──→ SessionEnd
     │               │                │
     ▼               ▼                ▼
 STATE.md 로드    PreToolUse        대화 내역 저장
 메모리 로드      (보안 검사)       세션 변경 추적
                  PostToolUse
                  (포맷, 추적)
                  Stop
                  (검증, 메모리 저장)
                  PreCompact
                  (스냅샷)
                  SubagentStop
                  (결과 요약)
```

> 이벤트별 훅 상세: [docs/HOOKS.md](.hxsk/docs/HOOKS.md)

### 3. 파일 기반 메모리 시스템

[A-Mem](https://arxiv.org/html/2502.12110v11), [Nemori](https://arxiv.org/html/2508.03341v3) 논문의 핵심 개념을 파일 시스템 위에 구현했습니다.

| 개념 | 출처 | HXSK 구현 |
|------|------|-----------|
| Frontmatter 메타데이터 | A-Mem | YAML frontmatter (`title`, `tags`, `keywords`, `related`) |
| 2-Hop 그래프 검색 | A-Mem | `related` 필드 → 관련 메모리까지 자동 추적 |
| 타입별 분리 | Nemori | canonical 17개 + historical ADR-006 + `_schema` |
| 중복 방지 | Nemori | 동일 제목 저장 시 `[SKIP:DUPLICATE]` |

```bash
# 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그1,태그2" "타입"

# 검색 (compact, 2-hop)
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact 2
```

<details>
<summary><strong>canonical 17개 메모리 디렉토리 + ADR-006 historical (v5.5.x)</strong></summary>

디버깅: `root-cause`, `debug-eliminated`, `debug-blocked` · 아키텍처: `architecture-decision`, `pattern-discovery` · 실행: `execution-summary`, `deviation`, `lessons-learned` · 세션: `session-summary`, `session-snapshot`, `session-handoff` · 시스템: `health-event`, `bootstrap`, `security-finding`, `general` · 용어: `term-definition` · 테스트: `test` · historical: `ADR-006`

> `tags: [decision|root-cause|incident]` 보유 파일은 shared-tier로 자동 승격. v5.5.0부터 하네스 독립 prune (cap=5, cooldown=60s).

</details>

> 상세: [docs/MEMORY.md](.hxsk/docs/MEMORY.md)

### 4. SPEC → PLAN → EXECUTE → VERIFY 워크플로우

[ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) 연구의 "계획과 실행의 분리" 개념을 적용합니다.

```
SPEC.md          PLAN.md           실행              검증
(무엇을)    →    (어떻게)     →    (코드 작성)   →   (경험적 증거)
 목표 정의       태스크 분해       atomic commit      실제 실행 결과로
 성공 기준       의존성 정리       PR 단위           성공/실패 판단
 제약 조건       파일 소유권
```

**순차 실행**: SPEC → PLAN → 태스크 순서대로 실행 → VERIFY

**병렬 실행** (Dispatcher): 대규모 작업 시 Wave 기반 병렬 처리

```
Discovery → Issue 생성 (.hxsk/issues/)
├── Wave 할당 (파일 소유권 검증 — 같은 wave 내 동일 파일 수정 금지)
├── Wave 1: Agent(isolation: "worktree") × N개 병렬
├── merge → 통합 검증
├── Wave 2: Agent(isolation: "worktree") × M개 병렬
├── merge → 통합 검증
└── 완료
```

### 5. Git Forge 통합 · Lazy Loading · 수렴적 Bootstrap

**Git Forge**: `GATES.md`가 SPEC→PLAN→EXECUTE→VERIFY→DONE 각 게이트 조건을 정의. `gate-check.sh` 훅 + `forge-detect.sh`(GitHub/GitLab/Gitea 자동 감지)로 집행.

**Lazy Loading**: `CLAUDE.md`(L1, ~50 tokens) → `skills/SKILL.md`(L2) → `.hxsk/research/`(L3). 에이전트가 필요한 깊이만 읽음.

**Bootstrap**: `bootstrap.sh`는 멱등 수렴 엔진 — `fresh/update/verify` 어느 모드든 동일 최종 상태 보장.

> Git Forge 상세: [설계 문서](.hxsk/docs/plans/2026-04-15-github-task-management-design.md)

---

## Quick Start

AI 에이전트에게 setup 프롬프트를 전달하면 자동으로 프로젝트에 HXSK를 구성합니다.

**[setup.md](.hxsk/prompts/setup.md)** — Claude Code, Gemini, Copilot, Cursor, Windsurf 모두 지원.

> 초기 설치/업데이트를 자동 감지합니다. 별도 빌드 단계는 없고, 설치는 파일 배치와 설정 병합으로 수렴합니다.

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

</details>

---

## 디렉토리 구조

```
.
├── CLAUDE.md                  # Claude Code 지침 (L1)
├── AGENTS.md                  # 공통 에이전트 지침
├── GEMINI.md                  # Gemini 지침
├── .cursorrules → AGENTS.md   # Cursor symlink
├── .windsurfrules → AGENTS.md # Windsurf symlink
├── llms.txt                   # LLM 진입점 (Self-Configure 시작)
├── .claude/settings.json      # 훅 설정 (7개 이벤트)
└── .hxsk/                     # Single Source of Truth
    ├── skills/                # 스킬 정의 (24) — How
    ├── agents/                # 에이전트 정의 (18) — When/With What
    ├── hooks/                 # 훅 스크립트 (27) — 자동화
    ├── scripts/               # 유틸리티 (bootstrap, verify, issue, forge, release)
    ├── workflow/              # 게이트 기반 작업 관리 (GATES.md)
    ├── docs/                  # 상세 운영 문서
    ├── prompts/               # Setup + 마이그레이션 프롬프트
    ├── templates/             # 문서 템플릿
    ├── memories/              # 파일 기반 메모리 + 스키마
    ├── research/              # 연구·근거 문서
    ├── issues/                # 파일 기반 이슈 레지스트리
    ├── STATE.md               # 현재 작업 상태
    ├── SPEC.md                # 프로젝트 명세
    ├── PATTERNS.md            # 학습된 패턴
    └── DECISIONS.md           # 아키텍처 결정 기록
```

---

## 연구 기반

현재 아키텍처는 최신 에이전트 메모리 및 추론 최적화 연구를 선택적으로 적용한 결과입니다.

핵심 출처: [A-Mem](https://arxiv.org/html/2502.12110v11) · [Nemori](https://arxiv.org/html/2508.03341v3) · [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) · [RLM](https://arxiv.org/html/2512.24601v2) · [Anthropic Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) · [Superpowers](https://github.com/obra/superpowers) · [SkillReducer (2026)](https://arxiv.org/abs/2603.29919) · [Meincke et al. (2025)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5357179) · [Sharma et al. ICLR 2024](https://arxiv.org/abs/2310.13548)

> 상세: [.hxsk/research/INDEX.md](.hxsk/research/INDEX.md)

---

## 상세 문서

[Design Philosophy](.hxsk/docs/DESIGN-PHILOSOPHY.md) · [Skills](.hxsk/docs/SKILLS.md) · [Agents](.hxsk/docs/AGENTS.md) · [Hooks](.hxsk/docs/HOOKS.md) · [Memory](.hxsk/docs/MEMORY.md) · [Workflows](.hxsk/docs/WORKFLOWS.md) · [Conventions](.hxsk/docs/CONVENTIONS.md) · [Build](.hxsk/docs/BUILD.md) · [Research](.hxsk/research/INDEX.md)

공개 문서: [docs/](docs/) — codebase-summary · system-architecture · deployment-guide · testing-guide · configuration-guide · code-standards · project-roadmap · project-overview-pdr

---

## 로드맵

현재 공개 문서 기준 라인은 **v5.5.x**입니다. 최근 반영된 완료 범위는 하네스 독립 prune(v5.5.0), 신뢰성 17건 수정(PR #137), test 메모리 확장(PR #138), 보안 강화(Phase 8), Progressive Disclosure(PR #144)입니다.

주요 완료 마일스톤: Iron Laws · 합리화 테이블 · CSO · Git Forge 통합(GATES.md) · 하네스 독립 prune · 보안 강화 · Progressive Disclosure.

상세 로드맵: [docs/project-roadmap.md](docs/project-roadmap.md)

---

<p align="center">
  <img src="logo.gif" alt="HExoskeleton 워크플로우 데모" width="480" />
  <br><sub>SPEC → PLAN → EXECUTE → VERIFY 워크플로우</sub>
  <br><br>
  MIT License
</p>
