# MASTER Issue Template

> Copy this template when creating master plan issues.

```markdown
---
id: MASTER-{id}
title: "{마스터플랜 제목}"
branch: feat/master-{id}
status: draft
works: []
wave_plan:
  wave-1: []
created: {YYYY-MM-DD}
---

## Objective
{PLAN.md 또는 SPEC.md에서 도출된 목표}

## Progress
- [ ] Wave 1 (0/0)

## Merge Log
<!-- 각 Work 머지 결과: 날짜, WORK ID, 커밋 해시, 성공/실패 -->

## Notes
<!-- 충돌 해결, 의사결정, 크래시 복구 등 -->
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | `MASTER-{3자리 숫자}` 형식 |
| `title` | Yes | 마스터플랜 제목 |
| `branch` | Yes | 이슈 브랜치명 (`feat/master-{id}`) |
| `status` | Yes | `draft` \| `in-progress` \| `review` \| `done` |
| `works` | Yes | 소속 WORK ID 배열 |
| `wave_plan` | Yes | Wave별 WORK 배정 맵 |
| `created` | Yes | 생성일 (YYYY-MM-DD) |

## Status Lifecycle

`draft` → `in-progress` (Phase 3 시작) → `review` (Phase 6 검증) → `done` (검증 통과)
