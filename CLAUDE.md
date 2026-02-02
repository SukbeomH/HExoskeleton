# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. code-graph-rag(AST 인덱싱) + memory-graph(에이전트 기억)와 GSD(Get Shit Done) 문서 기반 방법론을 결합.

Primary language is Python 3.12. Documentation is bilingual (Korean/English).

## Repository Layout

- **.agent/** — GSD workflows (29 commands)
- **.claude/skills/** — Modular skill definitions (14 skills)
- **.github/agents/** — GitHub Agent specification
- **.gsd/** — GSD documents and context management:
  - `SPEC.md`, `PLAN.md`, `DECISIONS.md`, `STATE.md` — Core working docs
  - `PATTERNS.md` — Distilled learnings for fresh sessions (2KB limit)
  - `reports/` — Analysis reports (REPORT-*.md)
  - `research/` — Research documents (RESEARCH-*.md)
  - `archive/` — Monthly archives (journal, changelog, prd)
  - `templates/` — Document templates
- **.mcp.json** — MCP server config (graph-code, memory, context7)
- **scripts/** — Utility scripts

## Commands

**Package manager: `uv` only. Never use pip or poetry.**

```bash
uv sync                              # Install/sync dependencies
uv add <package> [--dev]             # Add dependency
uv run pytest tests/ [-k "name"]     # Run tests
uv run ruff check . [--fix]          # Lint
uv run mypy .                        # Type check
```

```bash
make setup                    # Full setup (install → env → index)
make status                   # Tool & environment status
make index                    # code-graph-rag indexing
make check-deps               # Verify prerequisites
make clean                    # Index data + patch workspace cleanup
make patch-prompt             # System prompt patching (토큰 절감)
make patch-restore            # Patch 원복
make patch-clean              # Patch workspace 삭제
```

## Architecture

- **code-graph-rag** (MCP stdio, `@er77/code-graph-rag-mcp`): Tree-sitter + SQLite 기반 AST 코드 분석 — 19개 MCP 도구 (`query`, `semantic_search`, `analyze_code_impact`, `analyze_hotspots`, `detect_code_clones`, `find_similar_code`, `list_file_entities`, `list_entity_relationships`, `suggest_refactoring`, `cross_language_search`, `find_related_concepts`, `index`, `clean_index`, `get_graph`, `get_graph_stats`, `get_graph_health`, `reset_graph`, `get_metrics`, `get_version`). 코드 탐색 시 파일 직접 읽기보다 우선 사용
- **mcp-memory-service** (MCP stdio, `memory server`): doobidoo/mcp-memory-service 기반 에이전트 기억 저장. 핵심 도구 — `memory_store`, `memory_search`, `memory_update`, `memory_delete`, `memory_stats`, `memory_list`, `memory_graph`, `memory_quality`. 권한: `mcp__memory__*` 와일드카드 사용
- **MCP Config**: `.mcp.json` — 도구 상세는 `.github/agents/agent.md` Section 4-5 참조
- **Memory Isolation**: 프로젝트별 DB 파일 경로로 격리 (`MCP_MEMORY_SQLITE_PATH`). multi-tenant 미사용 (단일 사용자)
- **GSD Workflow**: SPEC.md → PLAN.md → EXECUTE → VERIFY. Working docs in `.gsd/`

## Memory Protocol

mcp-memory-service 사용 시 아래 규칙을 따른다. 상세는 `.claude/skills/memory-protocol/SKILL.md` 참조.

### Session Start
- `memory_search(query: "{project context}", mode: "semantic")` 필수 실행
- semantic 결과가 부족할 때만 tag 필터로 보충

### Search Protocol
| 방식 | 용도 | 순서 |
|------|------|------|
| `memory_search(mode: "semantic")` | Broad context (세션/태스크 시작) | **1st** |
| `memory_search(tags: [...])` | Narrow filter (태그/타입 특정) | **2nd** |

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

### Required Fields (memory_store)
- `content`: `## {title}\n\n{상세 내용}` (title을 markdown 헤더로 포함)
- `metadata.tags`: 콤마 구분 태그 문자열 (최소 2개)
- `metadata.type`: Type Registry에서 선택

## Code Style

See `pyproject.toml` for full Ruff/Mypy configuration. Key constraints:
- Line-length 100, max-complexity 10, max-args 6
- Use `TypedDict` for state definitions
- `*Factory`, `Create*` patterns exempt from naming rules

## Validation & Testing

검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.

- **결과 우선**: 기능 동작 확인 후 스타일 수정. 기능이 깨지면 실패
- **실패 전수 보고**: 모든 실패를 수집하여 보고 (첫 번째에서 멈추지 않음)
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력. 무조건적 "All tests passed!" 금지
- **3회 연속 실패 시**: 접근 방식 변경 — 웹 검색, 공식 문서, 또는 fresh session
- **mock 최소화**: 외부 API/네트워크만 mock. 실제 객체 우선
- **새 기능 = 새 테스트**: 버그 수정 시 회귀 테스트 추가

## Agent Boundaries

### Always
- `analyze_code_impact` for impact analysis before refactoring or deleting code
- Read `.gsd/SPEC.md` before implementation
- Verify empirically — 명령 실행 결과로 증명
- Atomic commits per task

### Ask First
- Adding external dependencies (`uv add`)
- Deleting files outside task scope
- Changing public API signatures or database schema
- Architectural decisions affecting 3+ modules

### Never
- Read/print `.env` or credential files
- Commit hardcoded secrets or API keys
- Assume API signatures without verification
- Skip failing tests to "fix later"
- Print unconditional success messages without verification
- Use `--dangerously-skip-permissions` outside containers
