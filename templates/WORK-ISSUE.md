# WORK Issue Template

> Copy this template when creating work unit issues.

```markdown
---
id: WORK-{master-id}-{seq}
master: MASTER-{master-id}
title: "{Work 단위 제목}"
status: pending
wave: {N}
depends_on: []
files: []
side_effect_files: []
worktree: ""
worktree_branch: ""
---

## Tasks
1. [ ] {순차 실행할 Task 1}
2. [ ] {순차 실행할 Task 2}
3. [ ] {순차 실행할 Task 3}

## Result
<!-- 완료 후 오케스트레이터가 기록: 커밋 해시, 변경 요약 -->

## Failure Log
<!-- 실패 시 오케스트레이터가 기록: 사유, 시도 횟수, 3-Strike 상태 -->
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | `WORK-{master-id}-{seq}` 형식 |
| `master` | Yes | 소속 MASTER ID |
| `title` | Yes | Work 단위 제목 |
| `status` | Yes | `pending` \| `in-progress` \| `done` \| `failed` |
| `wave` | Yes | 배정된 Wave 번호 |
| `depends_on` | Yes | 선행 WORK ID 배열 (같은 MASTER 내만) |
| `files` | Yes | 수정 대상 파일 경로 배열 |
| `side_effect_files` | No | 자동 생성 가능 파일 (lock, barrel export 등) |
| `worktree` | No | 실행 시 워크트리 경로 (오케스트레이터 기록) |
| `worktree_branch` | No | 워크트리 브랜치명 (오케스트레이터 기록) |

## Status Lifecycle

`pending` → `in-progress` (Phase 3 dispatch) → `done` (성공) / `failed` (실패)

## Wave Assignment Rules

- `depends_on`이 비어있으면 → Wave 1
- 복수 의존성: `max(선행 Work들의 Wave) + 1`
- 순환 의존성 감지 시 → 에러
