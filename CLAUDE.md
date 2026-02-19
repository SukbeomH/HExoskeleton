# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. 네이티브 Claude Code 도구(Grep, Glob, Read)와 파일 기반 메모리 시스템(`.gsd/memories/`)을 활용하며 GSD(Get Shit Done) 문서 기반 방법론을 결합.

**외부 종속성 없음**: 순수 bash 스크립트 + 마크다운 파일 기반. Documentation is bilingual (Korean/English).

## Repository Layout

- **.claude/** — Single source of truth for agent configuration:
  - `agents/` — Agent definitions (14 agents, skill 래핑 구조)
  - `skills/` — Modular skill definitions (16 skills)
  - `hooks/` — Event hooks and utility scripts
  - `settings.json` — Claude Code project settings
- **.github/agents/** — GitHub Agent specification
- **.gsd/** — GSD documents and context management:
  - `SPEC.md`, `PLAN.md`, `DECISIONS.md`, `STATE.md` — Core working docs
  - `PATTERNS.md` — Distilled learnings for fresh sessions (2KB limit)
  - `memories/` — File-based agent memory (14 type directories)
  - `reports/` — Analysis reports (REPORT-*.md)
  - `research/` — Research documents (RESEARCH-*.md)
  - `archive/` — Monthly archives (journal, changelog, prd)
  - `templates/` — Document templates
- **.gemini/** — Gemini agent config (CLAUDE.md 참조로 축소)
- **scripts/** — Utility scripts

### Agent-Skill 래핑 구조

Skill은 "어떻게(How)"를 정의하고, Agent는 "언제/무엇과 함께(When/With What)"를 정의한다.

- **Skill** (`.claude/skills/{name}/SKILL.md`): 재사용 가능한 최소 모듈. 실행 절차와 규칙을 상세히 기술.
- **Agent** (`.claude/agents/{name}.md`): Skill을 탑재하고 오케스트레이션 흐름을 정의. model/tools 메타데이터 포함.

## Commands

```bash
make setup                    # Full setup (install → env)
make status                   # Tool & environment status
make check-deps               # Verify prerequisites
make clean                    # Patch workspace cleanup
make patch-prompt             # System prompt patching (토큰 절감)
make patch-restore            # Patch 원복
make patch-clean              # Patch workspace 삭제
```

## Architecture

**외부 종속성 없음**: 순수 bash 스크립트 + 네이티브 Claude Code 도구만 사용. MCP 서버, 외부 API 호출 불필요.

- **코드 분석**: 네이티브 Claude Code 도구(Grep, Glob, Read)
- **에이전트 메모리**: `.gsd/memories/{type}/` 마크다운 파일 기반. 14개 타입 디렉토리 + `_schema/` 스키마 디렉토리
- **메모리 도구**: `.claude/hooks/md-store-memory.sh` (저장, A-Mem 확장), `.claude/hooks/md-recall-memory.sh` (검색, 2-hop)
- **GSD Workflow**: SPEC.md → PLAN.md → EXECUTE → VERIFY. Working docs in `.gsd/`

## Memory Protocol

파일 기반 메모리 시스템 (A-Mem 확장). 상세는 `.claude/skills/memory-protocol/SKILL.md` 참조.

### Session Start
- `Grep(pattern: "{project context}", path: ".gsd/memories/")` 또는 `md-recall-memory.sh` 실행
- 결과가 부족할 때 `Glob(pattern: ".gsd/memories/{type}/*.md")`로 타입별 탐색

### Search Protocol
| 방식 | 용도 | 순서 |
|------|------|------|
| `md-recall-memory.sh <query> [path] [limit] [mode] [hop]` | 훅 기반 검색 (2-hop 지원) | **권장** |
| `Grep(path: ".gsd/memories/")` | Broad context (세션/태스크 시작) | **1st** |
| `Glob(pattern: ".gsd/memories/{type}/*.md")` | Narrow filter (타입 특정) | **2nd** |

### Storage (A-Mem 확장)
```bash
md-store-memory.sh <title> <content> [tags] [type] [keywords] [contextual_desc] [related]
```
- **중복 방지**: 동일 title 저장 시 `[SKIP:DUPLICATE]` 반환
- **2-hop 검색**: `related` 필드로 연결된 메모리 자동 추적

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

### Memory File Format (A-Mem 확장)
`.gsd/memories/{type}/{YYYY-MM-DD}_{slug}.md`:
```markdown
---
title: "{title}"
tags: [tag1, tag2]
type: {type}
created: {ISO-8601}
contextual_description: "{1줄 요약}"
keywords: [keyword1, keyword2]
related: [related_file_slug]
---
## {title}
{content}
```

### Schema Validation
`.gsd/memories/_schema/`에서 타입별 JSON Schema와 관계 정의:
- `base.schema.json`: 공통 필드 스키마
- `type-relations.yaml`: 14개 타입 간 관계 (Ontology)

## Validation

검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고 (첫 번째에서 멈추지 않음)
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력
- **3회 연속 실패 시**: 접근 방식 변경 — 웹 검색, 공식 문서, 또는 fresh session

## Agent Boundaries

### Always
- Grep/Glob 기반 impact analysis before refactoring or deleting code
- Read `.gsd/SPEC.md` before implementation
- Verify empirically — 명령 실행 결과로 증명
- Atomic commits per task
- **WebFetch는 순차적으로 실행할 것 (병렬 fetch 금지)** — 병렬 호출 시 "Sibling tool call errored" 발생

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
- Use `--dangerously-skip-permissions` outside containers
