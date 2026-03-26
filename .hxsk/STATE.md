# Project State

## Current Position

**Milestone:** .hxsk/ 경로 통합 + Setup v2 완료
**Phase:** Complete
**Status:** idle
**Branch:** master

## Last Action

.hxsk/ 경로 통합 완료. scripts/, docs/, prompts/를 .hxsk/ 하위로 이동 (#83).
Setup v2 멱등 수렴 엔진 (#78), Dispatcher v2 (#75), 메모리 정리 자동화 (#80),
docs 현행화 (#80), README 디자인 개선 (#81), CI 릴리즈 자동화 (#85).
가상 프로젝트 E2E 전체 통과.

## Next Steps

1. 다른 프로젝트에 실제 적용 테스트
2. 새 작업 정의 시 SPEC.md 작성

## Active Decisions

| Decision | Choice | Made | Affects |
|----------|--------|------|---------|
| GSD 버전 관리 | templates/ + examples/만 추적 | 2026-02-02 | .gitignore |
| Memory 시스템 | 순수 bash + 마크다운 파일 기반 | 2026-02-05 | hooks, .hxsk/memories/ |
| Agent 구조 | Skill(How) + Agent(When/With What) 래핑 | 2026-02-02 | .hxsk/ 전체 |
| 외부 종속성 | 없음 (MCP, Python 환경 제거) | 2026-02-05 | 전체 시스템 |
| 배포 모델 | Self-Configure (레포 = 배포, 빌드 없음) | 2026-03-24 | 전체 시스템 |
| 디렉토리 구조 | scripts/, docs/, prompts/ → .hxsk/ 하위 | 2026-03-26 | 전체 시스템 |
| Dispatcher v2 | MASTER/WORK 이슈 트래킹 + 6-Phase Wave 루프 | 2026-03-26 | .hxsk/skills/dispatcher |
| Setup v2 | 멱등 수렴 엔진 (fresh/verify/update) + 2-hop | 2026-03-26 | .hxsk/scripts/bootstrap.sh |
| 에이전트 프롬프트 컨벤션 | 간결 유지 (~20-30줄), 상세는 SKILL.md 위임 | 2026-03-26 | .hxsk/agents/ 전체 |
| 이슈 문서 | .hxsk/issues/ (git-untracked, 오케스트레이터 단독 쓰기) | 2026-03-26 | dispatcher |
| 메모리 정리 | session-summary 30d/30개, snapshot 14d, execution-summary 60d | 2026-03-26 | .hxsk/scripts/memory-cleanup.sh |
| 릴리즈 | setup 프롬프트 자동 릴리즈 (setup-vX.X.X) | 2026-03-26 | .github/workflows/ |

## Blockers

None

## Recent Commits
67cf7c2 ci: master 머지 시 setup 프롬프트 자동 릴리즈 + 복사 가능 body (#85)
a0f9d6e fix: E2E 잔여 정리 — 설계 문서 이동 + llms.txt 재생성 (#84)
3f5ce8e refactor: scripts/, docs/, prompts/를 .hxsk/ 하위로 이동 (#83)

---

*Last updated: 2026-03-26*
