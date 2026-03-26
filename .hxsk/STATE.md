# Project State

## Current Position

**Milestone:** Dispatcher v2 + 안정화
**Phase:** Testing
**Status:** active
**Branch:** master

## Last Action

Dispatcher v2 구현 완료 (#75). MASTER/WORK 마크다운 이슈 트래킹, 6-Phase Wave 루프 오케스트레이션, arch-review 설계 문서 검토 단계 추가, 에이전트 간결 프롬프트 컨벤션 근거 README 명시.

## Next Steps

1. Dispatcher v2 실전 테스트 (MASTER → WORK 분할 → 워크트리 병렬 실행 → 머지 full cycle)
2. 실전 테스트 피드백 반영
3. 새 작업 정의 시 SPEC.md 작성

## Active Decisions

| Decision | Choice | Made | Affects |
|----------|--------|------|---------|
| GSD 버전 관리 | templates/ + examples/만 추적 | 2026-02-02 | .gitignore |
| Memory 시스템 | 순수 bash + 마크다운 파일 기반 | 2026-02-05 | hooks, .hxsk/memories/ |
| Agent 구조 | Skill(How) + Agent(When/With What) 래핑 | 2026-02-02 | .hxsk/ 전체 |
| 외부 종속성 | 없음 (MCP, Python 환경 제거) | 2026-02-05 | 전체 시스템 |
| 배포 모델 | Self-Configure (레포 = 배포, 빌드 없음) | 2026-03-24 | 전체 시스템 |
| Dispatcher v2 | MASTER/WORK 이슈 트래킹 + 6-Phase Wave 루프 | 2026-03-26 | .hxsk/skills/dispatcher, .hxsk/agents/dispatcher, scripts/issue-*.sh |
| 에이전트 프롬프트 컨벤션 | 간결 유지 (~20-30줄), 상세는 SKILL.md 위임 | 2026-03-26 | .hxsk/agents/ 전체 |
| 이슈 문서 쓰기 주체 | 오케스트레이터 단독 (서브에이전트 읽기 전용) | 2026-03-26 | dispatcher 워크플로우 |
| 이슈 문서 저장 | .hxsk/issues/ (git-untracked, 절대경로 참조) | 2026-03-26 | .gitignore, dispatcher |

## Blockers

None

## Concerns

None

## Recent Commits
eb3cb4f feat(dispatcher): v2 — MASTER/WORK 마크다운 이슈 트래킹 기반 6-Phase 오케스트레이션 (#75)
50b60cc feat: setup 프롬프트에 'assisted with HExoskeleton' 뱃지 안내 추가 (#74)
263e21a docs: README 가독성 개선 + setup 프롬프트에 다음 단계 안내 추가 (#73)

---

*Last updated: 2026-03-26*
