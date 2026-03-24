---
name: dispatcher
description: "Wave 기반 병렬 이슈 디스패치 — 이슈 → worktree subagent 배정"
version: 1.0.0
trigger: "dispatch|병렬 실행|wave 실행|이슈 배정"
allowed-tools:
  - Agent
  - Read
  - Bash
  - Glob
  - Grep
---

## Quick Reference
- **입력**: PLAN.md (wave 구조) 또는 .hxsk/issues/*.md (이슈 목록)
- **출력**: wave별 subagent 병렬 실행 → 결과 수집 → merge
- **규칙**: 같은 wave 내 파일 소유권 겹침 없음 검증 필수
- **Merge**: `scripts/merge-worktrees.sh` 사용
- **Fallback**: 충돌 시 이슈 에스컬레이션

# Dispatcher Skill

<role>
You are a wave-based parallel dispatch orchestrator.
You take a set of issues or plans grouped into dependency waves
and dispatch each wave's items as isolated subagents in parallel worktrees.
</role>

## Dispatch Protocol

### Phase 1: Load & Validate

1. 이슈 목록 로드 (L0: frontmatter만)
   ```bash
   bash scripts/issue-list.sh open
   ```

2. Wave 할당 검증
   - 같은 wave 내 이슈의 `files` 필드 교차 확인
   - 겹치면 → 후속 wave로 이동 또는 분할

### Phase 2: Wave 실행

각 wave를 순차적으로 처리하되, wave 내 이슈는 병렬 dispatch:

```
for wave in 1, 2, 3...:
    for issue in wave:
        Agent(
            prompt: "이슈 #{id} 실행: {title}\n\n{issue 본문}",
            isolation: "worktree",
            subagent_type: "general-purpose",
            run_in_background: true
        )
    모든 subagent 완료 대기
    결과 수집 및 리뷰
```

### Phase 3: Merge

각 subagent worktree 결과를 순차 merge:

```bash
bash scripts/merge-worktrees.sh <worktree-path> <branch-name>
```

충돌 발생 시:
1. 자동 해소 시도 (git merge --no-edit)
2. 실패 시 이슈 상태를 `blocked`로 변경
3. 사용자에게 에스컬레이션

### Phase 4: Verify

모든 merge 후 통합 검증:
- `make build` 성공 확인
- 변경된 파일의 영향 분석

## Dispatch Rules

1. **Wave 순서 엄수**: Wave N+1은 Wave N 완료 후에만 시작
2. **파일 소유권 검증**: 같은 wave 내 이슈가 동일 파일 수정 금지
3. **Subagent 독립성**: 각 subagent는 자체 worktree에서 독립 실행
4. **실패 격리**: 하나의 subagent 실패가 다른 subagent에 영향 없음
5. **결과 리뷰**: merge 전 각 subagent 결과를 메인 에이전트가 리뷰

## Issue Lazy Loading

- **L0** (디스패치 시): frontmatter만 — id, title, type, priority, wave, files
- **L1** (subagent에 전달): 본문 전체 — 설명, acceptance criteria
- **L2** (subagent 자체 로드): 관련 SKILL.md, PLAN.md
