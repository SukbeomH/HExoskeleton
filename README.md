<p align="center">
  <img src="logo.png" alt="HExoskeleton Logo" width="200" />
</p>

# HExoskeleton

> **Get Shit Done** — 추상화의 늪 없이, 실제 결과물을 내는 AI 에이전트 개발 프레임워크.

Claude Code 네이티브 환경에 최적화된 **에이전틱 워크플로우(Agentic Workflow)** 보일러플레이트입니다. 순수 bash 스크립트와 마크다운 파일만으로 최신 AI 메모리 연구(A-Mem, Nemori, ReWOO)를 실무 수준으로 구현했습니다.

```
SPEC → PLAN → EXECUTE → VERIFY
```

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

| 구성요소 | 개수 | 설명 |
|----------|------|------|
| **Skills** | 18 | Claude가 상황을 인식하여 자율 호출하는 기능 단위 (How) |
| **Agents** | 16 | 스킬을 조합하고 오케스트레이션하는 서브에이전트 (When/With What) |
| **Hooks** | 11 | 이벤트 기반 자동화 (가드레일, 상태 저장, 검증) |
| **Memory System** | 14 types | A-Mem 확장 파일 기반 메모리 (2-hop 검색, 중복 방지) |

### 상세 문서

| 문서 | 설명 |
|------|------|
| [Agents](docs/AGENTS.md) | 16개 서브에이전트 (역할, capabilities, 실행 흐름) |
| [Skills](docs/SKILLS.md) | 18개 스킬 (트리거 조건, 도구 연동) |
| [Hooks](docs/HOOKS.md) | 11개 훅 이벤트 (이벤트, 코드, 작동 예시) |
| [Memory](docs/MEMORY.md) | 파일 기반 메모리 시스템 상세 |
| [Build](docs/BUILD.md) | Self-Configure 배포 가이드 |
| [Linting](docs/LINTING.md) | 린팅 설정 가이드 |
| [MCP](docs/MCP.md) | MCP 서버 통합 |
| [Workflows](docs/WORKFLOWS.md) | 워크플로우 상세 |
| [Conventions](docs/CONVENTIONS.md) | 개발 컨벤션 (Issue, Branch, Commit, PR, Release) |

---

## 디렉토리 구조

```
.
├── .claude/                   # Claude Code 설정
│   └── settings.json          # 훅 설정
├── .hxsk/                     # HXSK 핵심 디렉토리 (Single Source of Truth)
│   ├── skills/                # 스킬 정의 (18)
│   ├── agents/                # 서브에이전트 정의 (16)
│   ├── hooks/                 # 훅 스크립트 (11) + 유틸리티
│   ├── STATE.md               # 현재 작업 상태 (git 추적)
│   ├── PATTERNS.md            # 핵심 패턴/학습 (git 추적)
│   ├── memories/              # 파일 기반 메모리 (14 타입)
│   │   ├── _schema/           # JSON Schema + 타입 관계
│   │   ├── architecture-decision/
│   │   ├── root-cause/
│   │   ├── session-summary/
│   │   └── ...
│   ├── templates/             # 문서 템플릿 (git 추적)
│   ├── examples/              # 예제 (git 추적)
│   └── issues/                # 이슈 관리
├── prompts/                   # Setup 프롬프트
│   ├── setup.md               # 범용 setup 프롬프트
│   └── setup-claude.md        # Claude Code 전용 setup 프롬프트
├── docs/                      # 상세 문서
├── scripts/                   # 유틸리티 스크립트
│   ├── bootstrap.sh           # 프로젝트 부트스트랩
│   ├── verify-self-configure.sh # Self-Configure 검증
│   ├── md-store-memory.sh     # 메모리 저장
│   ├── md-recall-memory.sh    # 메모리 검색
│   └── detect-language.sh     # 언어 감지
├── Makefile                   # 개발 명령어
├── CLAUDE.md                  # Claude Code 지침
├── AGENTS.md                  # 공통 에이전트 지침
├── GEMINI.md                  # Gemini 지침
└── llms.txt                   # LLM 진입점
```

---

## Quick Start

### 1. Self-Configure (Setup Prompt)

새 프로젝트에 HExoskeleton을 적용하려면, 에이전트에게 setup 프롬프트를 전달합니다.

```bash
# Claude Code에서 — setup 프롬프트 실행
# prompts/setup-claude.md 내용을 에이전트에 전달하면
# 스킬, 훅, 문서 구조가 자동으로 구성됩니다.
```

또는 이 레포를 직접 사용:

```bash
git clone https://github.com/SukbeomH/HExoskeleton.git
cd HExoskeleton
make setup
```

### 2. 워크플로우 시작

```
/bootstrap    # 프로젝트 분석 및 메모리 초기화
/planner      # SPEC 기반 실행 계획 수립
/executor     # 계획 실행 (atomic commits)
/verifier     # 경험적 증거 기반 결과 검증
```

**외부 종속성 없음** — Node.js, Python 환경, MCP 서버, 벡터 DB 불필요.

---

## 메모리 시스템

순수 bash + 마크다운 파일 기반 에이전트 메모리. A-Mem, Nemori, ReWOO 논문의 핵심 개념을 파일 시스템 위에 구현했습니다.

### 설계 원칙

- **2-Hop 그래프 검색**: `related` 필드로 메모리 간 연결 → 관련 메모리까지 자동 추적
- **중복 방지 (Nemori)**: 동일 제목이 같은 날 저장되면 자동 스킵 (`[SKIP:DUPLICATE]`)
- **토큰 최적화 (ReWOO)**: `compact` 모드로 제목 + 1줄 요약만 반환 — 컨텍스트 절감
- **완전한 감사 추적**: 모든 메모리가 Markdown 파일 → Git 추적 가능, 블랙박스 없음

### 저장

```bash
bash scripts/md-store-memory.sh \
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
bash scripts/md-recall-memory.sh "검색어" "." 5 compact

# full 모드 (전체 내용)
bash scripts/md-recall-memory.sh "검색어" "." 5 full

# 2-hop 검색 (related 필드 추적)
bash scripts/md-recall-memory.sh "검색어" "." 5 compact 2
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

## Agent-Skill 아키텍처

**Skill(How)**과 **Agent(When/With What)**를 분리하여 유지보수성과 자율성을 동시에 확보합니다.

- **Skill**: 재사용 가능한 최소 기능 단위. 절차와 규칙을 상세히 정의.
- **Agent**: 스킬을 탑재하고 오케스트레이션 흐름을 정의. 상황에 맞는 스킬을 자율 선택.

Claude는 작업 성격을 인식하여 적절한 스킬을 **스스로 판단하고 호출**합니다.

---

## Skills (18)

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
| `write-report` | 솔루션 비교 보고서 작성 | 기술 선정/벤더 평가 시 |
| `handoff` | 세션 핸드오프 워크플로우 (테스트→커밋→push→메모리 저장) | 세션 종료 시 |

---

## Agents (16)

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
| `write-report` | 솔루션 비교 보고서 | write-report |
| `handoff` | 세션 핸드오프 자동화 | handoff, commit, memory-protocol |

---

## Hooks (11)

**Hooks**는 Claude Code 이벤트에 자동으로 응답하는 스크립트입니다. AI의 자율성을 유지하면서도 **위험 행동을 원천 차단**하는 가드레일 역할을 합니다.

| 이벤트 | 스크립트 | 기능 |
|--------|----------|------|
| **SessionStart** | `session-start.sh` | STATE.md 로드, git status 주입 |
| **PreToolUse** | `bash-guard.py` | 위험한 명령어 차단 |
| **PreToolUse** | `file-protect.py` | .env, 시크릿 파일 보호 |
| **PostToolUse** | `auto-format.sh` | Python 파일 자동 포맷 |
| **PostToolUse** | `track-modifications.sh` | 변경 파일 추적 |
| **PreCompact** | `pre-compact-save.sh` | 컴팩트 전 상태 저장 |
| **Stop** | `stop-context-save.sh` | 세션 컨텍스트 저장 |
| **Stop** | `post-turn-verify.sh` | 작업 검증 |
| **SubagentStop** | *(prompt)* | 서브에이전트 완료 시 결과 요약 및 패턴 기록 |
| **SessionEnd** | `save-session-changes.sh` | 세션 변경사항 추적 |
| **SessionEnd** | `save-transcript.sh` | 대화 기록 저장 |

### 유틸리티 스크립트

| 스크립트 | 기능 |
|----------|------|
| `md-store-memory.sh` | 파일 기반 메모리 저장 |
| `md-recall-memory.sh` | 파일 기반 메모리 검색 |
| `scaffold-hxsk.sh` | HXSK 문서 초기화 |
| `scaffold-infra.sh` | 인프라 스캐폴딩 |
| `compact-context.sh` | 컨텍스트 압축 |
| `organize-docs.sh` | 문서 정리/아카이브 |
| `_json_parse.sh` | JSON 파싱 유틸리티 |

---

## HXSK 워크플로우

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

## Self-Configure

빌드 과정 없이 **setup 프롬프트**를 통해 새 프로젝트에 HXSK를 적용합니다.

1. `prompts/setup.md` (범용) 또는 `prompts/setup-claude.md` (Claude Code 전용)를 에이전트에 전달
2. 에이전트가 스킬, 훅, 문서 구조를 자동 구성
3. `scripts/verify-self-configure.sh --all`로 검증

---

## Make 명령어

```bash
make help                   # 전체 명령어 목록
```

| 명령어 | 설명 |
|--------|------|
| `make setup` | 전체 초기 설정 (의존성 확인 + 환경) |
| `make status` | 환경 상태 확인 |
| `make check-deps` | 필수 도구 설치 확인 |

---

## 참고 문서

### Claude Code 공식 문서

| 문서 | 설명 |
|------|------|
| [Hooks](https://code.claude.com/docs/en/hooks.md) | 이벤트 훅 설정 |
| [Skills](https://code.claude.com/docs/en/skills.md) | 스킬 정의 및 활용 |
| [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | 에이전트 frontmatter |

### 커뮤니티 리소스

| 리소스 | 설명 |
|--------|------|
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Claude Code 리소스 큐레이션 |
| [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers) | MCP 서버 목록 |

---

## 설계 배경 (Design Rationale)

현재 아키텍처는 최신 에이전트 메모리 및 추론 최적화 연구들을 분석하고 선택적으로 적용한 결과입니다. 상세 리서치 문서는 `.hxsk/research/`에서 확인할 수 있습니다.

### 왜 순수 bash + 마크다운인가?

| 대안 | 장점 | 채택하지 않은 이유 |
|------|------|-------------------|
| 벡터 DB (Qdrant, Weaviate) | 의미적 유사도 검색 | 외부 서비스 의존, 설정 복잡도 증가 |
| MCP 서버 | 표준화된 인터페이스 | 추가 프로세스 필요, 네트워크 오버헤드 |
| SQLite/JSON | 구조화된 쿼리 | 파일 수준 가독성 저하, Git diff 불가 |

**결론**: 순수 bash + 마크다운은 Claude Code 네이티브 도구(Grep, Glob, Read)와 직접 호환되며, Git 추적이 가능하고, 외부 종속성이 없습니다.

### A-Mem에서 채택한 것

> 출처: [A-Mem: Agentic Memory for LLM Agents](https://arxiv.org/html/2502.12110v11)

| A-Mem 개념 | 본 시스템 적용 |
|-----------|---------------|
| 7-속성 노트 구조 | `contextual_description`, `keywords`, `related` frontmatter 필드 |
| Link Generation | `related:` 필드로 메모리 간 명시적 연결 |
| 그래프 탐색 검색 | `md-recall-memory.sh`의 2-hop 검색 (`hop` 파라미터) |
| 토큰 절감 (85-93%) | compact 모드 — title + 1줄 요약만 반환 |

**채택하지 않은 것**: Memory Evolution (기존 메모리 자동 갱신) — 마크다운 파일의 감사(audit) 추적성을 유지하기 위해 write-once 정책 유지.

### Nemori에서 채택한 것

> 출처: [Nemori: Self-Organizing Agent Memory](https://arxiv.org/html/2508.03341v3)

| Nemori 개념 | 본 시스템 적용 |
|-------------|---------------|
| Episodic + Semantic 이중 메모리 | `session-summary` (에피소드) vs `architecture-decision`, `pattern-discovery` (의미) 타입 분리 |
| 중복 제거 | `md-store-memory.sh`의 `[SKIP:DUPLICATE]` — 동일 title 저장 방지 |
| session-summary 서사화 | `stop-context-save.sh`가 커밋 메시지 포함 contextual_description 생성 |
| keyword 유사도 경고 | `[WARN:SIMILAR]`: 2개 이상 키워드 매칭 시 경고 (저장 계속) |

**채택하지 않은 것**: Predict-Calibrate 사이클 전체 — LLM 추가 호출 비용 대비 효용이 불확실. 단, 경량 적용으로 keyword 유사도 기반 `[WARN:SIMILAR]` 경고를 구현.

### 토큰 최적화 연구에서 채택한 것

> 출처: [Awesome-Agentic-Reasoning](https://github.com/weitianxin/Awesome-Agentic-Reasoning)

| 패턴 | 논문 | 본 시스템 적용 |
|------|------|---------------|
| 계획-실행 분리 | ReWOO (5x 효율) | HXSK: `SPEC.md` → `PLAN.md` → `EXECUTE` 분리 |
| 적응적 탐색 깊이 | System-1.x | planner의 Discovery Level (0-3) |
| 가설 가지치기 | Tree of Thoughts | `debug-eliminated` 메모리 타입 |
| 도구 문서 압축 | EASYTOOL | 스킬 2단계 로딩 (요약 → 상세) |
| 서사 문장 우선 fallback | Context Compression 연구 | `md-recall-memory.sh`: `>` 블록쿼트를 우선 fallback으로 사용 |

### 온톨로지에서 채택한 것

> 출처: [LLM 에이전트를 위한 온톨로지 연구 정리](RESEARCH-ontology-for-llm-agents.md)

| 온톨로지 개념 | 본 시스템 적용 |
|--------------|---------------|
| 타입 분류 체계 | 14개 메모리 타입 디렉토리 |
| 스키마 검증 | `.hxsk/memories/_schema/` JSON Schema |
| 타입 간 관계 | `type-relations.yaml` (Ontology) |

**향후 확장**: OWL 기반 명시적 온톨로지 도입은 Cognee 같은 외부 프레임워크 통합 시 검토.

### RLM에서 채택한 것

> 출처: [Recursive Language Models](https://arxiv.org/html/2512.24601v2)

| RLM 개념 | 본 시스템 적용 |
|----------|---------------|
| Root/Sub-LLM 분리 | Agent-Skill 래핑 구조 (Opus → Haiku 위임 가능) |
| 재귀적 분할 | Phase → Plan → Task 3단계 분할 |

**채택하지 않은 것**: Persistent REPL — 현재 사용 사례에서 필요성 낮음.

### 설계 원칙 요약

```
┌─────────────────────────────────────────────────────────────┐
│  최소 종속성 원칙                                             │
│  ────────────────                                           │
│  외부 서비스 = 0 │ MCP 서버 = 선택적 │ 순수 bash + 마크다운    │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   A-Mem 스타일          Nemori 스타일         토큰 최적화
   연결 그래프           이중 메모리 분류       계획-실행 분리
   2-hop 검색            중복 제거             적응적 탐색
```

<p align="center">
  <img src="logo.gif" alt="HExoskeleton Demo" width="480" />
</p>

---

## 라이선스

MIT
