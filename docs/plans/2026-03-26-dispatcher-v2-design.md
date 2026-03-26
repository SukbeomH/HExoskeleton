# Dispatcher v2: 로컬 마크다운 이슈 트래킹 기반 병렬 오케스트레이션

> Date: 2026-03-26
> Status: DRAFT
> Scope: `.hxsk/skills/dispatcher/` 개선 + 신규 템플릿/스크립트

## Background

기존 dispatcher 스킬은 Wave 기반 병렬 실행 + 워크트리 격리를 지원하지만, 진행상황 추적이 부재하고 이슈 레지스트리(L0→L1→L2)가 불필요하게 복잡하다. GitHub Issues 없이 로컬 마크다운으로 동일한 협업 워크플로우를 구현한다.

## Core Concept

**로컬 마크다운 이슈 트래킹**이 핵심. 오케스트레이터가 단일 쓰기 주체로 이슈 문서를 관리하고, 서브에이전트는 `git worktree list`로 메인 루트를 resolve하여 읽기 전용으로 참조한다.

## Document Structure

```
.hxsk/issues/
├── MASTER-{id}.md          # 마스터플랜 (전체 진행상황)
├── WORK-{id}-{seq}.md      # 분할된 Work 단위
└── archive/                # 완료된 이슈 아카이브
```

> **gitignore 정책**: `.hxsk/issues/*.md`를 `.gitignore`에 추가하여 untracked로 유지한다.
> 기존 `!.hxsk/issues/` 규칙은 `.gitkeep`만 tracked되도록 조정.
> 이유: 워크트리에서 stale 복사본이 보이는 문제를 방지하고,
> 서브에이전트가 항상 메인 루트의 최신 문서를 참조하도록 보장.

### MASTER Document

```yaml
---
id: MASTER-{id}
title: "{마스터플랜 제목}"
branch: feat/master-{id}
status: draft | in-progress | review | done
works: [WORK-{id}-1, WORK-{id}-2, ...]
wave_plan:
  wave-1: [WORK-{id}-1, WORK-{id}-2]
  wave-2: [WORK-{id}-3]
created: {YYYY-MM-DD}
---

## Objective
{PLAN.md 또는 SPEC.md에서 도출된 목표}

## Progress
- [ ] Wave 1 (0/2)
- [ ] Wave 2 (0/1)

## Merge Log
{각 Work 머지 결과 기록}

## Notes
{충돌 해결, 의사결정 등}
```

### WORK Document

```yaml
---
id: WORK-{id}-{seq}
master: MASTER-{id}
title: "{Work 단위 제목}"
status: pending | in-progress | done | failed
wave: {N}
depends_on: [WORK-{id}-{seq}, ...]   # 의존성 명시 (같은 MASTER 내만 참조)
files: [path/to/file1, path/to/file2]  # 수정 대상 파일
side_effect_files: []                   # 자동 생성 가능 파일 (lock, barrel export 등)
worktree: ""                            # 실행 시 경로 기록
worktree_branch: ""                     # 워크트리 브랜치명 기록
---

## Tasks
1. [ ] {순차 실행할 Task 1}
2. [ ] {순차 실행할 Task 2}
3. [ ] {순차 실행할 Task 3}

## Result
{완료 후 오케스트레이터가 기록: 커밋 해시, 변경 요약}

## Failure Log
{실패 시 오케스트레이터가 기록: 사유, 시도 횟수}
```

## Orchestration Lifecycle

### Phase 구조

Phase 1 (SPLIT)과 Phase 2 (BRANCH)는 1회 실행.
Phase 3-5는 **Wave별 루프**로 실행. Phase 6은 전체 완료 후 1회 실행.

```
Phase 1: SPLIT
Phase 2: BRANCH
┌─── Wave Loop ───────────────────┐
│  Phase 3: DISPATCH (Wave N)     │
│  Phase 4: TRACK (Wave N)        │
│  Phase 5: MERGE (Wave N)        │
│  → Wave N+1이 있으면 루프 반복   │
└─────────────────────────────────┘
Phase 6: VERIFY → CLOSE
```

> **핵심**: Wave N+1의 워크트리는 Wave N 머지 완료 후 이슈 브랜치에서 생성한다.
> 이렇게 해야 Wave N+1 서브에이전트가 Wave N의 변경사항을 기반으로 작업한다.

### Phase 1: PLAN → SPLIT
- PLAN.md 또는 SPEC.md를 읽고 Work 단위로 분할
- MASTER-{id}.md 생성, WORK-{id}-{seq}.md 일괄 생성
- 파일 소유권 검증:
  - `files`와 `side_effect_files` 모두 포함하여 겹침 체크
  - 같은 Wave 내 겹침 → 에러, Wave 분리 필요
  - 다른 Wave 간 겹침 → depends_on에 선행 Work 명시 필요
- depends_on 기반 Wave 자동 배정 (위상 정렬):
  1. 모든 WORK의 depends_on 그래프 구성
  2. **순환 의존성 감지** → 발견 시 에러, 사용자에게 분할 재요청
  3. depends_on이 비어있으면 → Wave 1
  4. 복수 의존성: `max(선행 Work들의 Wave) + 1`로 배정
  5. 위상 정렬 순서대로 처리 (미할당 선행 Work 문제 방지)

### Phase 2: BRANCH
- 메인 이슈 브랜치 생성: `git checkout -b feat/master-{id}`
- MASTER 문서에 branch 필드 기록

### Phase 3: DISPATCH (Wave별)
- 현재 Wave의 Work들만 실행
- 각 Work → `Agent(isolation: "worktree")` 생성
  - 워크트리 브랜치명: `feat/master-{id}/work-{seq}`
- 동일 Wave 내 Work은 `run_in_background: true`로 병렬
- 서브에이전트 프롬프트에 WORK 문서 경로 + 메인 루트 resolve 방법 주입
- WORK 문서에 worktree 경로 및 worktree_branch 기록

### Phase 4: TRACK (Wave별)
- 각 Work 완료 시 WORK 문서 status 업데이트
- MASTER 문서 Progress 섹션 갱신
- 실패 시 status: failed + Failure Log 기록, 3-Strike Rule 적용
- Wave 내 모든 Work 완료 확인 후 Phase 5로 이행

### Phase 5: MERGE (Wave별)
- 완료된 워크트리를 메인 이슈 브랜치에 순차 머지
- `scripts/merge-worktrees.sh` 활용 (기존 스크립트 재사용)
- **워크트리 보존**: 머지 후 즉시 삭제하지 않고 Phase 6 검증 통과까지 유지
- 충돌 발생 시 MASTER 문서 Notes에 기록 + 오케스트레이터가 해결
- MASTER 문서 Merge Log에 결과 기록
- → 다음 Wave가 있으면 Phase 3로 복귀 (이슈 브랜치 기반으로 새 워크트리 생성)

### Phase 6: VERIFY → CLOSE
- 메인 이슈 브랜치에서 통합 테스트 실행
- 검증 실패 시 → 워크트리가 보존되어 있으므로 디버깅/롤백 가능
- 검증 통과 후 → 워크트리 정리, MASTER 문서 status: done
- 완료 이슈를 `archive/`로 이동
- 마스터 머지는 사용자 확인 후 진행

## Crash Recovery Protocol

오케스트레이터가 중단된 경우 재개 절차:

1. `.hxsk/issues/MASTER-*.md`에서 status: in-progress인 문서 검색
2. 해당 MASTER의 WORK 문서들의 status 확인
3. status: in-progress인 WORK에 대해:
   - `git worktree list`로 워크트리 존재 확인
   - 존재하면 → `git log --oneline`으로 커밋 확인하여 실제 완료 여부 판단
   - 존재하지 않으면 → status: failed로 갱신, 재실행 대상
4. 미완료 Wave부터 Phase 3 루프 재개

## Subagent Interface

### Prompt Injection Template
```
You are executing {WORK_ID}.
Main root: resolve via `git worktree list | head -1 | awk '{print $1}'`
Read your work spec: {main_root}/.hxsk/issues/{WORK_ID}.md

Rules:
- Tasks 섹션의 체크리스트를 순차 수행
- files 필드에 명시된 파일만 수정 (side_effect_files는 허용)
- 각 Task마다 atomic commit
- 커밋 메시지 형식: feat({WORK_ID}): {내용}
- files + side_effect_files 범위 밖 파일 수정 금지
- 완료/실패 시 exit
```

### Main Root Resolve (범용)
```bash
MAIN_ROOT=$(git worktree list | head -1 | awk '{print $1}')
```
어떤 프로젝트/머신에서든 별도 설정 없이 동작.

### Orchestrator Status Detection
- Agent 도구의 반환값으로 성공/실패 판단
- 워크트리의 `git log --oneline`으로 실제 커밋 확인
- WORK 문서 status를 done 또는 failed로 업데이트

## File Ownership Validation

```
Phase 1에서 수행:
1. 모든 WORK 문서의 files + side_effect_files 필드 추출
2. 같은 Wave 내 겹침 → 에러, Wave 분리 필요
3. 다른 Wave 간 겹침 → depends_on에 선행 Work 명시 필요
4. side_effect_files 간 겹침도 동일 규칙 적용
```

## Integration with Existing System

### 변경 파일
| 파일 | 변경 유형 |
|------|-----------|
| `.hxsk/skills/dispatcher/SKILL.md` | 확장: 4-Phase → 6-Phase (Wave 루프) |
| `.hxsk/agents/dispatcher.md` | 업데이트: 오케스트레이션 단계 + allowed-tools 정합성 |
| `.hxsk/templates/MASTER-ISSUE.md` | 신규 |
| `.hxsk/templates/WORK-ISSUE.md` | 신규 |
| `scripts/issue-create.sh` | 업데이트: MASTER/WORK 스키마 호환 |
| `scripts/issue-list.sh` | 업데이트: MASTER/WORK 문서 목록 표시 |
| `.gitignore` | 수정: `.hxsk/issues/*.md` untracked 추가 |

### 유지
- Wave 기반 실행 모델
- `Agent(isolation: "worktree")` 패턴
- `scripts/merge-worktrees.sh` 재사용
- 기존 파일 소유권 검증 로직 (side_effect_files로 강화)

### 제거
- 이슈 레지스트리 Lazy loading (L0→L1→L2) → WORK 문서로 단순화
- 기존과 중복되는 상태 추적 방식

### 역할 분리: 스크립트 vs AI 에이전트
| 역할 | 담당 |
|------|------|
| MASTER/WORK 템플릿 생성 | 스크립트 (`issue-create.sh`) |
| PLAN → Work 분할, 의존성 분석, 파일 배정 | AI 에이전트 (오케스트레이터) |
| 위상 정렬, 순환 의존성 감지 | AI 에이전트 (오케스트레이터) |
| 파일 소유권 검증 | 스크립트 (기존 로직 강화) |

> `split-plan.sh`는 신규 생성하지 않는다. PLAN.md의 XML task 블록 파싱은
> 순수 bash로 신뢰성이 낮으므로, AI 에이전트가 직접 분할하고
> `issue-create.sh`로 문서를 생성하는 구조로 한다.

## Research References

| 프로젝트 | 참고 포인트 |
|----------|------------|
| [ccswarm](https://github.com/nwiizo/ccswarm) | 멀티 에이전트 오케스트레이션, 워크트리 격리 |
| [parallel-worktrees](https://github.com/spillwavesolutions/parallel-worktrees) | Claude Code 스킬 기반 병렬 워크트리 |
| [Backlog.md](https://github.com/MrLesk/Backlog.md) | 마크다운 기반 이슈 트래킹 |
| [tick-md](https://purplehorizons.io/blog/tick-md-multi-agent-coordination-markdown) | 마크다운 기반 멀티 에이전트 조율 |
| [Clash](https://github.com/clash-sh/clash) | 워크트리 간 머지 충돌 사전 감지 |

## Design Decisions

| 결정 | 선택 | 이유 |
|------|------|------|
| 이슈 문서 쓰기 주체 | 오케스트레이터 단독 | 머지 충돌 방지, 단일 진실 소스 |
| 메인 루트 resolve | `git worktree list` | 범용적, 외부 종속성 없음 |
| 실행 모델 | Wave 유지 + 의존성 문서화 | 검증된 패턴 + 추적성 |
| 기존 dispatcher 관계 | in-place 개선 | 중복 기능/혼란 방지 |
| 이슈 저장 위치 | `.hxsk/issues/` (git-untracked) | 워크트리 stale 복사본 방지, 절대경로 참조 |
| Phase 3-5 구조 | Wave별 루프 | Wave N+1이 Wave N 결과 기반으로 동작 보장 |
| 워크트리 보존 | Phase 6 검증 후 정리 | 검증 실패 시 롤백/디버깅 경로 확보 |
| split-plan.sh | 생성하지 않음 | bash XML 파싱 비현실적, AI 에이전트 직접 분할 |
| 의존성 해석 | 위상 정렬 + 순환 감지 | 다중 의존성, 다이아몬드 의존성 안전 처리 |
| side_effect_files | WORK 문서에 명시 | lock 파일, barrel export 등 간접 충돌 방지 |
