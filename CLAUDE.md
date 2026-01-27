# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. CodeGraph AST 인덱싱과 GSD(Get Shit Done) 문서 기반 방법론을 사용합니다.

Primary language is Python 3.11+. Documentation is bilingual (Korean/English).

## Repository Layout

- **.agent/** — Agent symlinks, GSD workflows (25 commands)
- **.claude/skills/** — Modular skill definitions (SKILL.md per skill)
- **.github/agents/** — GitHub Agent specification (agent.md)
- **.gsd/** — GSD methodology: templates, examples, state documents
- **.specs/** — Project specs (SPEC.md, PLAN.md, DECISIONS.md)
- **mcp/** — Local MCP server configuration (config.json, server.py)
- **scripts/** — Utility scripts (validate_spec.py)

## Build & Development Commands

**Package manager is `uv` — never use pip or poetry directly.**

```bash
uv sync                              # Install/sync dependencies
uv add <package>                     # Add dependency
uv add <package> --dev               # Add dev dependency

uv run pytest tests/                 # Run all tests
uv run pytest tests/ -k "test_name"  # Run specific test

uv run ruff check .                  # Lint
uv run ruff check --fix .            # Lint with auto-fix
uv run mypy .                        # Type check
```

### CodeGraph Rust (external tool)

```bash
codegraph index . -r -l python,typescript,rust   # Index codebase
codegraph start stdio --watch                     # Start MCP server (stdio)
codegraph index . -r --force                      # Force re-index
```

### Spec Validation

```bash
python scripts/validate_spec.py                   # Validate SPEC.md integrity
```

## Infrastructure

```bash
make setup                    # Full setup: SurrealDB + DB init + CodeGraph index
make up                       # SurrealDB 시작
make down                     # SurrealDB 중지
make init-db                  # SurrealDB namespace/database 생성
make status                   # 컨테이너 상태 확인
make logs                     # SurrealDB 로그
make clean                    # Docker volume + CodeGraph 인덱스 삭제
```

## Architecture

### CodeGraph + MCP

The system uses CodeGraph for local AST analysis via MCP Protocol:
- **CodeGraph** (stdio transport): 7 agentic tools for code search, dependency analysis, call chain tracing, architecture review, API surface analysis, context building, and semantic questions
- **MCP Adapter**: `langchain-mcp-adapters` (MultiServerMCPClient)

### URN Schema

All entities are identified via local URNs:
- `urn:local:{project_id}:{file_path}:{symbol}`

### GSD Document-Driven Workflow

Tasks follow: `SPEC.md` (requirements) → `PLAN.md` (execution plan with XML tasks) → `DECISIONS.md` (ADRs). GSD state files live in `.gsd/` and project specs in `.specs/`.

## Code Style

- **Ruff**: target Python 3.11, line-length 100, rules: E, F, I, N, W (E501 ignored)
- Use `TypedDict` for state definitions
- Use `langchain-mcp-adapters` for MCP connections

## Agent Boundaries (from agent.md)

- **Always**: Run dependency/impact analysis before refactoring; read `.specs/SPEC.md` before implementation
- **Ask First**: Adding external dependencies, deleting files outside your task scope
- **Never**: Read/print `.env` files, commit hardcoded secrets, assume API signatures without verification
