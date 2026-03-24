# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. 네이티브 Claude Code 도구(Grep, Glob, Read)와 파일 기반 메모리 시스템(`.hxsk/memories/`)을 활용하며 HXSK(Get Shit Done) 문서 기반 방법론을 결합.

**외부 종속성 없음**: 순수 bash 스크립트 + 마크다운 파일 기반. Documentation is bilingual (Korean/English).

## Repository Layout

- **.claude/** — Agent/Skill/Hook 설정 (single source of truth)
- **.hxsk/** — Working docs (`SPEC/PLAN/DECISIONS/STATE.md`), `memories/`, `reports/`, `research/`
- **scripts/** — Utility scripts (md-store-memory.sh, md-recall-memory.sh 등)
- **docs/** — 프로젝트 문서 (빌드, 훅, 스킬, 워크플로우, 컨벤션 가이드)

### Agent-Skill 래핑 구조
- **Skill** (`.claude/skills/{name}/SKILL.md`): "어떻게(How)" — 재사용 가능한 실행 절차
- **Agent** (`.claude/agents/{name}.md`): "언제/무엇과(When/With What)" — Skill 탑재 + 오케스트레이션

## Commands

```bash
make setup                    # Full setup (install → env)
make status                   # Tool & environment status
make check-deps               # Verify prerequisites
make clean                    # Build artifacts cleanup
make build                    # Build all targets (plugin, antigravity, opencode)
```

## Architecture

**외부 종속성 없음**: 순수 bash 스크립트 + 네이티브 Claude Code 도구만 사용. MCP 서버, 외부 API 호출 불필요.

- **코드 분석**: 네이티브 Claude Code 도구(Grep, Glob, Read)
- **에이전트 메모리**: `.hxsk/memories/{type}/` 마크다운 파일 기반. 14개 타입 디렉토리 + `_schema/` 스키마 디렉토리
- **메모리 도구**: `scripts/md-store-memory.sh` (저장, A-Mem 확장), `scripts/md-recall-memory.sh` (검색, 2-hop)
- **HXSK Workflow**: SPEC.md → PLAN.md → EXECUTE → VERIFY. Working docs in `.hxsk/`

## Memory Protocol

파일 기반 메모리 시스템 (A-Mem 확장). 상세는 `.claude/skills/memory-protocol/SKILL.md` 참조.

### Search (우선순위)
| 방식 | 용도 | 순서 |
|------|------|------|
| `md-recall-memory.sh <query>` | 훅 기반 검색 (2-hop 지원) | **권장** |
| `Grep(path: ".hxsk/memories/")` | Broad context (세션/태스크 시작) | **1st** |
| `Glob(pattern: ".hxsk/memories/{type}/*.md")` | Narrow filter (타입 특정) | **2nd** |

### Storage Triggers
| Trigger | Type |
|---------|------|
| Architecture decision | `architecture-decision` |
| Bug root cause | `root-cause` |
| Pattern discovered | `pattern-discovery` |
| Hypothesis eliminated | `debug-eliminated` |
| Plan deviation | `deviation` |
| Execution summary | `execution-summary` |
| Session end (auto) | `session-summary` |
| Session handoff (manual) | `session-handoff` |

저장 명령어, 파일 포맷, 스키마 상세는 `.claude/skills/memory-protocol/SKILL.md` 참조.

## Validation

검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고 (첫 번째에서 멈추지 않음)
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력

## Execution Constraints

- **3-Strike Rule**: 동일 접근 3회 연속 실패 시 반드시 전환 — 웹 검색, 공식 문서, 또는 fresh session
- **WebFetch 순차 실행**: 병렬 fetch 금지. 병렬 호출 시 "Sibling tool call errored" 발생
- **Atomic Commit**: 태스크당 하나의 커밋. 논리적 단위 유지
- **Discovery Levels**: L1=CLAUDE.md (요약) → L2=skills/SKILL.md (상세) → L3=.hxsk/research/ (출처/벤치마크)

## Compaction Rules
압축 시 반드시 보존:
- `.hxsk/.track-modifications.log` 변경 파일 목록
- 현재 SPEC.md 목표 및 활성 PLAN.md 태스크
- 이 세션의 메모리 검색 결과와 아키텍처 결정사항

## Prompt Maintenance Rules

CLAUDE.md, SKILL.md, Agent 정의 파일을 수정할 때 아래 규칙을 따른다.

### L1 편집 규칙 (CLAUDE.md)
- **포함**: 검색 순서, 트리거 조건, 제약 조건, "상세는 X 참조" 링크
- **제외**: 명령어 예시, 파일 포맷 블록, 스키마 설명, 구현 세부사항
- **한도**: 단일 프로토콜 섹션 ≤15줄. 전체 파일 ≤120줄
- **검증**: 수정 후 `wc -l CLAUDE.md` 실행하여 한도 초과 확인

### Skill/Agent 편집 규칙
- Quick Reference ≤5줄 (bullet point)
- frontmatter 필드: 기존 파일과 동일한 키 사용
- 새 Skill 추가 시 기존 패턴(planner, arch-review) 참조

## Agent Boundaries

### Always
- Grep/Glob 기반 impact analysis before refactoring or deleting code
- Read `.hxsk/SPEC.md` before implementation
- Verify empirically — 명령 실행 결과로 증명

### Ask First
- Adding external dependencies
- Deleting files outside task scope
- Architectural decisions affecting 3+ modules

### Never
- Read/print `.env` or credential files
- Commit hardcoded secrets or API keys
- Assume API signatures without verification
- Skip failing tests to "fix later"
- Print unconditional success messages without verification
- `--dangerously-skip-permissions` 사용 금지 — 컨테이너 환경 포함 모든 곳에서 위험
