# Project State

## Current Position

**Milestone:** Self-Configure 전환 완료
**Phase:** Complete
**Status:** review pending
**Branch:** feature/self-configure

## Last Action

Self-Configure 전환 Phase 3 완료: 빌드 스크립트 5개 삭제, release-please + CI 워크플로우 삭제, Makefile build 타겟 제거, .gitignore 빌드 출력 항목 제거, 문서 전면 갱신.

## Next Steps

1. T20: End-to-End 검증 실행
2. feature/self-configure → master PR 생성 및 merge
3. 새 작업 정의 시 SPEC.md 작성

## Active Decisions

| Decision | Choice | Made | Affects |
|----------|--------|------|---------|
| GSD 버전 관리 | templates/ + examples/만 추적 | 2026-02-02 | .gitignore |
| Memory 시스템 | 순수 bash + 마크다운 파일 기반 | 2026-02-05 | hooks, .hxsk/memories/ |
| Agent 구조 | Skill(How) + Agent(When/With What) 래핑 | 2026-02-02 | .hxsk/ 전체 |
| 외부 종속성 | 없음 (MCP, Python 환경 제거) | 2026-02-05 | 전체 시스템 |
| 배포 모델 | Self-Configure (레포 = 배포, 빌드 없음) | 2026-03-24 | 전체 시스템 |

## Blockers

None

## Concerns

None

## Session Context

Self-Configure 전환 Phase 1~3 완료. 신규 파일 생성(llms.txt, AGENTS.md, prompts/, CLAUDE.md 분리), 소스 재배치(.claude/ → .hxsk/), 빌드 인프라 삭제, 문서 갱신 완료.

---

*Last updated: 2026-03-24*
