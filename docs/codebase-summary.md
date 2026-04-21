# Codebase Summary

> HExoskeleton 리포지토리의 파일 인벤토리, 의존성, 구성 요소 카운트.
>
> Version 5.5.0 · ~321 추적 파일

## 1. Repository Layout

```
HExoskeleton/
├── README.md                  # 공개 랜딩 페이지 (462 lines)
├── CLAUDE.md                  # Claude Code 진입점 (38 lines)
├── AGENTS.md                  # 하네스 공용 지침 (97 lines)
├── GEMINI.md                  # Gemini CLI 진입점 (12 lines)
├── llms.txt                   # Self-Configure 인덱스 (35 lines)
├── CHANGELOG.md               # 릴리스 히스토리
├── Makefile                   # 빌드 타겟 (74 lines)
├── .envrc / .env.example      # 환경 설정
├── logo.png / logo.gif        # 에셋
├── docs/                      # 공개 문서 (이 디렉토리) ← 본 문서 포함
└── .hxsk/                     # HXSK 작업 상태 + 런타임
    ├── SPEC.md                # 프로젝트 스펙
    ├── STATE.md               # 활성 게이트 + 디스패처 상태
    ├── ARCHITECTURE.md        # 아키텍처 스냅샷
    ├── STACK.md               # 기술 스택 인벤토리
    ├── DECISIONS.md           # ADR
    ├── PATTERNS.md            # 학습된 패턴 (≤2KB/20 items)
    ├── ROADMAP.md             # 로드맵
    ├── TODO.md / CURRENT.md / SESSION_HANDOFF.md
    ├── VERIFICATION.md        # 검증 프레임워크
    ├── CHANGELOG.md           # 내부 CHANGELOG
    ├── context-config.yaml    # 컨텍스트/프룬 설정
    ├── skills/   (22)         # 재사용 절차
    ├── agents/   (18)         # 스킬 오케스트레이션
    ├── hooks/    (21+)        # 이벤트 훅
    ├── scripts/  (12)         # 유틸리티
    ├── workflow/ (1)          # GATES.md
    ├── prompts/  (3)          # setup 프롬프트
    ├── templates/ (33)        # 문서 템플릿
    ├── adapters/ (7)          # 하네스별 어댑터
    ├── githooks/              # git post-commit/post-merge
    ├── memories/ (15 types)   # 파일 기반 메모리
    ├── research/              # L3 근거 문서
    ├── issues/                # 파일 기반 이슈 레지스트리
    ├── docs/                  # 내부 심화 문서 (11)
    ├── reports/               # 생성 보고서
    ├── archive/               # 아카이브된 구 버전
    └── examples/              # 워크플로우 예제
```

## 2. Core Components Count

| 영역 | 개수 | 총 LOC | 비고 |
|------|------|--------|------|
| **Skills** | 22 | ~6,032 | 각 `{name}/SKILL.md` 형식 |
| **Agents** | 18 | ~622 | 각 `{name}.md` 파일 |
| **Hooks** | 21+ | ~3,246 | Claude Code 이벤트별 |
| **Scripts** | 12 | ~2,606+ | 유틸리티 bash |
| **Templates** | 33 | ~2,386 | 문서 생성 표준 |
| **Internal Docs** | 11 | varied | `.hxsk/docs/` |
| **Prompts** | 3 | ~495 | setup 프롬프트 |
| **Adapters** | 7 | ~280–884 each | 하네스별 훅 설정 |
| **Memory Types** | 15 | 런타임 생성 | A-Mem 확장 |
| **Workflow Gates** | 8 | 133 | GATES.md 정의 |

## 3. Skills Inventory (22)

| Skill | 핵심 역할 |
|-------|----------|
| `arch-review` | 아키텍처 규칙 검증, 레이어 위반/순환 의존성 감지 |
| `bootstrap` | 프로젝트 초기화(fresh/update/verify) 수렴 엔진 |
| `clean` | 쉘 스크립트 lint(shellcheck, shfmt) + 자동 수정 |
| `codebase-mapper` | 구조/패턴/의존성 분석 → ARCHITECTURE.md + STACK.md |
| `commit` | 논리 단위별 원자 커밋 분리, 컨벤셔널 이모지 메시지 |
| `context-health-monitor` | 컨텍스트 rot 방지: 3-strike, 순환 감지, 세션 핸드오프 |
| `create-pr` | 브랜치 + 커밋 + gh pr create |
| `debugger` | 가설 테스트, 기억 영속화, 3-strike rule |
| `dispatcher` | 6단계 병렬 오케스트레이션(SPLIT→BRANCH→Wave→VERIFY) |
| `doc-lint` | 마크다운 일관성 검증(LINK/INDEX/COUNT/REF/ORPHAN) |
| `empirical-validation` | 증거 기반 검증 게이트 (자기 합리화 차단) |
| `executor` | PLAN.md → 원자 커밋 + 4-규칙 편차 처리 |
| `handoff` | 세션 종료: 테스트→커밋→메모리→요약 |
| `impact-analysis` | 변경 blast radius 평가 |
| `memory-protocol` | 15 타입 메모리 저장/회상(2-hop) |
| `plan-checker` | PLAN.md 6차원 검증 |
| `planner` | 목표→PLAN.md 작성 (goal-backward) |
| `pr-review` | 6-페르소나 코드 리뷰 (Dev/QA/Security/Arch/DevOps/UX) |
| `skill-testing` | 스킬 TDD (RED/GREEN/REFACTOR) |
| `verifier` | SPEC.md must-haves 대조 검증 |
| `write-report` | 솔루션 비교 보고서 작성 (TCO+가중점수) |
| (+ INDEX.md) | 스킬 카탈로그 인덱스 |

상세: `.hxsk/skills/{name}/SKILL.md`.

## 4. Agents Inventory (18)

| Agent | 래핑 Skill | 모델 힌트 |
|-------|-----------|---------|
| `arch-review` | arch-review + memory-protocol | sonnet |
| `bootstrap` | bootstrap + codebase-mapper + memory-protocol | sonnet |
| `clean` | clean | haiku |
| `codebase-mapper` | codebase-mapper | opus |
| `commit` | commit | haiku |
| `context-health-monitor` | context-health-monitor + memory-protocol | sonnet |
| `create-pr` | create-pr + commit | sonnet |
| `debugger` | debugger + memory-protocol | sonnet |
| `dispatcher` | dispatcher + memory-protocol | opus |
| `executor` | executor + memory-protocol | sonnet |
| `handoff` | handoff + commit + memory-protocol | sonnet |
| `impact-analysis` | impact-analysis + memory-protocol | haiku |
| `plan-checker` | plan-checker | opus |
| `planner` | planner + impact-analysis + memory-protocol | opus |
| `pr-review` | pr-review | opus |
| `spec-reviewer` | (implied) | sonnet |
| `verifier` | verifier + empirical-validation | sonnet |
| `write-report` | write-report | opus |

상세: `.hxsk/agents/{name}.md`.

## 5. Hooks Catalog (21+)

### 이벤트별 분류

**SessionStart**:
- `session-start.sh` (156 lines) — CURRENT.md + STATE.md + 최근 커밋 + 메모리 회상 로드

**PostToolUse (Edit/Write/Bash)**:
- `track-modifications.sh` — 수정 플래그 + 변경 파일 로그
- `auto-format.sh` — Qlty/ruff/prettier/gofmt/rustfmt 자동 포맷
- `post-turn-verify.sh` — 턴 종료 검증

**PreCompact**:
- `pre-compact-save.sh` — 압축 전 스냅샷 저장; shebang `#!/usr/bin/env bash`로 표준화

**Stop**:
- `stop-context-save.sh` — CURRENT.md 재생성 + A-Mem 저장; atomic `mv "$FLAG_FILE" "$CLAIMED_FLAG.$$"` 으로 동시 Stop 훅 race condition 방지

**SessionEnd**:
- `save-session-changes.sh` — CHANGELOG.md에 세션 변경 기록
- `save-transcript.sh` — 트랜스크립트 보존 (선택)

**Memory**:
- `md-store-memory.sh` — YAML+MD 저장, Nemori dedup; `yaml_safe()` YAML injection 방지; TYPE_DIR 자동 생성; `.hxsk/` 존재 검증
- `md-recall-memory.sh` — 2-hop grep 검색; 결과 없음 시 stderr `[NO_MATCH]` 출력; `HXSK_RECALL_MAX` 환경변수로 스캔 깊이 제한(기본 500줄); 2-hop `related` 파싱은 frontmatter 범위로 한정

**Workflow**:
- `gate-check.sh` — GATES.md 조건 검증
- `check-consistency.sh` — INDEX vs 실제 파일 교차 검증
- `pre-pr-check.sh` — 버전 sync + CHANGELOG + 릴리스 노트

**Utilities**:
- `_json_parse.sh` — jq → python3 → node 폴백
- `organize-docs.sh` — 문서 구조 정리
- `compact-context.sh` — PATTERNS/JOURNAL 프룬
- `collect-rationalization.sh` — 합리화 노트 수집
- `scaffold-hxsk.sh` / `scaffold-infra.sh` — 초기 스캐폴드

**Pre-commit Git**:
- `pre-commit-doc-lint.sh`
- `pre-commit-version-check.sh`

## 6. Utility Scripts (12)

| Script | 목적 |
|--------|------|
| `bootstrap.sh` (458 lines) | 환경 수렴 엔진 — fresh/update/verify; FAIL 시 "다음 단계: setup.md 열어 수동 수정" 안내 |
| `detect-language.sh` (221) | Python/Node/Go/Rust + 패키지 매니저 감지 |
| `doc-lint.sh` (619) | 마크다운 구조 검증; ORPHAN_EXCLUDE_DIRS에 `./scenario ./predict ./.hxsk/docs ./.hxsk/phases` 포함 |
| `issue-create.sh` (166) | master/work/legacy 모드 이슈 생성 |
| `issue-list.sh` (137) | 이슈 인덱스 출력 |
| `merge-worktrees.sh` (63) | 워크트리 병합 |
| `prune-memories.sh` (295) | Tier 기반 메모리 프룬 + 가치 승격; `.prune-config` 소싱 전 owner(`-O`) + permissions(`& 022`) 검증 |
| `prune-tick.sh` (75) | 하네스 독립 opportunistic 트리거 (60s 쿨다운); stale lock 300s 감지·제거; `.prune-config` source 안전 검증 |
| `generate-llms-txt.sh` (61) | llms.txt 자동 생성 |
| `forge-detect.sh` (170) | GitHub/GitLab/Gitea + auth 감지 |
| `verify-self-configure.sh` (341) | 자가 구성 검증 |
| `check-reliability.sh` (NEW) | 11-패턴 신뢰성 이슈 카운터; `bash .hxsk/scripts/check-reliability.sh` → `ISSUE COUNT: N` 출력 |

## 7. Memory System (15 Types)

`.hxsk/memories/` 하위 디렉토리:

| 타입 | 용도 |
|------|------|
| `architecture-decision` | ADR 기록 |
| `bootstrap` | 환경 초기화 이력 |
| `debug-blocked` | 막힌 디버그 시도 |
| `debug-eliminated` | 제거된 가설 |
| `deviation` | 계획 편차 기록 |
| `execution-summary` | 실행 완료 요약 |
| `general` | 기타 |
| `health-event` | 컨텍스트 건강 이벤트 |
| `lessons-learned` | A/B/C/D/E 5 카테고리 반복 실수 방지 |
| `pattern-discovery` | 새로 발견된 패턴 |
| `root-cause` | 버그 근본 원인 |
| `security-finding` | 보안 취약점 |
| `session-handoff` | 세션 간 브리지 |
| `session-snapshot` | pre-compact 스냅샷 |
| `session-summary` | 세션 종료 요약 |

스키마: `.hxsk/memories/_schema/base.schema.json` + `type-relations.yaml`.

## 8. Harness Adapters (7)

`.hxsk/adapters/`:

| 파일 | 대상 하네스 | 이벤트 |
|------|-----------|--------|
| `(Claude Code 네이티브)` | Claude Code | `.claude/settings.json` 직접 |
| `codex-hooks.json` | OpenAI Codex | `$autoresearch` 패턴 |
| `copilot-hooks.json` | GitHub Copilot CLI | sessionEnd, agentStop |
| `cursor-hooks.json` | Cursor 1.7+ | stop, preCompact |
| `gemini-settings.json` | Gemini CLI | SessionEnd, PreCompress |
| `opencode-plugin.ts` | OpenCode | session.idle, session.compacting (JS) |
| `windsurf-hooks.json` | Windsurf Cascade | post_cascade_response |
| **git 폴백** | Aider/Continue/Antigravity | `.hxsk/githooks/post-commit` & `post-merge` |

## 9. Build Targets (3)

| 타겟 | 명령 | 출력 |
|------|------|------|
| Claude Code Plugin | `make build-plugin` | `hxsk-plugin/` |
| Google Antigravity | `make build-antigravity` | `antigravity-boilerplate/` |
| OpenCode | `make build-opencode` | `opencode-boilerplate/` |

상세: @deployment-guide.md.

## 10. Key Dependencies

### Required

| 의존성 | 버전 | 용도 |
|--------|------|------|
| Bash | ≥3.2 | 모든 스크립트 (macOS 기본 호환) |
| Git | ≥2.x | 버전 관리 + 메모리 감사 추적 |
| Python 3 | 시스템 내장 | `_json_parse.sh` 폴백, 일부 훅 |
| GNU Make | 표준 | Makefile 타겟 |
| Claude Code CLI | 최신 | 주 실행 환경 (선택적) |

**외부 패키지 의존성: ZERO**. npm/pip/gem 없음.

### Optional

| 도구 | 용도 | 설치 |
|------|------|------|
| `qlty` | 코드 품질 분석(shellcheck 등) | `make install-qlty` |
| `gh` | GitHub CLI (PR 생성) | `brew install gh` |
| `node` | system-prompt 패치 (`make patch-prompt`) | Node.js 설치 |
| `jq` | JSON 파싱 가속 (폴백: python3/node) | 시스템 패키지 |

### Harness 지원 매트릭스

| 하네스 | 네이티브 지원 | 어댑터 필요 | 깊은 통합 |
|--------|--------------|-----------|---------|
| Claude Code | ✅ | - | ⭐⭐⭐ |
| Gemini CLI | ✅ | gemini-settings.json | ⭐⭐ |
| Cursor 1.7+ | - | cursor-hooks.json | ⭐⭐ |
| GitHub Copilot CLI | - | copilot-hooks.json | ⭐⭐ |
| Windsurf | - | windsurf-hooks.json | ⭐ |
| OpenCode | - | opencode-plugin.ts | ⭐⭐ |
| OpenAI Codex | - | codex-hooks.json | ⭐ |
| Antigravity | - | git 훅 폴백 | ⭐ |
| Aider | - | git 훅 폴백 | ⭐ |
| Continue | - | git 훅 폴백 | ⭐ |

## 11. Research Foundation

`.hxsk/research/` 에는 33개 연구 문서가 7개 카테고리로 정리되어 있다:

- **memory-systems/** (8) — A-Mem, Nemori, ReWOO, RLM, 컨텍스트 압축, 하이브리드 검색
- **platform-integration/** (8) — Claude Code/OpenCode/Antigravity 통합 연구
- **deployment-strategy/** (6) — 플러그인 vs Self-Configure 결정 과정
- **language-support/** (3) — 다국어 확장 타당성 (archived)
- **tooling/** (2) — bash CLI vs MCP 트레이드오프
- **architecture/** (3) — 코드 엔트로피, 솔루션 비교 프레임워크
- **workflow/** (4+) — GitHub 워크플로우, 멀티플랫폼 호환성, autoresearch 방법론 비교

인덱스: `.hxsk/research/INDEX.md`.

## See Also

- [Project Overview](project-overview-pdr.md) — 비전과 원리
- [System Architecture](system-architecture.md) — 컴포넌트 다이어그램
- [Code Standards](code-standards.md) — 컨벤션
- [Testing Guide](testing-guide.md) — 검증 방법
