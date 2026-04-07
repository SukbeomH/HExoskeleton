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
  <img src="https://img.shields.io/badge/v5.2.1%20%C2%B7%2019%20skills%20%C2%B7%2017%20agents%20%C2%B7%2020%20hooks-orange?style=flat-square" alt="Components" />
  <img src="https://img.shields.io/github/license/SukbeomH/HExoskeleton?style=flat-square" alt="License" />
</p>

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

> **결론**: 외부 종속성 0. 빌드 스크립트 0. 레포지토리 자체가 배포 단위 (Self-Configure 모델).

---

## 아키텍처

```
                    ┌──────────────────────────┐
                    │    GitHub Repository      │
                    │    (= Distribution)       │
                    └──────────┬───────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
        ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼──────┐
        │  llms.txt  │   │ AGENTS.md │   │  prompts/  │
        │  (진입점)  │   │  (공통)   │   │  (setup)   │
        └─────┬──────┘   └───────────┘   └────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼───┐ ┌──▼──┐ ┌───▼────┐
│skills/│ │hooks│ │agents/ │
│  19   │ │ 17  │ │  17    │
└───────┘ └─────┘ └────────┘
```

### Self-Configure 모델

일반적인 프레임워크는 `npm install`, `pip install`, 빌드 스크립트를 요구합니다. HExoskeleton은 다릅니다:

1. 에이전트가 `llms.txt`를 읽어 프로젝트 구조를 파악
2. `setup.md` 프롬프트를 따라 스킬/훅/에이전트를 프로젝트에 배치
3. `bootstrap.sh`가 누락 컴포넌트를 수렴적(idempotent)으로 보충

**빌드 없음, 설치 명령 없음.** 에이전트가 파일을 읽고 복사하는 것이 곧 설치입니다.

### 멀티 에이전트 수렴

하나의 프로젝트를 여러 AI 에이전트가 동시에 관리합니다. 에이전트 지침은 분리하되, 워킹 상태(`.hxsk/`)는 공유합니다.

```
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
│ Claude    │  │ Gemini    │  │ Copilot   │  │ Cursor    │  │ Windsurf  │
│ CLAUDE.md │  │ GEMINI.md │  │ symlink   │  │ symlink   │  │ symlink   │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      └───────────────┼──────────────┼──────────────┼───────────────┘
                      ▼              ▼              ▼
                ┌──────────────────────────────────────┐
                │           .hxsk/ (공유 상태)           │
                │  STATE · SPEC · PATTERNS · memories   │
                │  skills · agents · hooks              │
                └──────────────────────────────────────┘
```

- **에이전트 간 인수인계** — Claude Code로 디버깅 → Cursor로 UI 작업. STATE.md와 메모리가 컨텍스트를 유지
- **Lock-in 없음** — 순수 마크다운이므로 어떤 에이전트든 읽고 쓸 수 있음
- **동시 사용** — 백엔드(Claude) + 프론트엔드(Cursor) 동시 작업 가능

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
| **Skills** | 19 | `.hxsk/skills/` | [docs/SKILLS.md](.hxsk/docs/SKILLS.md) |
| **Agents** | 17 | `.hxsk/agents/` | [docs/AGENTS.md](.hxsk/docs/AGENTS.md) |

### 2. 8-Event Hook 생명주기

Claude Code의 훅 시스템으로 에이전트 행동을 자동화합니다. 7개 이벤트, 20개 스크립트.

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

| 이벤트 | 훅 | 역할 |
|--------|-----|------|
| **SessionStart** | `session-start.sh` | STATE.md + git status 컨텍스트 주입 |
| **PreToolUse** | `file-protect.py`, `bash-guard.py` | .env/시크릿 보호, 파괴적 명령 차단 |
| **PostToolUse** | `auto-format.sh`, `track-modifications.sh` | 자동 포맷, 변경 파일 추적 |
| **PreCompact** | `pre-compact-save.sh` | 컨텍스트 압축 전 스냅샷 |
| **Stop** | `post-turn-verify.sh`, `stop-context-save.sh` | 작업 검증, 세션 컨텍스트 저장 |
| **SubagentStop** | (prompt) | 서브에이전트 결과 요약 |
| **SessionEnd** | `save-transcript.sh`, `save-session-changes.sh` | 대화 내역 + 변경사항 저장 |

> 상세: [docs/HOOKS.md](.hxsk/docs/HOOKS.md)

### 3. 파일 기반 메모리 시스템

[A-Mem](https://arxiv.org/html/2502.12110v11), [Nemori](https://arxiv.org/html/2508.03341v3) 논문의 핵심 개념을 파일 시스템 위에 구현했습니다.

| 개념 | 출처 | HXSK 구현 |
|------|------|-----------|
| Frontmatter 메타데이터 | A-Mem | YAML frontmatter (`title`, `tags`, `keywords`, `related`) |
| 2-Hop 그래프 검색 | A-Mem | `related` 필드 → 관련 메모리까지 자동 추적 |
| Compact 모드 | A-Mem | 제목 + 1줄 요약만 반환 (토큰 최적화) |
| 타입별 분리 | Nemori | 14개 디렉토리 (root-cause, architecture-decision 등) |
| 중복 방지 | Nemori | 동일 제목 저장 시 `[SKIP:DUPLICATE]` |
| Contextual description | Nemori | 검색 시 압축 요약 자동 생성 |

```bash
# 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그1,태그2" "타입"

# 검색 (compact, 2-hop)
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact 2
```

<details>
<summary><strong>14개 메모리 타입</strong></summary>

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

### 5. Lazy Loading 문서 계층

에이전트가 필요한 만큼만 읽도록 3단계로 구조화합니다.

| 레벨 | 내용 | 토큰 | 예시 |
|------|------|------|------|
| **L0** | YAML frontmatter만 | ~50 | 이슈 목록 스캔 |
| **L1** | 본문 (Quick Reference 포함) | ~200-500 | 스킬 개요 파악 |
| **L2** | 관련 SKILL/PLAN/연구 문서 | ~1000+ | 상세 절차 실행 |

`CLAUDE.md`(L1) → `skills/SKILL.md`(L2) → `.hxsk/research/`(L3) 순으로 깊어집니다.

### 6. 수렴적 Bootstrap

`bootstrap.sh`는 멱등(idempotent) 수렴 엔진입니다. 몇 번을 실행해도 동일한 최종 상태에 도달합니다.

```
fresh   → 모든 컴포넌트 생성, 카운트 기록
update  → 기존 카운트와 비교, 변경분만 [NEW]/[UPDATED] 표시
verify  → 구조 검증, 누락 타입 자동 보충
```

---

## Quick Start

AI 에이전트에게 setup 프롬프트를 전달하면 자동으로 프로젝트에 HXSK를 구성합니다.

**[setup.md](.hxsk/prompts/setup.md)** — Claude Code, Gemini, Copilot, Cursor, Windsurf 모두 지원.

> 초기 설치/업데이트를 자동 감지합니다. 빌드 명령 없음.

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
├── .claude/settings.json      # 훅 설정 (8개 이벤트)
└── .hxsk/                     # Single Source of Truth
    ├── skills/                # 스킬 정의 (19) — How
    ├── agents/                # 에이전트 정의 (17) — When/With What
    ├── hooks/                 # 훅 스크립트 (20) — 자동화
    ├── scripts/               # 유틸리티 (bootstrap, issue, merge)
    ├── docs/                  # 상세 문서 (11)
    ├── prompts/               # Setup + 마이그레이션 프롬프트
    ├── templates/             # 문서 템플릿 (30)
    ├── memories/              # 파일 기반 메모리 (14 타입)
    ├── research/              # 연구 문서 (30개, 7개 카테고리)
    ├── issues/                # 파일 기반 이슈 레지스트리
    ├── STATE.md               # 현재 작업 상태
    ├── SPEC.md                # 프로젝트 명세
    ├── PATTERNS.md            # 학습된 패턴
    └── DECISIONS.md           # 아키텍처 결정 기록
```

---

## 연구 기반

현재 아키텍처는 최신 에이전트 메모리 및 추론 최적화 연구를 분석하고 선택적으로 적용한 결과입니다.

| 출처 | 적용한 것 | 적용하지 않은 것 |
|------|-----------|-----------------|
| [A-Mem](https://arxiv.org/html/2502.12110v11) | frontmatter, `related`, 2-hop, compact | Memory Evolution (자동 진화) |
| [Nemori](https://arxiv.org/html/2508.03341v3) | 타입 분리, `[SKIP:DUPLICATE]`, contextual_description | Predict-Calibrate (확률 보정) |
| [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) | SPEC → PLAN → EXECUTE 분리 | 전체 프레임워크 |
| [RLM](https://arxiv.org/html/2512.24601v2) | Agent-Skill 래핑, Phase → Plan → Task | Persistent REPL |
| [Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 간결한 에이전트 정의, 외부 파일 위임 | — |
| [Superpowers](https://github.com/obra/superpowers) | Iron Laws, Gate Functions, 합리화 테이블 패턴 분석 | 스킬 TDD, 2단계 리뷰 (중기 적용) |
| [Meincke et al. (2025)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5357179) | Authority 기반 Iron Laws 설계 근거 (N=28,000, 준수율 33%→72%) | — |
| [Sharma et al. (ICLR 2024)](https://arxiv.org/abs/2310.13548) | 합리화 테이블의 이론적 근거 (RLHF 아첨 메커니즘) | — |
| [SkillReducer (2026)](https://arxiv.org/abs/2603.29919) | CSO 패턴 — description 트리거 최적화 (55K 스킬 분석) | — |

> 상세: [.hxsk/research/INDEX.md](.hxsk/research/INDEX.md)

---

## 상세 문서

| 문서 | 설명 |
|------|------|
| [**Design Philosophy**](.hxsk/docs/DESIGN-PHILOSOPHY.md) | **설계 철학 — 9가지 원칙, 작성 규칙, 연구 근거, 방향성** |
| [Skills](.hxsk/docs/SKILLS.md) | 19개 스킬 상세 |
| [Agents](.hxsk/docs/AGENTS.md) | 17개 에이전트 상세 |
| [Hooks](.hxsk/docs/HOOKS.md) | 훅 시스템 + settings.json 전체 예시 |
| [Memory](.hxsk/docs/MEMORY.md) | 파일 기반 메모리 시스템 |
| [Workflows](.hxsk/docs/WORKFLOWS.md) | SPEC→PLAN→EXECUTE→VERIFY |
| [Conventions](.hxsk/docs/CONVENTIONS.md) | 개발 컨벤션 (Issue, Branch, Commit, PR) |
| [Build](.hxsk/docs/BUILD.md) | Self-Configure 배포 가이드 |
| [Research](.hxsk/research/INDEX.md) | 33개 연구 문서 카탈로그 |

---

## 로드맵

[Superpowers 분석](.hxsk/research/superpowers-analysis.md)과 [근거 논문 리서치](.hxsk/research/superpowers-references.md), [Claude Code 품질 저하 완화 분석](.hxsk/research/claude-code-quality-mitigation.md)을 기반으로 한 개선 계획입니다.

### Phase 1: 규율 강화 (즉시 적용)

에이전트의 규칙 우회·허위 완료·읽기 건너뛰기를 프롬프트 레벨에서 차단합니다.

| 항목 | 내용 | 근거 |
|------|------|------|
| **Iron Laws** | `NO EDIT WITHOUT READ FIRST`, `NO COMPLETION WITHOUT VERIFICATION`, `NO WRITE TO EXISTING FILES` | Meincke+ 2025: Authority 기법으로 준수율 33%→72% |
| **합리화 테이블** | 허위 완료(5항목), Read 건너뛰기(4항목), 파일 덮어쓰기(3항목) | Sharma+ ICLR 2024: RLHF 아첨 메커니즘 차단 |
| **CSO 적용** | 19개 스킬 description을 트리거 조건만으로 최적화 | SkillReducer 2026: 48% 압축 + 2.8% 품질 향상 |
| **Ultrathink 트리거** | 아키텍처 결정·디버깅·리팩토링 시 깊은 thinking 명시 요청 | Anthropic: adaptive thinking under-allocation 대응 |

### Phase 2: 검증 체계 고도화 (중기)

| 항목 | 내용 | 근거 |
|------|------|------|
| **Gate Function 스킬** | 5단계 게이트 (IDENTIFY→RUN→READ→VERIFY→CLAIM) | Anthropic harness blog: 허위 완료 선언 제거 |
| **보조 문서 시스템** | 스킬당 심화 .md (프롬프트 템플릿, 안티패턴, 기법 가이드) | Superpowers: 스킬당 2-3개 보조 문서 패턴 |
| **2단계 리뷰** | spec-reviewer(스펙 준수) + code-reviewer(코드 품질) 분리 | Anthropic multi-agent: 전문 역할 분리로 90%+ 향상 |
| **PreToolUse 훅 강화** | Edit/Write 도구 사용 시 조건부 thinking 요청 주입 | Context rot 방지, 도구 사용 전 검증 |

### Phase 3: 스킬 품질 보증 (장기)

| 항목 | 내용 | 근거 |
|------|------|------|
| **스킬 TDD** | 서브에이전트로 스킬 없이 압박 시나리오 실행 → 스킬 작성 → 재검증 | Superpowers writing-skills: RED→GREEN→REFACTOR |
| **서브에이전트 프롬프트 템플릿** | implementer, reviewer 등 역할별 표준 템플릿 | Superpowers: 컨텍스트 격리 + 구조화된 지시 |
| **합리화 테이블 자동 갱신** | 실제 우회 패턴 수집 → 테이블 업데이트 사이클 | 모델 업데이트 시 행동 변화 추적 |

---

<p align="center">
  <img src="logo.gif" alt="HExoskeleton 워크플로우 데모" width="480" />
  <br><sub>SPEC → PLAN → EXECUTE → VERIFY 워크플로우</sub>
  <br><br>
  MIT License
</p>
