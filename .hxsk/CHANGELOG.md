# Changelog

> Auto-maintained by SessionEnd hook. `.gsd/` 내부 변경은 제외됨.

---

### [2026-04-30] v5.5.1 — 정합성/검증 하드닝 + 메타데이터 동기화

#### 수정
- **check-consistency.sh** — `settings.json` 훅 경로 검증을 JSON 파싱 기반으로 보강하고, `strict-mode-exempt:` 예외를 헤더 주석 기준으로만 인정하도록 조정.
- **pre-commit-doc-lint.sh** — strict mode 하에서도 doc-lint 종료 코드를 안전하게 수집하도록 수정.
- **pre-pr-check.sh** — uncommitted change count 계산의 `0\n0` 표현식 오류를 제거.
- **bootstrap.sh / .bootstrap-version** — canonical memory count를 17로 정렬하고 bootstrap 버전을 `v5.5.1`로 갱신.

#### 문서
- **README.md / docs/codebase-summary.md / docs/project-roadmap.md / docs/testing-guide.md** — canonical counts, memory surface, template 수, make target 설명을 실제 저장소 상태와 일치하도록 정리.
- **llms.txt** — HXSK 버전, 업데이트 날짜, skills/hooks/agents/templates/research 카운트를 현행 상태로 갱신.

---

### [2026-04-23] v5.6.0 — 전체 22개 스킬 CSO 최적화 + hook CWD 고정

#### 신규
- **skill-doc-optimizer** — DSPy BootstrapFewShot 기반 스킬 문서 자동 최적화 도구 (`.hxsk/tools/skill-doc-optimizer/`). Watson et al. 2026 OR 메트릭, composite_hallucination_risk 지표.

#### 개선
- **전체 22개 SKILL.md description** — "Use when..." CSO(Context-Selective Output) 패턴으로 일괄 업데이트. composite_hallucination_risk 0.571 → 0.196 (-63%), Val score 0.797.
- **hook CWD 드리프트 수정** — `.claude/settings.json` 모든 `.hxsk/hooks/` 명령에 `cd "${CLAUDE_PROJECT_DIR:-.}" &&` 접두어 추가. `cd` 후 상대 경로 훅 실패 문제 해결.

#### 연구
- Watson et al. 2026 (arXiv:2602.20300) OR 메트릭 + DSPy BootstrapFewShot 최적화 검증 완료 (Phase 10).
- 22개 스킬 중 MEDIUM(bootstrap, commit, create-pr, write-report) 4개 CSO description 수동 검증 완료 (Phase 11, PR #149).

---

### [2026-04-16] v5.5.0 — 하네스 독립 prune + 임계치 5 + 전 local-tier cap

#### 신규
- **prune-tick.sh** — 하네스 독립 opportunistic 트리거. sentinel mtime + mkdir atomic lock, cooldown 60s 기본. 메모리 툴 호출 시 자연 발화.
- **--auto 모드** (`prune-memories.sh`) — 설정 파일(`.hxsk/.prune-config`) 기반으로 전 local-tier에 tier별 cap 일괄 적용. 기본 cap=5 (bootstrap=1).
- **하네스 어댑터 템플릿** (`.hxsk/adapters/`) — Cursor / Gemini CLI / Copilot CLI / Windsurf / OpenCode / Codex CLI 각각의 훅 시스템용 설정 스니펫.
- **git 훅 폴백** (`.hxsk/githooks/post-commit`, `post-merge`) — lifecycle 훅 미지원 하네스(Aider/Continue/Antigravity)용. `core.hooksPath .hxsk/githooks`.
- **`.hxsk/.prune-config` 템플릿** — shell-sourceable 설정 샘플(`templates/prune-config.sample`).

#### 개선
- Stop 훅: 단일 tier hardcode → `--auto` 단일 호출로 전 tier 통합 관리. COUNT > 20 게이트 제거.
- PreCompact 훅: session-summary(20) + session-snapshot(10) 두 줄 → `--auto` 한 줄로 단순화.
- md-store-memory.sh / md-recall-memory.sh / bootstrap.sh 말미에 `prune-tick.sh` 비동기 호출 삽입.
- 기본 cap 20 → 5 (모든 local-tier). bootstrap은 1개만 유지.

#### 연구
- AI 에이전트 하네스 9종 훅 지원 현황 조사 (Cursor/Gemini CLI/Copilot CLI/Windsurf/OpenCode/Codex CLI/Aider/Continue/Antigravity).
- Opportunistic self-trigger 패턴 (sentinel mtime + mkdir atomic lock, BashFAQ/045) 적용.

---

### [2026-04-15] v5.4.0 — Git Forge 통합 작업 관리 + lessons-learned + 메모리 티어 최적화

#### 신규 — Git Forge 통합 작업 관리 (PR #131)
- **GATES.md** — SPEC→PLAN(P1-P5)→EXECUTE→VERIFY→DONE 단일 진실 원천
- **gate-check.sh** — PreToolUse/Stop 훅으로 게이트 조건 자동 집행
- **forge-detect.sh** — remote URL로 플랫폼 감지(GitHub/GitLab/Gitea/Forgejo) → gh/glab/tea CLI 추상화
- AGENTS.md에 게이트 규칙 섹션 추가 — opencode/Copilot/Antigravity 호환

#### 신규 — lessons-learned 체계 (PR #127)
- `lessons-learned` 메모리 타입 추가 — A/B/C/D/E 5개 카테고리로 분류 저장
- `planner` 스킬 — 계획 수립 전 lessons recall + `cross_phase_invariants` 체크리스트
- `executor` 스킬 — invariants 로드 + deviation A-E 분류 자동 저장
- `create-pr` 스킬 — Pre-PR Self-Check A-E 품질 점검
- `pr-review` 스킬 — 리뷰 후 lessons-learned A-E 분류 저장
- `dispatcher` 스킬 — 서브에이전트에 lessons recall + ambiguity log 전달
- `PLAN.md` 템플릿 — `cross_phase_invariants` frontmatter 필드 추가

#### 개선 — 메모리 티어 최적화 (PR #132)
- **Write-gating** — 훅 자체 변경(.hxsk/CURRENT.md, STATE.md, 내부 로그)만 있는 세션은 session-summary 저장 생략
- **Cap 기반 prune** — `prune-memories.sh --max-count N [--tier T]` FIFO 모드 추가. stop-context-save / compact-context가 TTL 대신 최신 20개 유지로 교체
- **가치 기반 승격** — frontmatter `tags: [decision|root-cause|incident|security|pattern|lesson]` 매칭 파일은 삭제 직전 shared-tier 해당 폴더로 자동 `mv`. git이 장기 보존 시스템 역할
- `prune-memories.sh` — `--dry-run` / `--help` / `--max-count` / `--tier` 옵션 (PR #125, #132)
- `RETENTION_DAYS=0` 전체 삭제 분기, `rm` 실패 시 exit 2 + failed 카운터 분리
- `memory-cleanup.sh` 삭제 (30일 아카이브 구정책과 충돌) — `compact-context.sh`가 `prune-memories.sh` 직접 호출

#### 신규 — doc-lint 검증 체계 (PR #123, #126)
- **doc-lint 훅** — PR 전 문서 정합성 6개 항목 검증 (LINK, INDEX, COUNT, REF, ORPHAN)
- **LINK-02** — 마크다운 앵커(`#`) 링크 유효성 검사
- 메모리 2-tier 분리 정착 — local(gitignored) vs shared(git-tracked)

#### 수정
- `dispatcher` 스킬 — 서브에이전트 프롬프트 외부 펜스 4-backtick 교체 (GFM 중첩 코드블록 렌더링 이슈 #002)
- `check-consistency.sh` — dead component 탐지 glob 확장 에러 + grep/wc 예외 처리

#### 문서
- `ANTIGRAVITY_AGENT_GUIDE.md` — Antigravity IDE 에이전트 가이드 추가
- Git Forge 작업 관리 설계 문서 (`docs/plans/2026-04-15-github-task-management-design.md`)
- agent-workflow 통합 설계 + 구현 계획 문서 추가

---

### [2026-04-07] v5.3.0 — 에이전트 규율 강화 + 연구 기반 설계 문서화

#### 신규
- **Iron Laws** 3개 — AGENTS.md에 비타협 규칙 (NO EDIT w/o READ, NO CLAIM w/o VERIFY, NO WRITE to exist)
- **합리화 테이블** 12항목 — empirical-validation 스킬에 허위 완료/Read 건너뛰기/작업 중단 차단
- **Gate Function** 5단계 — IDENTIFY→RUN→READ→VERIFY→CLAIM 완료 검증 게이트
- **Thinking Budget** — 깊은 추론 필요 상황 트리거 (CLAUDE.md + empirical-validation)
- `read-before-edit.py` — PreToolUse 훅, Read 없이 Edit 차단 (Iron Law 인프라 강제)
- `track-read-history.py` — PostToolUse 훅, Read 이력 기록
- `write-guard.py` — PreToolUse 훅, 기존 파일 Write 차단
- `spec-reviewer` 에이전트 — 스펙 준수 리뷰 (2단계 리뷰 Step 1)
- `DESIGN-PHILOSOPHY.md` — 9가지 설계 원칙, 작성 규칙, 연구 근거, 방향성

#### 개선
- 15개 SKILL.md description **CSO 최적화** — 트리거 조건만 기재 (SkillReducer 2026 기반)
- `post-turn-verify.sh` — 완료 키워드 감지 시 검증 명령 이력 확인 게이트 추가
- 4개 핵심 스킬에 **Cross-skill 의존성 마커** 추가 (REQUIRED/RECOMMENDED)
- 2개 스킬에 **보조 문서** 추가 (anti-patterns.md, root-cause-tracing.md)
- `session-start.sh` — read-history.log 초기화 추가
- `skill-testing` 스킬 — RED→GREEN→REFACTOR 사이클, 압박 시나리오 4유형, 메타 테스트
- `subagent-implementer.md` / `subagent-reviewer.md` — 서브에이전트 프롬프트 템플릿 표준화
- `collect-rationalization.sh` — Stop 훅, 합리화 시그널 15패턴 + Iron Law 위반 자동 수집
- `rationalization-update-guide.md` — 합리화 테이블 갱신 프로세스 가이드
- `pre-pr-check.sh` — GITHUB_HEAD_REF로 PR 소스 브랜치 정확 감지 (오탐 수정)

#### 수정
- `check-consistency.sh` — dead component 탐지 grep exit code + wc 멀티라인 처리

#### 연구
- `superpowers-analysis.md` — Superpowers 플러그인 14개 스킬, 10가지 패턴 분석
- `superpowers-references.md` — 7패턴 × 20개 학술/산업 출처
- `claude-code-quality-mitigation.md` — GitHub #42796 품질 저하 완화 분석
- README 연구 기반 테이블에 5개 출처 추가, 3-Phase 로드맵

---

### [2026-04-07] v5.2.1 — CI 안정화 + 버전 동기화 가드레일

#### 수정
- `check-consistency.sh` — memory type 검증 fail → warn 전환 (gitignore 대상, CI 미존재)
- `.bootstrap-version` — 5.2.0 → 5.2.1 동기화
- `actions/checkout` v4 → v6 (Node.js 20 deprecation 대응)

#### 신규
- `dependabot.yml` — GitHub Actions 버전 자동 업데이트 (월 1회)
- `pre-commit-version-check.sh` — bootstrap.sh ↔ .bootstrap-version 버전 불일치 커밋 차단

---

### [2026-04-02] v5.2.0 — 정합성 자동 검증 + pre-PR 자동화 + 문서 체계화

#### 신규
- `check-consistency.sh` — 14개 포인트 정합성 자동 검증 훅 (INDEX, frontmatter, 경로, 버전, 링크, 카운트, 권한, 심볼릭, 메모리, 데드 컴포넌트, strict mode, JSON)
- `pre-pr-check.sh` — PR 전 8개 영역 자동 검증 (버전 동기화, CHANGELOG, GitHub 릴리즈, 카운트)
- `pr-check.yml` — PR 생성 시 CI에서 정합성 + pre-PR 검증 자동 실행

#### 개선
- `setup.md` — settings.json 전체 8개 이벤트 + 에이전트 복사 단계 추가
- `bootstrap.sh` — count_* mkdir -p guard + memories 누락 타입 개별 보충
- `release-setup.yml` — 릴리즈 노트에 CHANGELOG 자동 추출 + setup.md HTML 복사 블럭
- README — 설계 사상 + 핵심 개념 6가지 체계화 전면 리라이트

#### 수정
- 7개 스킬 경로 `.hxsk/scripts/md-*` → `.hxsk/hooks/md-*`
- 5개 스킬 플러그인 시대 누락 스크립트 참조 제거
- clean 에이전트 설명 ruff/mypy → shellcheck/shfmt
- dispatcher 에이전트 경로 `.hxsk/scripts/` 접두사 추가

---

### [2026-03-31] v5.1.1 — Hook 경로 수정 + gitignore 리팩토링

**변경 파일**: 6개 | **Issue**: #001

#### 배경 및 원인
`.claude/settings.json`의 훅 command 경로에서 `"$CLAUDE_PROJECT_DIR"` 환경변수가 Claude Code 훅 러너에서 확장되지 않아 간헐적 `PreToolUse hook error` 발생.

#### 수정 내용
- `.claude/settings.json` — 모든 훅 command 경로를 상대 경로(`.hxsk/hooks/...`)로 변경 (11곳)
- `.hxsk/docs/HOOKS.md` — settings.json 예시 코드 + 환경변수 주의사항 추가
- `.hxsk/ARCHITECTURE.md` — Conventions 섹션 훅 경로 설명 수정
- `.hxsk/prompts/setup.md` — Step 6 훅 설치 예시 상대 경로로 수정
- `.hxsk/prompts/migrate-hook-paths.md` — 기존 프로젝트용 마이그레이션 프롬프트 신규
- `.gitignore` — allowlist→blocklist 전환, 불필요 항목 정리
- `.hxsk/.bootstrap-version` — 5.1.0 → 5.1.1

---

### [2026-02-05 15:15] Session: fa4bad97

**변경 파일**: 36개
**추가/삭제**: +387 / -1528

#### 수정된 파일
- .claude/agents/arch-review.md
- .claude/agents/bootstrap.md
- .claude/agents/context-health-monitor.md
- .claude/agents/executor.md
- .claude/agents/impact-analysis.md
- .claude/agents/planner.md
- .claude/hooks/mcp-recall-memory.sh
- .claude/hooks/mcp-store-memory.sh
- .claude/hooks/post-turn-index.sh
- .claude/hooks/pre-compact-save.sh
- .claude/hooks/session-start.sh
- .claude/hooks/stop-context-save.sh
- .claude/settings.json
- .claude/skills/arch-review/SKILL.md
- .claude/skills/bootstrap/SKILL.md
- .claude/skills/context-health-monitor/SKILL.md
- .claude/skills/debugger/SKILL.md
- .claude/skills/executor/SKILL.md
- .claude/skills/impact-analysis/SKILL.md
- .claude/skills/memory-protocol/SKILL.md
- .claude/skills/planner/SKILL.md
- .github/agents/agent.md
- .mcp.json
- CLAUDE.md
- Makefile
- pyproject.toml
- scripts/bootstrap.sh
- scripts/index-codebase.sh
- scripts/migrate-memories.py
- tests/test_sample.py
- uv.lock

#### 새 파일
- .claude/hooks/mcp-recall-memory.sh.deprecated
- .claude/hooks/mcp-store-memory.sh.deprecated
- .claude/hooks/md-recall-memory.sh
- .claude/hooks/md-store-memory.sh
- .claude/hooks/post-turn-index.sh.deprecated

#### 삭제된 파일
- .claude/hooks/mcp-recall-memory.sh
- .claude/hooks/mcp-store-memory.sh
- .claude/hooks/post-turn-index.sh
- .mcp.json
- scripts/index-codebase.sh
- scripts/migrate-memories.py

---


### [2026-02-05 15:31] Session: 8037a162

**변경 파일**: 44개
**추가/삭제**: +624 / -1534

#### 수정된 파일
- .claude/agents/arch-review.md
- .claude/agents/bootstrap.md
- .claude/agents/context-health-monitor.md
- .claude/agents/executor.md
- .claude/agents/impact-analysis.md
- .claude/agents/planner.md
- .claude/hooks/mcp-recall-memory.sh
- .claude/hooks/mcp-store-memory.sh
- .claude/hooks/post-turn-index.sh
- .claude/hooks/pre-compact-save.sh
- .claude/hooks/session-start.sh
- .claude/hooks/stop-context-save.sh
- .claude/settings.json
- .claude/skills/arch-review/SKILL.md
- .claude/skills/bootstrap/SKILL.md
- .claude/skills/clean/SKILL.md
- .claude/skills/codebase-mapper/SKILL.md
- .claude/skills/commit/SKILL.md
- .claude/skills/context-health-monitor/SKILL.md
- .claude/skills/create-pr/SKILL.md
- .claude/skills/debugger/SKILL.md
- .claude/skills/empirical-validation/SKILL.md
- .claude/skills/executor/SKILL.md
- .claude/skills/impact-analysis/SKILL.md
- .claude/skills/memory-protocol/SKILL.md
- .claude/skills/plan-checker/SKILL.md
- .claude/skills/planner/SKILL.md
- .claude/skills/pr-review/SKILL.md
- .claude/skills/verifier/SKILL.md
- .github/agents/agent.md
- .mcp.json
- CLAUDE.md
- Makefile
- pyproject.toml
- scripts/bootstrap.sh
- scripts/index-codebase.sh
- scripts/migrate-memories.py
- tests/test_sample.py
- uv.lock

#### 새 파일
- .claude/hooks/mcp-recall-memory.sh.deprecated
- .claude/hooks/mcp-store-memory.sh.deprecated
- .claude/hooks/md-recall-memory.sh
- .claude/hooks/md-store-memory.sh
- .claude/hooks/post-turn-index.sh.deprecated

#### 삭제된 파일
- .claude/hooks/mcp-recall-memory.sh
- .claude/hooks/mcp-store-memory.sh
- .claude/hooks/post-turn-index.sh
- .mcp.json
- scripts/index-codebase.sh
- scripts/migrate-memories.py

---


### [2026-02-20] PR #26 — 메모리 스크립트 경로 정규화 (방안 C)

**변경 파일**: 15개 | **PR**: #26

#### 배경 및 원인
플러그인 환경(`autorag` 등)에서 `bash .claude/hooks/md-store-memory.sh` 실행 시 **exit 127** 발생.
SKILL.md 내 경로가 보일러플레이트 구조(`.claude/hooks/`)에 하드코딩되어, 플러그인 설치 경로(`.claude/plugins/gsd/scripts/`)와 불일치.

#### 수정된 파일
- `.claude/skills/` 8개 SKILL.md — `bash .claude/hooks/md-*.sh` → `bash scripts/md-*.sh` (33곳)
- `.claude/hooks/pre-compact-save.sh` — `COMPACT_SCRIPT` 경로를 `dirname "$0"` 기반 자기참조로 수정
- `scripts/build-plugin.sh` — Phase 3 치환 로직 + Phase 8 검증 추가
- `scripts/md-store-memory.sh`, `scripts/md-recall-memory.sh`, `scripts/_json_parse.sh` — 심볼릭 링크 신규 생성
- `CLAUDE.md`, `.gsd/PATTERNS.md` — 문서 경로 업데이트

#### 개선 사항
- 보일러플레이트 직접 사용: 심볼릭 링크로 기존 동작 유지
- 플러그인 빌드: `scripts/` → `${CLAUDE_PLUGIN_ROOT}/scripts/` 자동 치환
- 빌드 검증 강화: Phase 8에 `.claude/hooks/` 잔존 여부 체크 추가

---

### [2026-02-19 13:49] Session: 1b5a5395

**변경 파일**: 1개
**추가/삭제**: +1 / -0

#### 수정된 파일
- CLAUDE.md

---


### [2026-02-20 15:01] Session: 4b4dcb1f

**변경 파일**: 124개
**추가/삭제**: +0 / -0

#### 새 파일
- gsd-plugin/.claude-plugin/plugin.json
- gsd-plugin/README.md
- gsd-plugin/agents/arch-review.md
- gsd-plugin/agents/bootstrap.md
- gsd-plugin/agents/clean.md
- gsd-plugin/agents/codebase-mapper.md
- gsd-plugin/agents/commit.md
- gsd-plugin/agents/context-health-monitor.md
- gsd-plugin/agents/create-pr.md
- gsd-plugin/agents/debugger.md
- gsd-plugin/agents/executor.md
- gsd-plugin/agents/impact-analysis.md
- gsd-plugin/agents/plan-checker.md
- gsd-plugin/agents/planner.md
- gsd-plugin/agents/pr-review.md
- gsd-plugin/agents/verifier.md
- gsd-plugin/commands/arch-review.md
- gsd-plugin/commands/bootstrap.md
- gsd-plugin/commands/clean.md
- gsd-plugin/commands/codebase-mapper.md
- gsd-plugin/commands/commit.md
- gsd-plugin/commands/context-health-monitor.md
- gsd-plugin/commands/create-pr.md
- gsd-plugin/commands/debugger.md
- gsd-plugin/commands/empirical-validation.md
- gsd-plugin/commands/executor.md
- gsd-plugin/commands/impact-analysis.md
- gsd-plugin/commands/init.md
- gsd-plugin/commands/memory-protocol.md
- gsd-plugin/commands/plan-checker.md
- gsd-plugin/commands/planner.md
- gsd-plugin/commands/pr-review.md
- gsd-plugin/commands/verifier.md
- gsd-plugin/hooks/hooks.json
- gsd-plugin/references/CLAUDE.md
- gsd-plugin/references/Makefile
- gsd-plugin/references/env.example
- gsd-plugin/references/github-agent.md
- gsd-plugin/references/gitignore.txt
- gsd-plugin/references/issue-templates/bug_report.yml
- gsd-plugin/references/issue-templates/config.yml
- gsd-plugin/references/issue-templates/feature_request.yml
- gsd-plugin/references/vscode-extensions.json
- gsd-plugin/references/vscode-settings.json
- gsd-plugin/scripts/_json_parse.sh
- gsd-plugin/scripts/auto-format.sh
- gsd-plugin/scripts/bash-guard.py
- gsd-plugin/scripts/compact-context.sh
- gsd-plugin/scripts/file-protect.py
- gsd-plugin/scripts/md-recall-memory.sh
- gsd-plugin/scripts/md-store-memory.sh
- gsd-plugin/scripts/organize-docs.sh
- gsd-plugin/scripts/post-turn-verify.sh
- gsd-plugin/scripts/pre-compact-save.sh
- gsd-plugin/scripts/save-session-changes.sh
- gsd-plugin/scripts/save-transcript.sh
- gsd-plugin/scripts/scaffold-gsd.sh
- gsd-plugin/scripts/scaffold-infra.sh
- gsd-plugin/scripts/session-start.sh
- gsd-plugin/scripts/stop-context-save.sh
- gsd-plugin/scripts/track-modifications.sh
- gsd-plugin/skills/arch-review/SKILL.md
- gsd-plugin/skills/arch-review/scripts/check_complexity.sh
- gsd-plugin/skills/bootstrap/SKILL.md
- gsd-plugin/skills/clean/SKILL.md
- gsd-plugin/skills/clean/scripts/run_quality_checks.sh
- gsd-plugin/skills/codebase-mapper/SKILL.md
- gsd-plugin/skills/codebase-mapper/scripts/scan_structure.sh
- gsd-plugin/skills/commit/SKILL.md
- gsd-plugin/skills/context-health-monitor/SKILL.md
- gsd-plugin/skills/context-health-monitor/scripts/dump_state.sh
- gsd-plugin/skills/create-pr/SKILL.md
- gsd-plugin/skills/debugger/SKILL.md
- gsd-plugin/skills/debugger/scripts/collect_diagnostics.sh
- gsd-plugin/skills/empirical-validation/SKILL.md
- gsd-plugin/skills/executor/SKILL.md
- gsd-plugin/skills/impact-analysis/SKILL.md
- gsd-plugin/skills/memory-protocol/SKILL.md
- gsd-plugin/skills/plan-checker/SKILL.md
- gsd-plugin/skills/planner/SKILL.md
- gsd-plugin/skills/pr-review/SKILL.md
- gsd-plugin/skills/pr-review/scripts/extract_pr_diff.sh
- gsd-plugin/skills/verifier/SKILL.md
- gsd-plugin/skills/verifier/scripts/check_artifacts.sh
- gsd-plugin/templates/gsd/CHANGELOG.md
- gsd-plugin/templates/gsd/DECISIONS.md
- gsd-plugin/templates/gsd/JOURNAL.md
- gsd-plugin/templates/gsd/PATTERNS.md
- gsd-plugin/templates/gsd/ROADMAP.md
- gsd-plugin/templates/gsd/SPEC.md
- gsd-plugin/templates/gsd/STACK.md
- gsd-plugin/templates/gsd/STATE.md
- gsd-plugin/templates/gsd/TODO.md
- gsd-plugin/templates/gsd/examples/cross-platform.md
- gsd-plugin/templates/gsd/examples/quick-reference.md
- gsd-plugin/templates/gsd/examples/workflow-example.md
- gsd-plugin/templates/gsd/templates/DEBUG.md
- gsd-plugin/templates/gsd/templates/PLAN.md
- gsd-plugin/templates/gsd/templates/RESEARCH.md
- gsd-plugin/templates/gsd/templates/SUMMARY.md
- gsd-plugin/templates/gsd/templates/UAT.md
- gsd-plugin/templates/gsd/templates/VERIFICATION.md
- gsd-plugin/templates/gsd/templates/architecture.md
- gsd-plugin/templates/gsd/templates/context-config.yaml
- gsd-plugin/templates/gsd/templates/context.md
- gsd-plugin/templates/gsd/templates/current.md
- gsd-plugin/templates/gsd/templates/decisions.md
- gsd-plugin/templates/gsd/templates/discovery.md
- gsd-plugin/templates/gsd/templates/journal.md
- gsd-plugin/templates/gsd/templates/milestone.md
- gsd-plugin/templates/gsd/templates/patterns.md
- gsd-plugin/templates/gsd/templates/phase-summary.md
- gsd-plugin/templates/gsd/templates/project-config.yaml
- gsd-plugin/templates/gsd/templates/project.md
- gsd-plugin/templates/gsd/templates/requirements.md
- gsd-plugin/templates/gsd/templates/roadmap.md
- gsd-plugin/templates/gsd/templates/spec.md
- gsd-plugin/templates/gsd/templates/sprint.md
- gsd-plugin/templates/gsd/templates/stack.md
- gsd-plugin/templates/gsd/templates/state.md
- gsd-plugin/templates/gsd/templates/todo.md
- gsd-plugin/templates/gsd/templates/user-setup.md
- logo.mp4
- logo.png

---


### [2026-03-05 11:32] Session: 817df819

**변경 파일**: 2개
**추가/삭제**: +37 / -0

#### 수정된 파일
- .claude/skills/executor/SKILL.md

#### 새 파일
- .claude/skills/handoff/SKILL.md

---


### [2026-03-11 15:49] Session: 2a02d78f

**변경 파일**: 1개
**추가/삭제**: +0 / -0

#### 새 파일
- docs/PLUGIN-REGISTRATION.md

---


### [2026-03-24 13:12] Session: 99dfb92a

**변경 파일**: 12개
**추가/삭제**: +0 / -0

#### 새 파일
- .claude/worktrees/agent-a1140817/
- .claude/worktrees/agent-a1f6868a/
- .claude/worktrees/agent-a2683ea2/
- .claude/worktrees/agent-a4a2afac/
- .claude/worktrees/agent-a4a3f06e/
- .claude/worktrees/agent-a59ada2e/
- .claude/worktrees/agent-a6d2372d/
- .claude/worktrees/agent-a7ca556c/
- .claude/worktrees/agent-a9a81c13/
- .claude/worktrees/agent-ab60f139/
- .claude/worktrees/agent-abf5a6f8/
- .claude/worktrees/agent-ae39195b/

---


### [2026-03-24 14:50] Session: 7ecfdecc

**변경 파일**: 12개
**추가/삭제**: +0 / -0

#### 새 파일
- .claude/worktrees/agent-a1140817/
- .claude/worktrees/agent-a1f6868a/
- .claude/worktrees/agent-a2683ea2/
- .claude/worktrees/agent-a4a2afac/
- .claude/worktrees/agent-a4a3f06e/
- .claude/worktrees/agent-a59ada2e/
- .claude/worktrees/agent-a6d2372d/
- .claude/worktrees/agent-a7ca556c/
- .claude/worktrees/agent-a9a81c13/
- .claude/worktrees/agent-ab60f139/
- .claude/worktrees/agent-abf5a6f8/
- .claude/worktrees/agent-ae39195b/

---


### [2026-04-21 13:16] Session: c2cca2dd

**변경 파일**: 11개
**추가/삭제**: +0 / -0

#### 새 파일
- docs/code-standards.md
- docs/codebase-summary.md
- docs/configuration-guide.md
- docs/deployment-guide.md
- docs/project-overview-pdr.md
- docs/project-roadmap.md
- docs/system-architecture.md
- docs/testing-guide.md
- learn/260421-1000-hxsk-init/learn-results.tsv
- learn/260421-1000-hxsk-init/summary.md
- learn/260421-1000-hxsk-init/validation-report.md

---


### [2026-04-23 11:42] Session: aadf4b2b

**변경 파일**: 4개
**추가/삭제**: +0 / -0

#### 새 파일
- docs/plans/2026-04-23-dspy-skill-doc-optimizer.md
- learn/260423-1120-hxsk-phase89/learn-results.tsv
- learn/260423-1120-hxsk-phase89/summary.md
- skill-optimizer/SKILL.md

---

