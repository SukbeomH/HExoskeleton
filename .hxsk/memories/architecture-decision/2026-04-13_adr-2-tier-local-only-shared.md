---
title: "ADR: 메모리 2-tier 분리 (local-only / shared)"
tags:
  - architecture-decision
  - memory-system
  - multi-remote
  - gitignore
type: architecture-decision
created: 2026-04-13T00:17:14Z
contextual_description: "메모리 시스템을 local-only와 shared 두 티어로 분리해 멀티 리모트 환경 머지 충돌 해소 + 중요 지식 선택 공유"
keywords:
  - tier-separation
  - local-shared
  - merge-conflict
  - session-summary
  - prune
---

## ADR: 메모리 2-tier 분리 (local-only / shared)

## Decision
`.hxsk/memories/` 를 **local-only** 과 **shared** 두 티어로 분리한다.

- **local-only** (gitignored, 각 환경 독립): session-summary, session-snapshot, session-handoff, health-event, debug-blocked, debug-eliminated, bootstrap, general, deviation
- **shared** (git-tracked): architecture-decision, root-cause, pattern-discovery, security-finding, execution-summary, lessons-learned, _schema

## Context
여러 리모트 개발 환경에서 동시 작업 시 `.hxsk/memories/` 전체가 gitignored인 탓에:
1. 가치 높은 지식(아키텍처 결정 등)도 공유 불가
2. tracked 상태 파일(CURRENT.md, STATE.md, JOURNAL.md, SESSION_HANDOFF.md)은 매 세션 덮어써져 머지 충돌 확정
3. session-summary 누적 문제(150개/600KB) — 절반이 git-diff로 재생성 가능한 내용

## Alternatives Considered
- **호스트별 디렉토리** (`memories/{hostname}/`): 경로 충돌은 막지만 공유/독립을 파일별로 선택 불가
- **모두 공유**: 상태 파일 충돌 폭발, session-summary 리포 비대
- **모두 독립**: 아키텍처 지식 공유 불가

## Consequences
### Positive
- 상태 파일 머지 충돌 0건
- 중요 지식(ADR/패턴/RCA)만 선택적 공유
- local-tier 무제한 리텐션/prune 정책 자유

### Negative
- 티어 분류 판단 필요 — 애매한 타입은 `_schema/`에 정의
- shared-tier 동시 수정 시 여전히 conflict (의미 있는 충돌이라 허용)

## Supporting Infrastructure
- `.gitattributes`: INDEX.md/bootstrap-version에 `merge=ours`
- `bootstrap.sh`: `merge.ours.driver` 자동 등록
- `prune-memories.sh`: 30일 초과 local-tier → `_archive/YYYY-MM/` *(Superseded: PR #132)*
- `stop-context-save.sh`: 지문 기반 중복 저장 스킵

## References
- PR: #123 (merge commit에서 전체 변경 이력 확인)
- Date: 2026-04-13

## Superseded By
- **PR #132 (2026-04-15)**: local-tier 정리 정책 재설계
  - `_archive/` 이동 → **직접 삭제** (git log/PR이 이력 대체)
  - 30일 TTL → **cap 20 (FIFO) + 보조 7일 TTL**
  - Write-gating: 훅 자체 변경만 있는 세션은 session-summary 저장 생략
  - 가치 기반 승격: `tags: [decision|root-cause|incident|security|pattern|lesson]`
    매칭 시 삭제 직전 shared-tier 해당 폴더로 자동 이동
