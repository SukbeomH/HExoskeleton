# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OmniGraph Framework v1.2 — a hierarchical hybrid RAG system connecting local (CodeGraph AST) and global (Neo4j) knowledge graphs. Uses LangChain/LangGraph for orchestration, MCP Protocol for tool integration, and follows the GSD (Get Shit Done) document-driven methodology.

Primary language is Python 3.11+. Documentation is bilingual (Korean/English).

## Repository Layout

- **platform-core/** — Global Hub: LangGraph agent orchestration, Neo4j graph DB, FastAPI server
- **project-template/** — Local Spoke: developer boilerplate with agent specs, skills, GSD docs
- **mcp/** — Dockerized MCP servers (Serena, Codanna, Context7, Shrimp)
- **shared-libs/** — Common utilities (URN manager)
- **.gsd/** — Root-level GSD state (STATE.md, ROADMAP.md, DECISIONS.md, TODO.md)

## Build & Development Commands

**Package manager is `uv` — never use pip or poetry directly.**

```bash
# All commands run from platform-core/
cd platform-core

uv sync                              # Install/sync dependencies
uv add <package>                     # Add dependency
uv add <package> --dev               # Add dev dependency

uv run pytest tests/                 # Run all tests
uv run pytest tests/test_e2e.py -v   # Run single test file
uv run pytest tests/ -k "test_name"  # Run specific test

uv run ruff check .                  # Lint
uv run ruff check --fix .            # Lint with auto-fix
uv run mypy .                        # Type check
```

### Infrastructure

```bash
# Neo4j + NeoDash (from platform-core/)
docker-compose up -d

# MCP servers (from mcp/)
docker-compose -f docker-compose.mcp.yml up -d

# API server
python -m uvicorn api.app:app --reload --port 8000

# LangGraph agent
python -m orchestration.graph_v2
```

### CodeGraph Rust (external tool)

```bash
codegraph index . -r -l python,typescript,rust   # Index codebase
codegraph start stdio --watch                     # Start MCP server (stdio)
codegraph index . -r --force                      # Force re-index
```

## Architecture

### Hybrid RAG: Local Spoke + Global Hub

The system uses a **Fast/Slow thinking** model:
- **Fast (Local)**: CodeGraph AST indexing for immediate code-level context
- **Slow (Global)**: Neo4j knowledge graph for cross-project deep reasoning

All entities are identified via URNs:
- Local: `urn:local:{project_id}:{file_path}:{symbol}`
- Global: `urn:global:lib:{package_name}@{version}`

### LangGraph Orchestration (platform-core/orchestration/)

The agent uses a LangGraph `StateGraph` with `Command` pattern routing (not conditional edges):

1. `IntentClassifier` — determines local vs global retrieval need
2. `LocalRetriever` / `GlobalRetriever` — fetches context from CodeGraph or Neo4j
3. `Pruner` — filters low-relevance results before synthesis
4. `Synthesizer` — combines retrieved context into final answer

State is defined as `AgentState(TypedDict)` in `state.py`. MCP tools are loaded via `langchain-mcp-adapters` `MultiServerMCPClient` in `mcp_client.py`.

### MCP Integration

Uses `langchain-mcp-adapters` (not custom wrappers) for MCP tool integration:
- **CodeGraph** (stdio transport) — local AST analysis
- **Neo4j Cypher** (SSE transport) — global knowledge graph queries
- **Context7, Serena, Codanna, Shrimp** — additional MCP servers via Docker

### GSD Document-Driven Workflow

Tasks follow: `SPEC.md` (requirements) → `PLAN.md` (execution plan with XML tasks) → `DECISIONS.md` (ADRs). GSD state files live in `.gsd/` (root) and `.specs/` (project-template).

## Code Style

- **Ruff**: target Python 3.11, line-length 100, rules: E, F, I, N, W (E501 ignored)
- Use `TypedDict` for LangGraph state definitions
- Use `Command` objects for graph node routing
- Use `langchain-mcp-adapters` for MCP connections

## Agent Boundaries (from agent.md)

- **Always**: Run dependency/impact analysis before refactoring; read `.specs/SPEC.md` before implementation
- **Ask First**: Adding external dependencies, modifying Neo4j schema, writing to Global DB
- **Never**: Read/print `.env` files, commit hardcoded secrets, assume API signatures without verification
