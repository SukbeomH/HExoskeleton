---
researched_at: 2026-01-28
updated_at: 2026-01-28
discovery_level: 3
status: Revised — reflects current boilerplate state (15 skills, 13 agents, 5 hooks)
---

# everything-claude-code 분석 및 보일러플레이트 비교 (개정판)

## Objective

everything-claude-code 저장소를 심층 분석하고, **현재 최신 상태의 보일러플레이트**(15 skills, 13 sub-agents, 5 hook scripts)와 아키텍처/기능/철학 수준에서 비교한다.

## Discovery Level

**Level 3** -- 심층 비교 분석 + 갭 식별 + 채택 권고

## Revision Note

> 초판 작성 시 보일러플레이트는 서브에이전트 0, 후크 0 상태였다.
> 이후 13 sub-agents(모델별 분리), 5 hook scripts(4 이벤트), bootstrap 스킬이 추가되어
> 초판의 격차 분석 상당수가 해소됨. 본 개정판은 현재 코드베이스를 기준으로 재평가한 결과다.

---

## 1. everything-claude-code 개요

**저자**: Affaan Mustafa (@affaanmustafa) -- Anthropic x Forum Ventures 해커톤 우승자
**성격**: Claude Code 파워유저를 위한 **프로덕션 검증** 설정 컬렉션
**배포**: Claude Code Plugin 마켓플레이스 설치 지원
**라이선스**: MIT

### 핵심 구성

| 항목 | 수량 |
|------|------|
| Agents (서브에이전트) | 12 |
| Skills | 15+ |
| Commands (슬래시 명령) | 23+ |
| Rules (모듈형 규칙) | 8 |
| Hooks (이벤트 자동화) | 16 |
| MCP Configs | 14 |
| Contexts (동적 프롬프트) | 3 |
| Scripts (Node.js) | 6+ |

### 디렉토리 구조

```
everything-claude-code/
├── agents/              # 12 서브에이전트 (YAML frontmatter + markdown)
├── skills/              # 15+ 도메인별 스킬
├── commands/            # 23+ 슬래시 명령
├── rules/               # 8 모듈형 규칙 파일
├── hooks/               # 이벤트 기반 자동화 스크립트
├── contexts/            # 동적 시스템 프롬프트 (dev/review/research)
├── examples/            # 참조 설정 (CLAUDE.md 예시, 세션 파일)
├── mcp-configs/         # 14 MCP 서버 정의
├── scripts/             # Node.js 유틸리티 (398줄 lib/utils.js)
├── tests/               # 테스트 슈트
├── plugins/             # 플러그인 문서
├── assets/              # 이미지 (가이드용)
├── .claude-plugin/      # 플러그인 메타데이터 (plugin.json)
├── the-shortform-guide.md   # 셋업 기초 가이드
└── the-longform-guide.md    # 고급 패턴 & 최적화
```

---

## 2. 아키텍처 비교

### 2.1 프로젝트 성격

| | **보일러플레이트** | **everything-claude-code** |
|---|---|---|
| **유형** | 개발 인프라 + GSD 방법론 템플릿 | Claude Code 설정 컬렉션 + 가이드 |
| **산출물** | SPEC -> PLAN -> 코드 -> 검증 사이클 | 에이전트/스킬/후크/규칙 설정 파일 |
| **대상** | Python 프로젝트 + AI 에이전트 개발 | 모든 언어/프레임워크의 Claude Code 사용자 |
| **언어** | Python 3.11+ (uv) | JavaScript/TypeScript (Node.js 스크립트) |
| **배포** | git clone + make setup | Plugin marketplace 또는 수동 복사 |
| **문서** | 한국어/영어 이중 | 영어 단일 |

### 2.2 기능 매트릭스 (개정)

| 영역 | **보일러플레이트** | **everything-claude-code** | 상태 |
|---|---|---|---|
| **워크플로우 명령** | 29 (GSD) | 23+ (개발 중심) | **보일러플레이트 우위** |
| **에이전트 스킬** | 15 | 15+ | **동등** |
| **서브에이전트** | 13 (3-tier 모델 분리) | 12 (모델별 분리) | ~~격차~~ → **동등** |
| **모듈형 규칙** | 0 (CLAUDE.md 통합, 89줄) | 8 (분리 파일) | **잔여 격차** |
| **후크 시스템** | 5 스크립트, 4 이벤트 | 16 (6종 이벤트) | ~~격차~~ → **부분 해소** |
| **동적 컨텍스트** | GSD 워크플로우로 대체 | 3 (dev/review/research) | **불필요 (설계 차이)** |
| **MCP 통합** | 3 (graph-code, memorygraph, context7) | 14 (GitHub, Vercel, Supabase 등) | **보일러플레이트: RAG 특화** |
| **GSD 방법론** | 완전 (SPEC/PLAN/EXECUTE/VERIFY) | 없음 | **보일러플레이트 고유** |
| **문서 템플릿** | 22 | 0 | **보일러플레이트 고유** |
| **인프라 자동화** | Makefile (21 타겟) | 없음 | **보일러플레이트 고유** |
| **CI/CD** | GitHub Actions (1 workflow) | 없음 | **보일러플레이트 우위** |
| **멀티 에이전트** | 3 (Claude/GitHub/Gemini) | 1 (Claude Code only) | **보일러플레이트 우위** |
| **지속적 학습** | memory-graph MCP (구조화) | 세션 후크 + 패턴 추출 (자동) | **접근 차이** |
| **플러그인 배포** | 리서치 완료, 변환 가능 | 네이티브 Plugin 지원 | **잔여 격차 (실행 대기)** |
| **보안 자동화** | 2 PreToolUse 훅 (file-protect, bash-guard) | security-reviewer 에이전트 + 규칙 | **부분 해소** |

### 2.3 에이전트/스킬 비교 (개정)

#### 보일러플레이트 15 스킬 + 13 서브에이전트

| 카테고리 | 스킬 | 에이전트 모델 | 도구 제한 |
|----------|------|:---:|---|
| **Planning** | planner | Opus | Read, Grep, Glob |
| | plan-checker | Sonnet | Read, Grep, Glob |
| **Execution** | executor | Sonnet | Read, Write, Edit, Bash, Grep, Glob |
| | commit | Haiku | Read, Bash, Grep, Glob |
| | create-pr | Haiku | Read, Bash, Grep, Glob |
| | clean | Haiku | Read, Write, Edit, Bash, Grep, Glob |
| **Verification** | verifier | Sonnet | Read, Bash, Grep, Glob |
| | empirical-validation | (스킬만, 에이전트 없음) | - |
| | pr-review | Opus | Read, Bash, Grep, Glob |
| **Analysis** | arch-review | Opus | Read, Grep, Glob |
| | impact-analysis | Opus | Read, Grep, Glob |
| | codebase-mapper | Sonnet | Read, Bash, Grep, Glob |
| | context-health-monitor | Haiku | Read, Grep, Glob |
| | debugger | Opus | Read, Write, Edit, Bash, Grep, Glob |
| **Setup** | bootstrap | (스킬만, 에이전트 없음) | - |

**모델 분포:**
- **Opus (5)**: planner, debugger, impact-analysis, pr-review, arch-review
- **Sonnet (4)**: executor, verifier, plan-checker, codebase-mapper
- **Haiku (4)**: commit, clean, create-pr, context-health-monitor

#### everything-claude-code 12 에이전트

| 카테고리 | 에이전트 | 모델 |
|----------|---------|------|
| Planning | planner, architect | Opus |
| Development | tdd-guide | Opus |
| Review | code-reviewer, security-reviewer, go-reviewer, database-reviewer | Opus |
| Build | build-error-resolver, go-build-resolver | Haiku |
| Maintenance | refactor-cleaner, doc-updater | Haiku |
| Testing | e2e-runner | Opus |

**모델 분포:**
- **Opus (8)**: planner, architect, tdd-guide, code-reviewer, security-reviewer, go-reviewer, database-reviewer, e2e-runner
- **Haiku (4)**: build-error-resolver, go-build-resolver, refactor-cleaner, doc-updater

### 2.4 비교 분석

| 측면 | 보일러플레이트 | everything-claude-code |
|------|:---:|:---:|
| **에이전트 수** | 13 | 12 |
| **스킬 수** | 15 | 15+ |
| **모델 분리** | 3-tier (Opus/Sonnet/Haiku) | 2-tier (Opus/Haiku) |
| **Sonnet 활용** | O (executor, verifier 등 4개) | X |
| **스킬-에이전트 연결** | 1:1 매핑 (skills 필드로 연결) | 별도 구성 |
| **도구 제한** | 에이전트별 명시적 도구 목록 | 에이전트별 명시적 도구 목록 |
| **스킬 스크립트** | 15개 (Python/Bash) | 6개 (Node.js) |
| **GSD 사이클 통합** | Planning→Execution→Verification→Analysis | Plan→TDD→Review |
| **proactive 트리거** | description 기반 자동 위임 | description 기반 자동 위임 |

**핵심 차이점 (개정):**
- 보일러플레이트는 **Sonnet 계층**을 활용하여 더 세밀한 비용 최적화 (3-tier)
- everything-claude-code는 **Opus 비중이 높음** (8/12 = 67%) — 고비용 구조
- 보일러플레이트의 스킬-에이전트 1:1 매핑이 더 체계적
- everything-claude-code는 **리뷰 특화** (4개 리뷰 에이전트), 보일러플레이트는 **GSD 사이클 특화**

---

## 3. 격차 분석 (Gap Analysis) — 개정

### 3.1 서브에이전트 아키텍처 — ~~Critical Gap~~ → CLOSED

**초판**: 보일러플레이트 서브에이전트 0개, 모델 선택 불가.
**현재**: 13 서브에이전트 + 3-tier 모델 분리 + 도구 제한 + 스킬 프리로딩 완비.

```yaml
# 보일러플레이트 현재 에이전트 예시
---
name: commit
model: haiku
description: Analyzes diffs, splits logical changes, creates conventional emoji commits
tools: Read, Bash, Grep, Glob
skills:
  - commit
---
```

**평가**: everything-claude-code보다 **더 세밀한** 모델 분리 (3-tier vs 2-tier). 격차 완전 해소.

### 3.2 후크 시스템 — ~~High Gap~~ → PARTIALLY CLOSED

**초판**: 후크 없음.
**현재**: 5 hook scripts, 4 이벤트 커버.

| 이벤트 | 보일러플레이트 | everything-claude-code |
|--------|:---:|:---:|
| **SessionStart** | session-start.sh (STATE.md 로드) | 이전 컨텍스트 로드, 패키지 매니저 감지 |
| **PreToolUse** | file-protect.py (시크릿 차단), bash-guard.py (파괴적 명령 차단) | tmux 강제, .md 생성 차단, git push 리뷰 |
| **PostToolUse** | auto-format-py.sh (ruff format + check) | Prettier 자동 포맷, TypeScript 체크, console.log 경고 |
| **PreCompact** | pre-compact-save.sh (STATE/JOURNAL 백업) | 상태 백업 |
| **SessionEnd** | 없음 | 상태 저장, 패턴 평가 |
| **Stop** | 없음 | console.log 최종 체크 |

**해소된 부분:**
- SessionStart: STATE.md 자동 로드 (**완료**)
- PreToolUse: 파일 보호 + Bash 안전장치 (**완료**)
- PostToolUse: Python 자동 포맷 (**완료**)
- PreCompact: 상태 백업 (**완료**)

**잔여 격차:**
- SessionEnd: 세션 종료 시 패턴 추출/학습 저장 없음
- Stop: 최종 검증 체크 없음
- 전체 규모: 5 vs 16 (수량 차이, 단 Python 프로젝트에 불필요한 JS/TS 훅 제외 시 실질 격차 작음)

### 3.3 모듈형 규칙 — Medium Gap (변동 없음)

**현재**: CLAUDE.md 단일 파일 (89줄).
**everything-claude-code**: 8개 독립 규칙 파일.

| 파일 | 내용 |
|------|------|
| `security.md` | 시크릿, 입력 검증, SQL injection, XSS, CSRF, rate limiting |
| `coding-style.md` | 불변성, 파일 크기, 에러 핸들링, Zod 검증 |
| `testing.md` | 80% 커버리지, TDD 필수, E2E 크리티컬 플로우 |
| `git-workflow.md` | conventional commits, feature 워크플로우, PR 규칙 |
| `agents.md` | 에이전트 오케스트레이션, 자동 트리거 조건 |
| `patterns.md` | API 응답 포맷, Repository 패턴, Service 레이어 |
| `performance.md` | 모델 선택, 컨텍스트 윈도우 관리 |

**현재 판단**: CLAUDE.md 89줄은 관리 가능. 단, 플러그인 전환 시 CLAUDE.md를 플러그인에 포함할 수 없으므로(플러그인 시스템 미지원), 프로젝트 scaffolding에서 생성하거나 규칙을 스킬로 분리하는 방안 검토 필요.

### 3.4 동적 컨텍스트 전환 — Low Gap (변동 없음)

GSD 워크플로우가 동일 역할 수행:
- `/execute` = dev 컨텍스트
- `/verify` = review 컨텍스트
- `/research-phase` = research 컨텍스트

별도 컨텍스트 파일 불필요.

### 3.5 지속적 학습 메커니즘 비교 (보완)

| | **보일러플레이트** | **everything-claude-code** |
|---|---|---|
| **저장소** | memory-graph MCP (그래프 DB) | 파일 시스템 (~/.claude/sessions/) |
| **트리거** | debugger/executor 스킬의 allowed-tools에 memory-graph 도구 포함 (반자동) | 자동 (SessionEnd 후크) |
| **형태** | 구조화된 메모리 노드 + 관계 | 패턴 추출 → 스킬 파일 |
| **범위** | 프로젝트 내 + 크로스 프로젝트 (도메인) | 세션 내 → 스킬로 승격 |
| **진화** | 수동 store → 자동 recall (검색 기반) | 동적 (instinct → skill → agent 진화) |

**변화**: debugger, executor, context-health-monitor 스킬에 memory-graph 도구가 `allowed-tools`로 지정되어 반자동 학습 가능. 초판보다 통합도 상승.

### 3.6 플러그인 배포 — ~~Gap~~ → IN PROGRESS

별도 리서치 완료 (`RESEARCH-plugin-feasibility.md`). 15 Skills + 13 Agents + 5 Hook Scripts의 플러그인 변환은 **기술적으로 가능**. 핵심 과제:
- MCP 서버의 프로젝트 경로 참조 해결
- .gsd/ 문서체계 scaffolding
- CLAUDE.md 템플릿 제공

### 3.7 보안 자동화 — ~~Gap~~ → PARTIALLY CLOSED

**초판**: 수동 규칙만 존재.
**현재**:
- `file-protect.py`: .env, .pem, .key, credentials, id_rsa 등 민감 파일 쓰기 차단 (PreToolUse)
- `bash-guard.py`: `git push --force`, `git reset --hard`, `git checkout .`, `git clean -f` 차단 + pip/poetry/conda 사용 차단 (PreToolUse)

**잔여 격차**: everything-claude-code의 `security-reviewer` 에이전트(OWASP 전체 범위 자동 리뷰)에 해당하는 전용 보안 리뷰 에이전트는 없음. `pr-review` 에이전트의 6-persona 중 Security 관점이 부분적으로 커버.

---

## 4. 철학 비교

### 4.1 개발 방법론

| | **보일러플레이트** | **everything-claude-code** |
|---|---|---|
| **접근** | 문서 중심 (SPEC -> PLAN -> 코드) | 에이전트 중심 (Plan -> TDD -> Review) |
| **계획** | GSD SPEC.md 작성 후 락 | /plan 명령 → planner agent |
| **실행** | 페이즈 기반 원자적 커밋 | TDD 사이클 (RED -> GREEN -> IMPROVE) |
| **검증** | 경험적 증거 기반 (VERIFICATION.md) | 체크포인트 기반 eval + E2E |
| **반복** | 3회 실패 → 접근 변경 | Continuous eval loop |
| **위임** | 13 서브에이전트 자동 위임 (신규) | 12 서브에이전트 자동 위임 |

### 4.2 토큰 경제학 (개정)

| | **보일러플레이트** | **everything-claude-code** |
|---|---|---|
| **모델 전략** | 3-tier (Opus 5 / Sonnet 4 / Haiku 4) | 2-tier (Opus 8 / Haiku 4) |
| **비용 효율** | Sonnet 계층으로 중간 비용 최적화 | Opus 비중 67%로 고비용 |
| **MCP 관리** | 3개 목적 특화 (33 도구) | 14개 광범위 (80 도구 상한 권장) |
| **컨텍스트** | 무제한 (자동 요약) + PreCompact 훅 | 200k 중 70k 가용, 마지막 20% 회피 |
| **최적화** | GSD 문서 공유 + context-health-monitor | MCP → CLI+스킬 대체, mgrep 사용 |
| **패칭** | `make patch-prompt` (~50% 절감) | 없음 |

### 4.3 보안 접근 (개정)

| | **보일러플레이트** | **everything-claude-code** |
|---|---|---|
| **규칙** | CLAUDE.md Agent Boundaries | rules/security.md (독립 파일) |
| **자동 차단** | file-protect.py (시크릿 파일), bash-guard.py (위험 명령) | PreToolUse 후크 (tmux, git push) |
| **코드 리뷰** | pr-review 에이전트 (Opus, 6-persona 중 Security) | security-reviewer 에이전트 (전용) |
| **범위** | .env/credential 보호 + 파괴적 git 차단 | OWASP 전체 (SQLi, XSS, CSRF, Rate Limit) |
| **TLS** | SSL_CERT_FILE 지원 | 없음 |

---

## 5. 보일러플레이트 고유 강점 (개정)

everything-claude-code에 **없는** 보일러플레이트 기능:

| 기능 | 상세 |
|------|------|
| **GSD 방법론** | SPEC -> PLAN -> EXECUTE -> VERIFY 전체 사이클. 29개 워크플로우 |
| **문서 템플릿 22개** | SPEC, PLAN, VERIFICATION, DEBUG, milestone, sprint 등 |
| **code-graph-rag** | Tree-sitter + SQLite AST 분석 (19 도구). 리팩토링 전 영향도 분석 |
| **memory-graph** | 그래프 기반 영구 기억 (12 도구). 관계 추적, 도메인 분리 |
| **멀티 에이전트** | Claude Code + GitHub Agent + Gemini 동시 지원 |
| **인프라 자동화** | Makefile 21 타겟 + make setup 원커맨드 |
| **시스템 프롬프트 패치** | make patch-prompt (~50% 토큰 절감) |
| **VS Code 팀 설정** | 워크스페이스 설정 + 확장 권장 공유 |
| **코드 품질 엄격** | Ruff 9종 + McCabe<=10 + max-args=6 + mypy strict |
| **3-tier 모델 전략** | Opus/Sonnet/Haiku 세분화 (everything-claude-code는 2-tier) |
| **스킬-에이전트 1:1 매핑** | 스킬에 도메인 지식, 에이전트에 실행 환경 분리 |
| **15개 스킬 스크립트** | Python/Bash 유틸리티 (diff 분석, import 그래프, 복잡도 체크 등) |

---

## 6. everything-claude-code 고유 강점

보일러플레이트에 **없는** everything-claude-code 기능:

| 기능 | 상세 |
|------|------|
| **전용 security-reviewer** | OWASP 전체 범위 보안 리뷰 에이전트 |
| **tdd-guide 에이전트** | RED → GREEN → IMPROVE TDD 사이클 강제 |
| **e2e-runner 에이전트** | Playwright 기반 E2E 테스트 자동 실행 |
| **database-reviewer** | DB 스키마/쿼리 전용 리뷰 |
| **모듈형 규칙 (8개)** | 보안, 코딩 스타일, 테스팅, git 등 독립 규칙 파일 |
| **동적 컨텍스트 (3개)** | dev/review/research 모드 전환 |
| **14 MCP 설정** | GitHub, Vercel, Supabase 등 광범위 통합 |
| **SessionEnd 후크** | 세션 종료 시 패턴 추출 → 자동 학습 |
| **네이티브 플러그인 배포** | .claude-plugin/plugin.json으로 즉시 설치 가능 |
| **롱/숏폼 가이드** | 입문자용 + 고급 사용자용 문서 |

---

## 7. 채택 권고 (개정)

### 7.1 완료됨 (이전 "즉시 도입" 항목)

| # | 요소 | 초판 상태 | 현재 상태 | 결과 |
|---|------|-----------|-----------|------|
| 1 | **후크 시스템 기초** | 없음 | 5 스크립트, 4 이벤트 | **완료** |
| 2 | **에이전트 모델 분리** | 호스트 모델만 | 3-tier (5 Opus / 4 Sonnet / 4 Haiku) | **완료** |
| 3 | **PreCompact 후크** | 없음 | pre-compact-save.sh | **완료** |

### 7.2 신규 도입 검토 (현재 기준 우선순위)

| # | 요소 | 현재 상태 | 도입 방안 | 효과 | 우선순위 |
|---|------|-----------|-----------|------|---------|
| 1 | **security-reviewer 에이전트** | pr-review의 Security 관점만 | 전용 보안 리뷰 에이전트 추가 (Opus, OWASP 범위) | 보안 사각지대 해소 | 높음 |
| 2 | **SessionEnd 후크** | 없음 | 세션 종료 시 memory-graph에 패턴/결정 자동 저장 | 학습 연속성 | 높음 |
| 3 | **플러그인 패키징** | 리서치 완료 | 15 Skills + 13 Agents + Hooks → plugin 디렉토리 | 팀 배포, 멀티 프로젝트 공유 | 높음 |
| 4 | **tdd-guide 스킬** | /verify만 존재 | RED→GREEN→IMPROVE 사이클 스킬 추가 | 테스트 선행 개발 | 중간 |
| 5 | **e2e-runner 스킬** | 없음 | Playwright 기반 E2E 테스트 에이전트 | 크리티컬 플로우 검증 | 중간 |
| 6 | **Stop 후크** | 없음 | 작업 완료 전 최종 검증 (lint pass, test pass 확인) | 미완성 커밋 방지 | 낮음 |

### 7.3 불필요 / 보류 (유지)

| 요소 | 사유 |
|------|------|
| **규칙 모듈화** | CLAUDE.md 89줄 -- 관리 가능. 플러그인 전환 시 재검토 |
| **동적 컨텍스트** | GSD 워크플로우가 동일 역할 수행 |
| **Node.js 스크립트** | Python 생태계와 불일치. 보일러플레이트의 15개 Python/Bash 스크립트가 대체 |
| **14 MCP 설정** | 보일러플레이트의 3 MCP (33 도구)가 목적에 부합. 불필요한 MCP는 컨텍스트 낭비 |
| **Immutability/Zod 규칙** | TypeScript 전용. Python은 Pydantic/TypedDict 사용 |
| **Go 관련 에이전트** | Go 미사용 |
| **database-reviewer** | DB 스키마 변경이 드물고, pr-review가 일반 리뷰 커버 |

---

## 8. 패턴 학습 (Patterns to Follow)

### 8.1 프로액티브 에이전트 트리거

**현재 구현 상태**: 13 에이전트 모두 `description` 필드에 "Use proactively", "MANDATORY before" 등 프로액티브 트리거 키워드 포함.

```
복잡한 기능 → planner (Opus) 자동 실행
코드 변경 전 → impact-analysis (Opus) MANDATORY
코드 작성 완료 → pr-review (Opus) 자동 실행
버그 수정 → debugger (Opus) 자동 실행
품질 체크 → clean (Haiku) 자동 실행
```

### 8.2 3-Tier 모델 전략 — 구현 완료

| 작업 | 모델 | 에이전트 | 비용 |
|------|------|---------|------|
| 커밋, 포맷, PR 생성, 컨텍스트 모니터링 | Haiku | commit, clean, create-pr, context-health-monitor | 1x |
| 구현, 검증, 계획 검토, 코드 분석 | Sonnet | executor, verifier, plan-checker, codebase-mapper | 5x |
| 설계, 디버깅, 영향 분석, 리뷰, 아키텍처 | Opus | planner, debugger, impact-analysis, pr-review, arch-review | 15x |

### 8.3 Strategic Compaction — 구현 완료

**현재**: `pre-compact-save.sh`가 PreCompact 훅으로 등록. 자동/수동 컴팩션 전 STATE.md + JOURNAL.md 백업 + 상태 스냅샷을 additionalContext로 주입.

`context-health-monitor` 스킬이 컨텍스트 복잡도 모니터링 + 상태 덤프 수행. Haiku 에이전트로 경량 실행.

### 8.4 Iterative Retrieval Pattern

서브에이전트 반환값을 오케스트레이터가 평가 → 후속 질문 → 최대 3회 반복.

```
Orchestrator → impact-analysis (Opus): "analyze_code_impact for auth module"
impact-analysis → Result (affected files, risk score)
Orchestrator → executor (Sonnet): "implement changes with minimal impact"
executor → Implementation
Orchestrator → verifier (Sonnet): "verify against spec"
verifier → Verification Result
```

---

## 9. Anti-Patterns to Avoid (유지)

| 패턴 | 사유 |
|------|------|
| **14 MCP 동시 활성** | 컨텍스트 윈도우 200k 중 70k만 가용. 보일러플레이트의 3 MCP (33 도구)가 효율적 |
| **Node.js 후크 스크립트** | Python 프로젝트에 Node.js 의존성 추가는 복잡성 증가. Python/Bash 스크립트 유지 |
| **Opus 과다 사용** | everything-claude-code는 Opus 67%. 보일러플레이트는 Opus 38% (5/13)로 비용 효율적 |
| **console.log/Prettier 후크** | Python 프로젝트에 해당 없음. ruff format/check으로 대체 (이미 구현) |
| **에이전트 과잉 분리** | 언어별 에이전트(go-reviewer, go-build-resolver)는 범용 보일러플레이트에 부적합 |

---

## 10. 종합 평가 (개정)

### 10.1 요약

| 축 | 보일러플레이트 | everything-claude-code | 변화 |
|---|:---:|:---:|---|
| **방법론 체계** | ★★★★★ | ★★☆☆☆ | 변동 없음 |
| **문서 템플릿** | ★★★★★ | ★☆☆☆☆ | 변동 없음 |
| **코드 분석 (RAG)** | ★★★★★ | ☆☆☆☆☆ | 변동 없음 |
| **에이전트 기억** | ★★★★☆ | ★★★☆☆ | 변동 없음 |
| **인프라 자동화** | ★★★★☆ | ☆☆☆☆☆ | 변동 없음 |
| **후크/자동화** | ★★★★☆ | ★★★★★ | ☆→★★★★ (+4) |
| **서브에이전트** | ★★★★★ | ★★★★★ | ☆→★★★★★ (+5) |
| **토큰 최적화** | ★★★★☆ | ★★★★★ | ★★★→★★★★ (+1) |
| **보안 자동화** | ★★★☆☆ | ★★★★☆ | ★★→★★★ (+1) |
| **배포/공유** | ★★★☆☆ | ★★★★☆ | ★★→★★★ (+1) |

### 10.2 격차 변화 추적

| 격차 | 초판 심각도 | 현재 심각도 | 상태 |
|------|:---:|:---:|---|
| 서브에이전트 아키텍처 | Critical | - | **CLOSED** |
| 후크 시스템 | High | Low | **MOSTLY CLOSED** |
| 모듈형 규칙 | Medium | Medium | 유지 (플러그인 전환 시 재검토) |
| 동적 컨텍스트 | Low | - | **불필요 (설계 차이)** |
| 보안 자동화 | High | Medium | **PARTIALLY CLOSED** |
| 플러그인 배포 | Medium | Low | **리서치 완료, 실행 대기** |
| 학습 자동화 | Medium | Medium | 유지 (SessionEnd 훅 미구현) |

### 10.3 결론 (개정)

보일러플레이트는 초판 대비 **핵심 격차 대부분을 해소**했다:

- **서브에이전트**: 0 → 13 (모델별 3-tier 분리, everything-claude-code보다 세밀)
- **후크**: 0 → 5 (4 이벤트 커버, Python/Bash 네이티브)
- **토큰 최적화**: 단일 모델 → 3-tier (Opus 38%, Sonnet 31%, Haiku 31%)

**현재 상호 보완 관계:**

| 보일러플레이트 우위 | everything-claude-code 우위 |
|---|---|
| GSD 방법론 (29 워크플로우) | 전용 보안 리뷰 (security-reviewer) |
| 코드 분석 RAG (19 도구) | TDD 사이클 (tdd-guide) |
| 에이전트 기억 (12 도구) | E2E 테스트 (e2e-runner) |
| 3-tier 모델 (비용 효율 ↑) | 모듈형 규칙 (8개 분리 파일) |
| 22 문서 템플릿 | 네이티브 플러그인 배포 |
| 멀티 에이전트 (Claude/GitHub/Gemini) | SessionEnd 자동 학습 |
| 인프라 (Makefile 21 타겟) | 14 MCP 광범위 통합 |

**다음 단계**: 잔여 격차 3개(security-reviewer, SessionEnd 학습, 플러그인 배포) 중 **플러그인 배포를 우선** 실행하여 everything-claude-code와 동일한 배포 채널 확보 후, 보안/학습 에이전트를 추가하는 것이 효율적.

---

## Sources

- `everything-claude-code/README.md`
- `everything-claude-code/the-shortform-guide.md`
- `everything-claude-code/the-longform-guide.md`
- `everything-claude-code/agents/` (12 에이전트 정의)
- `everything-claude-code/skills/` (15+ 스킬)
- `everything-claude-code/commands/` (23+ 명령)
- `everything-claude-code/rules/` (8 규칙 파일)
- `everything-claude-code/hooks/` (hooks.json + 6 스크립트)
- `everything-claude-code/contexts/` (3 동적 프롬프트)
- `everything-claude-code/mcp-configs/mcp-servers.json` (14 MCP)
- `everything-claude-code/scripts/lib/utils.js` (398줄)
- `everything-claude-code/.claude-plugin/plugin.json`
- **보일러플레이트 현재 코드베이스** (2026-01-28 기준):
  - `.claude/skills/` (15 스킬, 15 스크립트)
  - `.claude/agents/` (13 서브에이전트)
  - `.claude/hooks/` (5 훅 스크립트)
  - `.claude/settings.json` (훅 설정)
  - `.agent/workflows/` (29 GSD 워크플로우)
  - `.mcp.json` (3 MCP 서버, 33 도구)
  - `.gsd/RESEARCH-plugin-feasibility.md` (플러그인 전환 리서치)
