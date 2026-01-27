# Load .env if exists (exports CODEGRAPH_SURREALDB_* vars for codegraph CLI)
-include .env
export

.PHONY: up down logs status init-db index setup lint test typecheck validate clean

# ─────────────────────────────────────────────────────
# Infrastructure
# ─────────────────────────────────────────────────────

up: ## Start SurrealDB container
	docker compose up -d

down: ## Stop SurrealDB container
	docker compose down

logs: ## Show SurrealDB logs
	docker compose logs -f surrealdb

status: ## Show container and health status
	docker compose ps

init-db: ## Create SurrealDB namespace and database
	@echo "Creating namespace 'ouroboros' and database 'codegraph'..."
	@curl -sf -X POST http://localhost:3004/sql \
		-H "Content-Type: application/surql" \
		-H "Accept: application/json" \
		-u root:root \
		-d "DEFINE NAMESPACE IF NOT EXISTS ouroboros; USE NS ouroboros; DEFINE DATABASE IF NOT EXISTS codegraph;" \
		> /dev/null && echo "Done." || echo "Failed. Is SurrealDB running? (make up)"

# ─────────────────────────────────────────────────────
# CodeGraph
# ─────────────────────────────────────────────────────

index: ## Index codebase with CodeGraph
	codegraph index . -r -l python,typescript,rust

# ─────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────

lint: ## Run ruff linter
	uv run ruff check .

lint-fix: ## Run ruff with auto-fix
	uv run ruff check --fix .

test: ## Run pytest
	uv run pytest tests/

typecheck: ## Run mypy type checker
	uv run mypy .

validate: ## Validate SPEC.md project structure
	python scripts/validate_spec.py

# ─────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────

setup: up ## Full initial setup: SurrealDB + namespace + CodeGraph index
	@echo "Waiting for SurrealDB to be healthy..."
	@timeout=30; while [ $$timeout -gt 0 ]; do \
		if docker compose ps | grep -q "(healthy)"; then break; fi; \
		sleep 1; timeout=$$((timeout - 1)); \
	done
	@$(MAKE) init-db
	@$(MAKE) index
	@echo "Setup complete."

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

clean: ## Remove Docker volumes and CodeGraph index
	docker compose down -v
	rm -rf .codegraph/

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
