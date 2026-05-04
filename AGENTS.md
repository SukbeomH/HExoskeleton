# HExoskeleton (HXSK)

> AI 에이전트 기반 개발 방법론. 순수 bash + 마크다운 기반, 외부 종속성 없음.
> Setup: llms.txt 또는 .hxsk/prompts/setup.md 참조

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. 파일 기반 메모리 시스템(.hxsk/memories/)과 HXSK(Get Shit Done) 문서 기반 방법론을 결합.

**외부 종속성 없음**: 순수 bash 스크립트 + 마크다운 파일 기반.

## Repository Layout

- **.hxsk/** — 스킬, 에이전트 정의, 훅, 템플릿, 메모리, 이슈, working docs
- **.hxsk/prompts/** — 에이전트별 setup 프롬프트
- **.hxsk/scripts/** — 유틸리티 (이슈 관리, 언어 감지, 워크트리 merge)
- **.hxsk/docs/** — 프로젝트 문서, 실행 계획

## HXSK Workflow

SPEC.md → PLAN.md → EXECUTE → VERIFY. Working docs in `.hxsk/`

### Canonical Active-State Surface
- `.hxsk/CURRENT.md` — latest local session snapshot
- `.hxsk/STATE.md` — structured coordination state
- `.hxsk/SESSION_HANDOFF.md` — minimal next-session re-entry handoff
- `.hxsk/VERIFICATION.md` — verification truth / evidence / verdict

### Parallel Execution Rule
- 기본 원칙은 **1 branch = 1 worktree = 1 active writer** 입니다.
- same-worktree multi-writer 병렬 작업은 기본 금지입니다. 병렬화가 필요하면 worktree를 분리합니다.
- `CURRENT.md` / `SESSION_HANDOFF.md` 는 local latest snapshot 성격이고, `STATE.md` / `VERIFICATION.md` 는 coordination/integration surface 성격입니다.

## Codex CLI Usage

Codex CLI는 Claude Code의 `PreToolUse`/`PostToolUse` 훅 전체를 동일하게 실행하지 못하므로, 이 레포에서는 루트 `AGENTS.md` 지침 + `.codex/hooks.json` Stop 훅 + Git hook 폴백으로 HXSK를 적용한다.

## Hermes Agent Usage

Hermes는 Claude Code 네이티브 훅 모델과 다르므로, 이 레포에서는 **repo-local canonical surface 우선 + Hermes 내장 기능을 thin bridge로 연결**하는 방식으로 HXSK를 적용한다.

### Session Start Checklist
- 먼저 `llms.txt` → `AGENTS.md` → `.hxsk/CURRENT.md` → `.hxsk/STATE.md` → `.hxsk/VERIFICATION.md` 순서로 읽는다.
- 관련 이력은 `rtk bash .hxsk/hooks/md-recall-memory.sh "<query>" "." 5 compact`로 검색한다.
- 장문 메모리는 Hermes built-in memory에 복제하지 않고 `.hxsk/memories/`를 canonical long-form store로 사용한다.

### During Work
- Hermes `todo`는 세션용 작업 큐, `.hxsk/TODO.md`는 repo backlog로 구분한다.
- Hermes `delegate_task` 사용 시에도 HXSK 파일 소유권 규칙과 GATES 규칙을 우선한다.
- repo-local policy, plans, verification 문서를 글로벌 Hermes 규칙보다 우선한다.

### Completion
- 완료 전 실제 검증 명령을 실행하고 결과를 `.hxsk/VERIFICATION.md` 또는 관련 artifact에 남긴다.
- 다음 세션 재진입 정보는 `.hxsk/SESSION_HANDOFF.md`와 `.hxsk/CURRENT.md`에 압축한다.
- 재사용 가능한 패턴/원인 분석은 `md-store-memory.sh`로 `.hxsk/memories/`에 저장한다.

### Codex Session Start Checklist
- 현재 위치가 레포 루트인지 확인하고, 필요 시 `rtk bash .hxsk/scripts/bootstrap.sh`로 구조를 검증한다.
- 구현/리팩터링 전 `.hxsk/SPEC.md`와 관련 working doc을 읽는다.
- 관련 이력은 `rtk bash .hxsk/hooks/md-recall-memory.sh "<query>" "." 5 compact`로 검색한다.

### Codex During Work
- 기존 파일 수정 전 반드시 해당 파일을 먼저 읽는다.
- 명령은 기본적으로 `rtk` prefix를 사용한다.
- PLAN 없이 EXECUTE하지 않는다. 작은 단일 수정은 응답 내 짧은 계획으로 충분하지만, 다단계 작업은 `.hxsk/workflow/GATES.md` 또는 해당 이슈 문서를 기준으로 진행한다.
- 병렬 작업/서브에이전트 사용 시 파일 소유권을 먼저 나눈다.

### Codex Completion
- 완료 전 실제 검증 명령을 실행하고 결과를 보고한다.
- 구조 검증이 필요한 변경은 `rtk bash .hxsk/scripts/local-verify.sh` 또는 더 좁은 검증 명령으로 확인한다.
- 재사용 가능한 패턴, 원인 분석, 세션 요약은 `rtk bash .hxsk/hooks/md-store-memory.sh ...`로 저장한다.

## Memory Protocol

파일 기반 메모리 시스템 (A-Mem 확장).

### Search (우선순위)
| 방식 | 용도 |
|------|------|
| `bash .hxsk/hooks/md-recall-memory.sh <query> "." 5 compact` | 훅 기반 검색 (2-hop 지원) |
| 파일 검색: `.hxsk/memories/` | Broad context |
| 타입별 필터: `.hxsk/memories/{type}/*.md` | Narrow filter |
| lessons-learned 조회: `md-recall-memory.sh "query lessons-learned" "." 5` | 반복 패턴 방지 |

### Storage Triggers
Architecture decisions, bug root causes, patterns, session ends 등 발생 시 자동 저장.
PR 리뷰/실행 이탈 발견 시 → `lessons-learned/{A-E}` 카테고리로 분류 저장.
상세: `.hxsk/skills/memory-protocol/SKILL.md`

## Validation

검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.

### Iron Laws
- `NO EDIT WITHOUT READ FIRST` — 파일을 읽지 않고 수정하지 않는다
- `NO COMPLETION WITHOUT VERIFICATION` — 검증 증거 없이 완료를 선언하지 않는다
- `NO WRITE TO EXISTING FILES` — 기존 파일 수정은 Edit을 사용한다. Write는 새 파일 전용

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력

## Execution Constraints

- **3-Strike Rule**: 동일 접근 3회 연속 실패 시 반드시 전환
- **Atomic Commit**: 태스크당 하나의 커밋. 논리적 단위 유지

## Task Management Gates

See `.hxsk/workflow/GATES.md` for full gate definitions.

### Gate Summary
| Gate | 진입 조건 | 완료 조건 |
|------|-----------|-----------|
| GATE-0 | SPEC.md 존재 + Goals/Scope 섹션 | — |
| GATE-P1~P4 | 이전 GATE 통과 | STATE.md 업데이트 |
| GATE-E0 | GATE-P4 통과 + sub_issue 전체 기록 | Dispatcher 핸드오프 |
| GATE-V0 | 모든 sub_issue closed | Conflict 해결 시작 |
| GATE-D0 | 부모 PR merged | 결과 보고서 + 메모리 동기화 |

### Rules (Claude Code 외 하네스 포함)
- PLAN 없이 EXECUTE 금지
- 파일 소유권 선언 없이 병렬 작업 금지
- PR 없이 main/feat 브랜치 직접 머지 금지
- 모든 하위 이슈 closed 전 VERIFY 금지
- 핸드오프 시 경로만 전달, 파일 내용/이슈 전문 포함 금지

### Forge Platform
플랫폼 자동 감지: `source .hxsk/scripts/forge-detect.sh`
GitHub → `gh` CLI / GitLab → `glab` CLI / Gitea → `tea` CLI

## Agent Boundaries

### Always
- 파일 검색 기반 impact analysis before refactoring or deleting code
- SPEC.md 읽고 구현 시작
- 경험적으로 검증 — 명령 실행 결과로 증명

### Ask First
- Adding external dependencies
- Deleting files outside task scope
- Architectural decisions affecting 3+ modules

### Never
- Read/print .env or credential files
- Commit hardcoded secrets or API keys
- Skip failing tests to "fix later"
- `/autoresearch` 커맨드를 `Iterations: N` 없이 실행 (unbounded 루프 금지)

## Autoresearch 통합 원칙

- HXSK debugger에서 3-Strike 발동 후 원인 불명 복합 버그 → `/autoresearch:debug`로 전환
- 태스크 완료마다 `.hxsk/reports/iteration-log.tsv` 에 결과 한 줄 append
- verify 실패 + attempt < 3: `git revert HEAD --no-edit` 후 다른 방식 재시도
- verify 실패 + attempt == 3: 3-Strike Rule — 사용자 에스컬레이션
