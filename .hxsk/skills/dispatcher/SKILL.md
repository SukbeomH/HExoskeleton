---
name: dispatcher
description: "MASTER/WORK 기반 6-Phase 병렬 이슈 오케스트레이션 — PLAN → 분할 → 워크트리 병렬 실행 → 머지"
version: 2.0.0
trigger: "dispatch|병렬 실행|wave 실행|이슈 배정|이슈 분할|work split|parallel issue|마스터플랜"
allowed-tools:
  - Agent
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

## Quick Reference
- **입력**: PLAN.md/SPEC.md → MASTER/WORK 이슈 문서로 분할
- **출력**: 6-Phase 라이프사이클 (SPLIT → BRANCH → Wave Loop[DISPATCH → TRACK → MERGE] → VERIFY)
- **Main Root**: `git worktree list | head -1 | awk '{print $1}'`
- **규칙**: 같은 Wave 내 files + side_effect_files 겹침 금지
- **Merge**: `scripts/merge-worktrees.sh` 사용

# Dispatcher Skill v2

<role>
You are a 6-Phase parallel dispatch orchestrator.
You split plans into MASTER/WORK issue documents, dispatch each wave's works
as isolated subagents in parallel worktrees, and manage the full lifecycle
from splitting through merge to verification.
</role>

## Orchestration Lifecycle

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

---

### Phase 1: PLAN → SPLIT

PLAN.md 또는 SPEC.md를 읽고 MASTER/WORK 이슈 문서를 생성한다.

1. **MASTER 생성**
   ```bash
   bash scripts/issue-create.sh master "<플랜 제목>"
   ```

2. **Work 분할** — AI 에이전트가 PLAN의 task를 겹치지 않는 Work 단위로 분할
   - 각 Work에 files, side_effect_files 명시
   - depends_on으로 의존성 명시 (같은 MASTER 내만)
   ```bash
   bash scripts/issue-create.sh work <master-id> "<title>" <wave> "<depends_on>" "<files>" "<side_effect_files>"
   ```

3. **Wave 자동 배정** (위상 정렬)
   - 모든 WORK의 depends_on 그래프 구성
   - **순환 의존성 감지** → 발견 시 에러, 사용자에게 분할 재요청
   - depends_on이 비어있으면 → Wave 1
   - 복수 의존성: `max(선행 Work들의 Wave) + 1`
   - 위상 정렬 순서대로 처리

4. **파일 소유권 검증**
   - 같은 Wave 내 Work 간 `files` + `side_effect_files` 겹침 체크
   - 겹침 발견 → Wave 분리 또는 Work 재분할
   - 다른 Wave 간 겹침 → depends_on 명시 필요

5. **MASTER 문서 업데이트** — works, wave_plan 필드 채우기

---

### Phase 2: BRANCH

메인 이슈 브랜치를 생성한다.

```bash
git checkout -b feat/master-<id>
```

MASTER 문서의 branch 필드 기록. status를 `in-progress`로 변경.

---

### Phase 3: DISPATCH (Wave별)

현재 Wave의 Work들을 병렬 워크트리 서브에이전트로 실행한다.

> **중요**: Wave N+1의 워크트리는 Wave N 머지 완료 후 이슈 브랜치에서 생성해야 한다.

각 Work에 대해:

1. WORK 문서 status를 `in-progress`로 업데이트
2. 서브에이전트 dispatch:
   ```
   Agent(
       prompt: <서브에이전트 프롬프트>,
       isolation: "worktree",
       subagent_type: "general-purpose",
       run_in_background: true  # 같은 Wave 내 병렬
   )
   ```
3. WORK 문서에 worktree, worktree_branch 기록

**서브에이전트 프롬프트 템플릿:**
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

---

### Phase 4: TRACK (Wave별)

서브에이전트 완료를 감지하고 이슈 문서를 업데이트한다.

1. **상태 감지**
   - Agent 도구 반환값으로 성공/실패 판단
   - 워크트리 `git log --oneline`으로 실제 커밋 확인

2. **WORK 문서 업데이트**
   - 성공 → status: `done`, Result 섹션에 커밋 해시/변경 요약
   - 실패 → status: `failed`, Failure Log에 사유/시도 횟수
   - 3-Strike Rule: 동일 Work 3회 실패 시 사용자 에스컬레이션

3. **MASTER Progress 갱신**
   - Wave별 완료 현황 업데이트
   - Wave 내 모든 Work 완료 확인 후 Phase 5로 이행

---

### Phase 5: MERGE (Wave별)

완료된 워크트리를 메인 이슈 브랜치에 순차 머지한다.

```bash
bash scripts/merge-worktrees.sh <worktree-path> <branch-name>
```

1. **머지 실행** — Wave 내 Work을 순차 처리
2. **충돌 처리**
   - 자동 해소 시도
   - 실패 시 MASTER Notes에 기록 + 오케스트레이터가 수동 해결
3. **MASTER Merge Log 기록** — 날짜, WORK ID, 커밋 해시, 결과
4. **워크트리 보존** — Phase 6 검증 통과까지 삭제하지 않음
5. → 다음 Wave가 있으면 **Phase 3로 복귀** (이슈 브랜치 기반 새 워크트리)

---

### Phase 6: VERIFY → CLOSE

전체 머지 완료 후 통합 검증을 수행한다.

1. **통합 테스트** — 이슈 브랜치에서 프로젝트 테스트 실행
2. **검증 실패 시** → 워크트리 보존 상태이므로 디버깅/롤백 가능
3. **검증 통과 후**:
   - 워크트리 정리 (`git worktree remove`)
   - MASTER 문서 status: `done`
   - 완료 이슈를 `.hxsk/issues/archive/`로 이동
   - **마스터 머지는 사용자 확인 후 진행**

---

## Crash Recovery Protocol

오케스트레이터가 중단된 경우 재개 절차:

1. `.hxsk/issues/MASTER-*.md`에서 status: `in-progress`인 문서 검색
2. 해당 MASTER의 WORK 문서들 status 확인
3. status: `in-progress`인 WORK에 대해:
   - `git worktree list`로 워크트리 존재 확인
   - 존재 → `git log --oneline`으로 커밋 확인, 실제 완료 여부 판단
   - 미존재 → status: `failed`로 갱신, 재실행 대상
4. 미완료 Wave부터 Phase 3 루프 재개

---

## Dispatch Rules

1. **Wave 순서 엄수**: Wave N+1은 Wave N 머지 완료 후에만 시작
2. **파일 소유권 검증**: 같은 Wave 내 files + side_effect_files 겹침 금지
3. **Subagent 독립성**: 각 서브에이전트는 자체 워크트리에서 독립 실행
4. **실패 격리**: 하나의 서브에이전트 실패가 다른 서브에이전트에 영향 없음
5. **결과 리뷰**: merge 전 각 서브에이전트 결과를 오케스트레이터가 리뷰
6. **오케스트레이터 단독 쓰기**: 이슈 문서는 오케스트레이터만 생성/업데이트
7. **워크트리 브랜치 네이밍**: `feat/master-{id}/work-{seq}`

## Main Root Resolve

서브에이전트가 워크트리에서 메인 루트를 resolve하는 범용 패턴:

```bash
MAIN_ROOT=$(git worktree list | head -1 | awk '{print $1}')
```

어떤 프로젝트/머신에서든 별도 설정 없이 동작.
