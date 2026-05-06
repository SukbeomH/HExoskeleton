# Codebase Summary

> HExoskeleton 리포지토리의 파일 인벤토리, 의존성, 구성 요소 카운트.
>
> Version 5.7.0 문서 스냅샷 · 2026-05-06 기준 로컬 스캔 반영

## 1. Repository Layout

```
HExoskeleton/
├── README.md                  # 공개 랜딩 페이지 (314 lines)
├── CLAUDE.md                  # Claude Code 진입점
├── AGENTS.md                  # 하네스 공용 지침 (155 lines)
├── GEMINI.md                  # Gemini CLI 진입점 (12 lines)
├── llms.txt                   # Self-Configure 인덱스 (67 lines)
├── CHANGELOG.md               # 릴리스 히스토리
├── Makefile                   # 빌드 타겟 (74 lines)
├── .envrc / .env.example      # 환경 설정
├── logo.png / logo.gif        # 에셋
├── docs/                      # 공개 문서 (이 디렉토리) ← 본 문서 포함
└── .hxsk/                     # HXSK 작업 상태 + 런타임
    ├── SPEC.md                # 프로젝트 스펙
    ├── CURRENT.md             # 현재 세션 서사 / 최근 실행 문맥
    ├── STATE.md               # 구조화된 현재 상태 / next checkpoint / blockers
    ├── SESSION_HANDOFF.md     # 다음 세션 재진입용 최소 handoff
    ├── ARCHITECTURE.md        # 아키텍처 스냅샷
    ├── STACK.md               # 기술 스택 인벤토리
    ├── DECISIONS.md           # ADR
    ├── PATTERNS.md            # 학습된 패턴 (≤2KB/20 items)
    ├── ROADMAP.md             # 로드맵
    ├── TODO.md                # backlog / follow-up
    ├── VERIFICATION.md        # 검증 truth / evidence / verdict
    ├── CHANGELOG.md           # 내부 CHANGELOG
    ├── context-config.yaml    # 컨텍스트/프룬 설정
    ├── skills/   (24)         # 재사용 절차
    ├── agents/   (18)         # 스킬 오케스트레이션
    ├── hooks/    (27)         # 이벤트 훅
    ├── scripts/  (23)         # 유틸리티 bash/Python
    ├── workflow/ (1)          # GATES.md
    ├── prompts/  (3)          # setup 프롬프트
    ├── templates/ (34)        # 문서 템플릿
    ├── adapters/              # 하네스별 어댑터 + 설정 파일
    ├── githooks/              # git post-commit/post-merge
    ├── memories/              # 파일 기반 메모리 + 스키마
    ├── research/              # L3 근거 문서 (43 markdown / 8 subdirs + root-level studies)
    ├── issues/                # 파일 기반 이슈 레지스트리
    ├── docs/                  # 내부 심화 문서 (15 root markdown + plans/)
    ├── reports/               # 생성 보고서
    ├── archive/               # 아카이브된 구 버전
    └── examples/              # 워크플로우 예제
```

## 2. Core Components Count

### Canonical Active-State Surface

HXSK의 작업 재진입 표면은 아래 문서를 canonical로 본다.

- `SPEC.md` — 목표/제약/성공 기준
- `CURRENT.md` — 현재 세션 서사와 최근 실행 문맥
- `STATE.md` — 구조화된 현재 상태, next checkpoint, blockers
- `SESSION_HANDOFF.md` — 다음 세션이 바로 재진입할 최소 handoff
- `VERIFICATION.md` — 검증 truth / evidence / verdict
- `DECISIONS.md` — 구조적 결정
- `PATTERNS.md` — distilled reusable learnings
- `TODO.md` — backlog / follow-up

| 영역 | 개수 | 총 LOC | 비고 |
|------|------|--------|------|
| **Skills** | 24 | index 기준 | 각 `{name}/SKILL.md` + `references/` |
| **Agents** | 18 | index 기준 | 각 `{name}.md` 파일 |
| **Hooks** | 27 | index 기준 | 7개 Claude Code 이벤트 + 보조 훅 |
| **Scripts** | 23 | 로컬 스캔 기준 | 설치·검증·릴리스·유지보수 유틸리티 |
| **Templates** | 34 | 로컬 스캔 기준 | 문서 생성 표준 |
| **Internal Docs** | 35 root markdown | 로컬 스캔 기준 | `.hxsk/docs/` + `plans/` 심화 문서 |
| **Prompts** | 3 | 로컬 스캔 기준 | setup 프롬프트 |
| **Adapters** | mixed | 설정 파일/문서 혼합 | 하네스별 훅 설정 |
| **Memory Surface** | canonical 17 + ADR-006 historical | 스키마/디렉토리 혼합 | `term-definition`, `test`, `lessons-learned` 포함 |
| **Workflow Gates** | 8 | GATES.md 기준 | 게이트 정의 |

## 3. Skills Inventory (24)

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
| `memory-protocol` | 코어 메모리 저장/회상(2-hop) 및 타입 규약 |
| `plan-checker` | PLAN.md 6차원 검증 |
| `planner` | 목표→PLAN.md 작성 (goal-backward) |
| `pr-review` | 6-페르소나 코드 리뷰 (Dev/QA/Security/Arch/DevOps/UX) |
| `refactor` | 기능 보존 리팩토링 — PREPARE→IDENTIFY→REFACTOR→VERIFY, 10개 코드 스멜 카탈로그 |
| `skill-testing` | 스킬 TDD (RED/GREEN/REFACTOR) |
| `verifier` | SPEC.md must-haves 대조 검증 |
| `write-report` | 솔루션 비교 보고서 작성 (TCO+가중점수) |
| `cleanse-memory` | 오염/저품질 메모리 정리 및 승격/제거 판단 |
| `define-term` | 용어 정의 등록/검토/병합/재생성 (ADR-006 기반, 기본 경로 편입 전 실험적) |
| (+ INDEX.md) | 스킬 카탈로그 인덱스 |

상세: `.hxsk/skills/{name}/SKILL.md` (entry ≤200줄) + `{name}/references/` (상세, 선택 로드).

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
| `spec-reviewer` | verifier + empirical-validation 기반 스펙 적합성 1차 심사 | sonnet |
| `verifier` | verifier + empirical-validation | sonnet |
| `write-report` | write-report | opus |

상세: `.hxsk/agents/{name}.md`.

## 5. Hooks Catalog (27)

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
- `md-store-memory.sh` — YAML+MD 저장, Nemori dedup; `yaml_safe()` backslash-first YAML injection 방지; TYPE_DIR 자동 생성; `.hxsk/` 존재 검증
- `md-recall-memory.sh` — 2-hop grep 검색; `grep -li -- "$QUERY"` option-injection 방지; `find -print0 | xargs -0` null-delimiter space-safety; `HXSK_RECALL_MAX`로 스캔 깊이 제한

**Security (Phase 8)**:
- `bash-guard.py` — DESTRUCTIVE_FS(rm -rRf, shred, dd if=/dev/zero, truncate, chmod 777, git push --mirror) + DESTRUCTIVE_GIT 패턴 차단
- `file-protect.py` — `secrets/`, `secrets.`, `.secrets`, `.gitconfig`, `credentials` 쓰기 차단

**Workflow**:
- `gate-check.sh` — GATES.md 조건 검증
- `check-consistency.sh` — INDEX vs 실제 파일 교차 검증
- `pre-pr-check.sh` — 버전 sync + CHANGELOG + 릴리스 노트

**Utilities**:
- `_json_parse.sh` — jq → python3 → node 폴백
- `organize-docs.sh` — 문서 구조 정리
- `compact-context.sh` — PATTERNS/JOURNAL 프룬
- `collect-rationalization.sh` — 합리화 노트 수집
- `glossary-detect.sh` — 용어 후보 감지 및 glossary 워크플로우 트리거
- `scaffold-hxsk.sh` / `scaffold-infra.sh` — 초기 스캐폴드

**Pre-commit Git**:
- `pre-commit-doc-lint.sh` — doc-lint 검사 (INDEX-01은 `references/` 서브디렉토리 자동 제외)
- `pre-commit-version-check.sh` — 버전 정합성 검증

## 6. Utility Scripts (23)

| Script | 목적 |
|--------|------|
| `bootstrap.sh` | 환경 수렴 엔진 — fresh/update/verify; FAIL 시 setup.md 또는 setup-verify.sh 안내 |
| `detect-language.sh` (221) | Python/Node/Go/Rust + 패키지 매니저 감지 |
| `doc-lint.sh` | 마크다운 구조 검증; ORPHAN_EXCLUDE_DIRS에 `./scenario ./predict ./.hxsk/docs ./.hxsk/phases` 포함 |
| `issue-create.sh` (166) | master/work/legacy 모드 이슈 생성 |
| `issue-list.sh` (137) | 이슈 인덱스 출력 |
| `merge-worktrees.sh` (63) | 워크트리 병합 |
| `prune-memories.sh` (295) | Tier 기반 메모리 프룬 + 가치 승격; `.prune-config` 소싱 전 owner(`-O`) + permissions(`& 022`) 검증 |
| `prune-tick.sh` (75) | 하네스 독립 opportunistic 트리거 (60s 쿨다운); stale lock 300s 감지·제거; `.prune-config` source 안전 검증 |
| `generate-llms-txt.sh` (61) | llms.txt 자동 생성 |
| `forge-detect.sh` (170) | GitHub/GitLab/Gitea + auth 감지 |
| `verify-self-configure.sh` | 자가 구성 검증 |
| `check-reliability.sh` | 14-패턴 신뢰성 이슈 카운터; `bash .hxsk/scripts/check-reliability.sh` → `ISSUE COUNT: N` 출력 |
| `install.sh` (70) | 하네스별 1-liner 설치 — `--harness <name>` (Tier 1: claude-code·cursor·copilot 완전 지원) |
| `install-hooks.sh` (228) | Claude Code settings.json 훅 설치/병합 — `--merge` 기존 설정 보존, python3 원자적 교체 |
| `hxsk-harness-sync.sh` (35) | 어댑터 드리프트 감지/동기화 — `--check`/`--sync` 모드 |
| `setup-verify.sh` (200) | 설치 검증 5개 독립 조건 — `PASS N/5 | FAIL M/5` 출력 |
| `pre-release-check.sh` (100) | 릴리스 전 4-체크: SHA256·CHANGELOG·ISSUE COUNT·실행권한 |
| `local-verify.sh` | 로컬 우선 검증 번들 — doc-lint, consistency, skill test dry-run, pre-pr 순서 실행 |
| `active-state.sh` | CURRENT/STATE/SESSION_HANDOFF/VERIFICATION active-state spine 관리 유틸리티 |
| `glossary-rebuild.sh` / `hitl-ask.sh` | ADR-006 용어/정의 재빌드와 HITL 어댑터 질의 지원 |

## 7. Memory System (Canonical 17 + ADR-006 historical)

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
| `term-definition` | ADR-006 기반 용어 정의 확장 표면 |
| `test` | 테스트 메모리 저장 (PR #138) |

스키마: `.hxsk/memories/_schema/base.schema.json` + `type-relations.yaml`.

보충: `ADR-006/` 디렉토리는 historical research artifact로 유지되며, canonical memory type count에는 포함하지 않는다.

## 8. Harness Adapters (8)

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

## 9. Makefile Entry Targets

| 타겟 | 명령 | 역할 |
|------|------|------|
| `check-deps` | `make check-deps` | `bootstrap.sh` 실행으로 환경/구조 점검 |
| `init-env` | `make init-env` | `.env.example` → `.env` 초기화 |
| `status` | `make status` | `.env`와 `.hxsk/memories/` 상태 요약 |
| `setup` | `make setup` | `install-deps` + `init-env` 전체 초기 설정 |
| `help` | `make help` | 사용 가능한 엔트리 타겟 표시 |

상세: `Makefile` 및 [deployment-guide.md](deployment-guide.md).

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

`.hxsk/research/` 에는 **43개 markdown 문서**가 있으며, 이 중 **42개 연구 문서 + 1개 인덱스**로 구성된다. 구조는 **8개 하위 디렉토리 + 루트 문서** 기준으로 정리된다:

- **memory-systems/** (8) — A-Mem, Nemori, ReWOO, RLM, 컨텍스트 압축, 하이브리드 검색
- **platform-integration/** (9) — Claude Code/OpenCode/Antigravity 통합 및 OpenCode 실증 검증
- **deployment-strategy/** (6) — 플러그인 vs Self-Configure 결정 과정
- **language-support/** (3) — 다국어 확장 타당성 (archived/superseded)
- **tooling/** (2) — bash CLI vs MCP 트레이드오프
- **architecture/** (3) — 코드 엔트로피, 솔루션 비교 프레임워크
- **workflow/** (5) — GitHub 워크플로우, 멀티플랫폼 호환성, 토큰 최적화, Git 이슈 메모리, AutoResearch 방법론 비교
- **benchmark/** (1) — 메모리 recall 성능 측정
- **root-level studies** (5) — `INDEX.md`, `superpowers-analysis.md`, `superpowers-references.md`, `claude-code-quality-mitigation.md`, `2026-04-23-hallucination-linguistic-features.md`

인덱스: `.hxsk/research/INDEX.md`. thematic section 요약은 디렉토리 구조와 완전히 동일하지 않을 수 있으므로, 카운트성 판단은 로컬 스캔 기준을 우선한다.

## See Also

- [Project Overview](project-overview-pdr.md) — 비전과 원리
- [System Architecture](system-architecture.md) — 컴포넌트 다이어그램
- [Code Standards](code-standards.md) — 컨벤션
- [Testing Guide](testing-guide.md) — 검증 방법
