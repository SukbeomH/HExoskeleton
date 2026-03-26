# HExoskeleton (HXSK)

> AI 에이전트 기반 개발 방법론. 순수 bash + 마크다운 기반, 외부 종속성 없음.
> Setup: llms.txt 또는 .hxsk/prompts/setup.md 참조

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. 파일 기반 메모리 시스템(.hxsk/memories/)과 HXSK(Get Shit Done) 문서 기반 방법론을 결합.

**외부 종속성 없음**: 순수 bash 스크립트 + 마크다운 파일 기반.

## Repository Layout

- **.hxsk/** — 스킬, 에이전트 정의, 훅, 템플릿, 메모리, 이슈, working docs
- **.hxsk/prompts/** — 에이전트별 setup 프롬프트
- **.hxsk/scripts/** — 유틸리티 (이슈 관리, 언어 감지, 워크트리 merge)
- **.hxsk/docs/** — 프로젝트 문서, 실행 계획

## HXSK Workflow

SPEC.md → PLAN.md → EXECUTE → VERIFY. Working docs in `.hxsk/`

## Memory Protocol

파일 기반 메모리 시스템 (A-Mem 확장).

### Search (우선순위)
| 방식 | 용도 |
|------|------|
| `bash .hxsk/hooks/md-recall-memory.sh <query>` | 훅 기반 검색 (2-hop 지원) |
| 파일 검색: `.hxsk/memories/` | Broad context |
| 타입별 필터: `.hxsk/memories/{type}/*.md` | Narrow filter |

### Storage Triggers
Architecture decisions, bug root causes, patterns, session ends 등 발생 시 자동 저장. 상세: `.hxsk/skills/memory-protocol/SKILL.md`

## Validation

검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력

## Execution Constraints

- **3-Strike Rule**: 동일 접근 3회 연속 실패 시 반드시 전환
- **Atomic Commit**: 태스크당 하나의 커밋. 논리적 단위 유지

## Agent Boundaries

### Always
- 파일 검색 기반 impact analysis before refactoring or deleting code
- SPEC.md 읽고 구현 시작
- 경험적으로 검증 — 명령 실행 결과로 증명

### Ask First
- Adding external dependencies
- Deleting files outside task scope
- Architectural decisions affecting 3+ modules

### Never
- Read/print .env or credential files
- Commit hardcoded secrets or API keys
- Skip failing tests to "fix later"
