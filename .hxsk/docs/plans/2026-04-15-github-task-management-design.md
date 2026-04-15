# Git Forge 기반 작업 관리 시스템 설계 v2

> 작성일: 2026-04-15 / 개정: 2026-04-15 (멀티홉 아키텍처 + 토큰 최적화)
> 참고:
>   - `.hxsk/research/workflow/RESEARCH-github-task-management-workflow.md`
>   - `.hxsk/research/workflow/RESEARCH-multi-platform-compatibility.md`
>   - `.hxsk/research/workflow/RESEARCH-token-optimization-multi-hop.md`
> 상태: DONE (PR #131 merged — GATES.md, forge-detect.sh, AGENTS.md, STATE.md, gate-check.sh)
> 호환 플랫폼: GitHub ✅ / GitLab ✅ (85%) / Gitea ✅ (80%) / Forgejo ✅ (80%)

---

## 개요

3-레이어 멀티홉 아키텍처로 책임 영역을 명확히 분리.
각 레이어는 인접 레이어의 내부를 모르며, 공유 상태(STATE.md, .hxsk/issues/)로만 통신.
핸드오프 시 경로/요약만 전달하여 토큰 소모 60-75% 절감.

**단일 진실 원천**: `.hxsk/workflow/GATES.md`

---

## 3-레이어 책임 영역

```
┌─────────────────────────────────────────────────────┐
│  HOP 1: GATES (조건 & 플랫폼 연동)                   │
│  "진행해도 되는가? 어디에 기록하는가?"               │
├─────────────────────────────────────────────────────┤
│  HOP 2: Dispatcher (실행 엔진)                       │
│  "어떻게 병렬로 쪼개서 실행하는가?"                  │
├─────────────────────────────────────────────────────┤
│  HOP 3: Sub-agent (작업 실행)                        │
│  "실제 파일을 어떻게 변경하는가?"                    │
└─────────────────────────────────────────────────────┘
```

| 책임 | GATES | Dispatcher | Sub-agent |
|------|:-----:|:----------:|:---------:|
| 게이트 조건 정의/검증 | ✅ | ❌ | ❌ |
| 계획 브랜치 + 부모 이슈 생성 | ✅ | ❌ | ❌ |
| 하위 이슈 생성 + PR 리뷰 게이트 | ✅ | ❌ | ❌ |
| 전체 진행률 추적 | ✅ | ❌ | ❌ |
| PLAN → WORK 분해 + Wave 배정 | ❌ | ✅ | ❌ |
| 파일 소유권 검증 + 워크트리 관리 | ❌ | ✅ | ❌ |
| 머지/충돌 해결 | ❌ | ✅ | ❌ |
| 실제 코드 변경 + Atomic 커밋 | ❌ | ❌ | ✅ |
| Self-review (A-E) | ❌ | ❌ | ✅ |

**경계 규칙**:
- GATES는 Dispatcher 내부를 모름 — "완료됐는가"만 확인
- Dispatcher는 GitHub 이슈를 모름 — WORK 문서만 읽고 씀
- Sub-agent는 Wave/게이트를 모름 — 할당된 파일만 변경

---

## 멀티홉 흐름 도식

```
┌── HOP 1: GATES ─────────────────────────────────────────┐
│  [GATE-0] SPEC.md Goals+Scope 확인                       │
│  P1: feat/plan-xxx 브랜치 생성                           │
│  P2: 부모 이슈 생성 (forge-detect.sh)                    │
│  P3: PLAN.md 분석 → 파일 소유권 맵 작성                  │
│  [GATE-P3] 파일 중복 없음, parallel:false 확인           │
│  P4: 하위 이슈 생성 (forge-detect.sh)                    │
│  ── HOP 1→2 핸드오프 (토큰 최소) ─────────────────────  │
│  전달: PLAN.md 경로 + 파일 소유권 맵 + 하위 이슈 번호    │
│  금지: 대화 내역, 이슈 내용, SPEC 전문                   │
└──────────────────────────────────────────────────────────┘
         ↓ 위임
┌── HOP 2: Dispatcher ────────────────────────────────────┐
│  WORK 문서 생성 (.hxsk/issues/)                          │
│  Wave 배정 (위상 정렬) + 파일 소유권 검증                │
│  워크트리 생성 (.worktrees/{name})                       │
│  ── HOP 2→3 핸드오프 (토큰 최소) ─────────────────────  │
│  전달: WORK 문서 경로만                                  │
│  금지: Dispatcher 컨텍스트, MASTER 전문, 파일 내용       │
└──────────────────────────────────────────────────────────┘
         ↓ 병렬 위임 × N
┌── HOP 3: Sub-agent ─────────────────────────────────────┐
│  WORK 문서 Read → files 범위 내 코드 변경                │
│  atomic 커밋 per task                                   │
│  Self-review A-E 완료                                    │
│  완료 보고 (최소): STATUS / COMMITS / SELF_REVIEW        │
└──────────────────────────────────────────────────────────┘
         ↑ 요약 보고
┌── HOP 2: Dispatcher (수신) ─────────────────────────────┐
│  WORK done 업데이트 → 워크트리 머지 → 충돌 해결          │
│  Wave 완료 → 다음 Wave 또는 GATES에 보고                 │
│  ── HOP 2→1 보고 ───────────────────────────────────── │
│  전달: 완료 / PR 번호 목록 / 실패 WORK 목록만            │
└──────────────────────────────────────────────────────────┘
         ↑ 요약 보고
┌── HOP 1: GATES (수신) ──────────────────────────────────┐
│  [GATE-V0] 모든 하위 이슈 closed 확인                    │
│  V1: 컨플릭트 없음 (feat/plan-xxx)                       │
│  V2: SPEC.md Goals 대비 검증 + 부모 이슈 코멘트          │
│  V3: 부모 PR 생성 → 최종 리뷰 게이트                     │
│  [GATE-D0] 머지 → 결과 보고서 + lessons-learned         │
└──────────────────────────────────────────────────────────┘
```

---

## 단계별 게이트 정의 (GATES.md 원형)

```markdown
## GATE-0: SPEC → PLAN 진입
진입 조건:
  - SPEC.md 존재
  - SPEC.md 내 `## Goals`, `## Scope` 섹션 포함

## GATE-P1: 계획 브랜치 생성 완료
진입 조건:
  - `feat/plan-{name}` 브랜치 존재 (`git branch --list`)
완료 조건:
  - 브랜치명이 PLAN.md에 기록

## GATE-P2: 부모 이슈 생성 완료
진입 조건:
  - GATE-P1 통과
완료 조건:
  - 이슈 번호가 PLAN.md `## GitHub` 섹션에 기록
  - 브랜치와 이슈 연동 확인 (`gh issue view N`)

## GATE-P3: 초안 분석 완료
진입 조건:
  - GATE-P2 통과
완료 조건:
  - PLAN.md에 태스크 분할 목록 존재 (`- [ ]` 형식)
  - 각 태스크에 `files:` 필드로 파일 소유권 선언
  - 파일 중복 없음 (동일 파일을 2개 이상 태스크가 소유하지 않음)
  - Lockfile/config 변경 태스크는 `parallel: false` 명시

## GATE-P4: 하위 이슈 + 브랜치 생성 완료
진입 조건:
  - GATE-P3 통과
완료 조건:
  - 각 태스크에 대해 하위 이슈 번호 기록
  - 각 태스크에 대해 `task/{name}` 브랜치 존재

## GATE-P5 / GATE-E0: 워크트리 생성 완료
진입 조건:
  - GATE-P4 통과
완료 조건:
  - `.worktrees/{task-name}/` 디렉토리 전수 존재

## GATE-E1: 태스크 PR 리뷰
진입 조건:
  - 태스크 구현 완료
  - 이슈 댓글에 완료 내역 기록
완료 조건:
  - PR approved
  - PR 본문에 `Closes #{sub-issue-number}` 포함
  - 리뷰 코멘트 전수 resolve

## GATE-V0: VERIFY 진입
진입 조건:
  - 모든 서브이슈 closed
  - 모든 task/ 브랜치 merged

## GATE-V1: 컨플릭트 해결 완료
진입 조건:
  - GATE-V0 통과
완료 조건:
  - `feat/plan-{name}` 브랜치에서 컨플릭트 없음
  - 빌드/테스트 통과

## GATE-V2: 계획 의도 검증
진입 조건:
  - GATE-V1 통과
완료 조건:
  - SPEC.md Goals 항목 전수 체크
  - 부모 이슈에 검증 결과 코멘트 작성

## GATE-V3: 최종 리뷰
진입 조건:
  - GATE-V2 통과
완료 조건:
  - 부모 PR approved
  - 리뷰 코멘트 타당성 판단 후 전수 resolve

## GATE-D0: DONE 진입
진입 조건:
  - 부모 PR merged
완료 조건:
  - 결과 보고서 생성
  - lessons-learned 메모리 저장
  - 임시 워크트리/브랜치 삭제
```

---

## 레이어 간 인터페이스 계약

### HOP 1→2 (GATES → Dispatcher)

```
GATES 보장 입력:
  - PLAN.md 경로
  - 파일 소유권 맵 (태스크명 → files)
  - parallel:false 태스크 목록
  - 하위 이슈 번호 목록 (STATE.md에 기록)

Dispatcher 보장 출력:
  - PR 번호 목록
  - 완료 신호 또는 실패 사유 + 영향 WORK ID
```

### HOP 2→3 (Dispatcher → Sub-agent)

```
Dispatcher 보장 입력:
  - WORK 문서 경로 (내용 아님)
  - main root 경로

Sub-agent 보장 출력:
  WORK: {id}
  STATUS: done | failed
  COMMITS: {hash1}, {hash2}
  SELF_REVIEW: A:PASS B:PASS C:PASS D:N/A E:PASS
  DECISIONS: none
```

---

## 공유 상태 (레이어 간 유일한 통신 채널)

```
STATE.md
  ## Active Gate          ← GATES가 쓰고 읽음
  plan: feat/plan-xxx
  parent_issue: #N
  current_gate: GATE-P3
  sub_issues: [#N+1, #N+2]

  ## Active Dispatcher    ← Dispatcher가 쓰고 읽음
  master: MASTER-001
  wave: 2
  status: in-progress

.hxsk/issues/
  MASTER-*.md             ← Dispatcher 오케스트레이터만 쓰기
  WORK-*.md               ← Sub-agent 읽기 / Dispatcher 쓰기
```

`session-start.sh`가 STATE.md 자동 로드 → 게이트 상태 세션 간 연속성 보장.

---

## Git 이슈/커밋 메모리 레이어

리서치 출처: `.hxsk/research/workflow/RESEARCH-git-issue-as-memory.md`

**역할 분리**: 로컬 파일 = 장기 메모리 / Git 이슈·커밋 = 단기 실행 메모리

| 정보 유형 | 저장 위치 | 검색 방법 |
|-----------|-----------|----------|
| 태스크 진행 로그 | 이슈 코멘트 | `gh issue view N --comments` |
| 아키텍처 결정 | 커밋 메시지 (`DECISION:`) | `git log --grep=DECISION` |
| 검증 이력 | PR 본문/리뷰 | `gh pr view N` |
| 장기 패턴/교훈 | `.hxsk/memories/` | `md-recall-memory.sh` |
| 세션 간 게이트 상태 | `STATE.md ## Active Gate` | session-start.sh 자동 로드 |

**GATE-D0 완료 시 동기화 흐름**:
```
이슈 코멘트 (실행 중 로그)
  → GATE-D0 완료 시 핵심 결정만 추출
  → md-store-memory.sh로 .hxsk/memories/ 저장
  → 이슈는 closed 상태로 아카이브 (삭제 안 함)
```

---

## 토큰 최적화 원칙

| 원칙 | 적용 위치 | 절감 |
|------|-----------|------|
| 경로만 전달, 내용 금지 | 모든 핸드오프 | ~70% |
| 구조화 WORK 문서 (YAML+체크리스트) | HOP 2→3 | ~55-87% |
| 완료 보고 최소화 (요약 테이블) | HOP 3→2 | ~80% |
| 대화 내역 전달 금지 | 서브에이전트 | 격리 |
| 게이트 상태를 STATE.md에 저장 | HOP 1 | 재로드 불필요 |

전체 세션 토큰 절감 추정: **~60-75%**
상세: `.hxsk/research/workflow/RESEARCH-token-optimization-multi-hop.md`

---

## 에이전트 하네스별 구현 방식

### Claude Code (훅 기반)

신규 훅 `gate-check.sh` (PreToolUse + Stop 이벤트):
```
GATES.md 파싱 → 현재 단계 확인 → 조건 미충족 시 차단
```

연동 훅:
- `session-start.sh`: 현재 게이트 상태 로드
- `track-modifications.sh`: 파일 소유권 맵 위반 감지
- `stop-context-save.sh`: 게이트 상태 저장

### opencode / Antigravity / GitHub Copilot (AGENTS.md 기반)

`AGENTS.md` 에 섹션 추가:
```markdown
## Task Management Gates
See `.hxsk/workflow/GATES.md` for full gate definitions.

### Rules
- PLAN 단계 없이 EXECUTE 금지
- 파일 소유권 선언 없이 병렬 작업 금지
- PR 없이 main/feat 브랜치 직접 머지 금지
- 모든 서브이슈 closed 전 VERIFY 금지
```

---

## 멀티 플랫폼 호환성

### 호환 전략

**플랫폼 무관 요소** (변경 없음):
- Git Worktree, GATES.md, AGENTS.md, 브랜치 명명 규칙, `Closes #N` 연동

**플랫폼별 추상화** — `forge-detect.sh` 신규 스크립트:

```
git remote URL 감지
  github.com  → gh CLI
  gitlab.*    → glab CLI
  gitea/forgejo/codeberg → tea CLI
```

### Sub-Issues 플랫폼별 처리

| 플랫폼 | P4 단계 구현 방식 |
|--------|-----------------|
| GitHub | `gh sub-issue create --parent N` (네이티브) |
| GitLab / Gitea / Forgejo | 일반 이슈 생성 + 부모 이슈 본문에 체크리스트 참조 |

### 추가 파일

```
.hxsk/scripts/
  forge-detect.sh     ← 플랫폼 감지 + CLI 추상화 함수 (신규)
```

---

## 파일 구조 (신규 생성 대상)

```
.hxsk/workflow/
  GATES.md              ← 단일 진실 원천 (신규)

.hxsk/hooks/
  gate-check.sh         ← Claude Code 게이트 집행 훅 (신규)

.hxsk/scripts/
  forge-detect.sh       ← 플랫폼 감지 + CLI 추상화 (신규)

AGENTS.md               ← Task Management Gates 섹션 추가 (수정)
```

---

## 구현 우선순위

| 우선순위 | 항목 | 이유 |
|---------|------|------|
| P0 | `GATES.md` 작성 | 모든 구현의 기반 |
| P1 | `AGENTS.md` 섹션 추가 | 즉시 전 하네스 적용, 외부 의존 없음 |
| P2 | `forge-detect.sh` 작성 | gate-check.sh 의존성 |
| P3 | `gate-check.sh` 훅 | Claude Code 자동 집행 |
| P4 | `STATE.md` Active Gate 섹션 추가 | 세션 간 연속성 |

---

## 참고 자료

- `.hxsk/research/workflow/RESEARCH-github-task-management-workflow.md`
- [GitHub flow - GitHub Docs](https://docs.github.com/en/get-started/using-github/github-flow)
- [Adding sub-issues - GitHub Docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)
- [How to Use Git Worktrees for Parallel AI Agent Execution](https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution)
- [Agent Teams Workflow](https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/guide/workflows/agent-teams.md)
