# Use bash for all recipes (portable across macOS/Linux/CI)
SHELL := $(shell command -v bash)

# Load .env if exists
-include .env
export

.PHONY: status setup install-deps init-env check-deps clean \
        build build-plugin build-antigravity build-opencode help

# ─────────────────────────────────────────────────────
# Prerequisites Check
# ─────────────────────────────────────────────────────

check-deps: ## Check required tools are installed
	@bash scripts/bootstrap.sh

# ─────────────────────────────────────────────────────
# Installation
# ─────────────────────────────────────────────────────

install-qlty: ## Install Qlty CLI for code quality
	@command -v qlty >/dev/null 2>&1 && echo "qlty already installed: $$(qlty --version 2>/dev/null)" || \
		{ echo "Installing qlty..."; curl -fsSL https://qlty.sh | sh; }

install-deps: check-deps install-qlty ## Install all external dependencies
	@echo ""
	@echo "All dependencies installed."

# ─────────────────────────────────────────────────────
# Environment Setup
# ─────────────────────────────────────────────────────

init-env: ## Create .env from .env.example (if not exists)
	@if [ -f .env ]; then \
		echo ".env already exists. Skipping."; \
	else \
		cp .env.example .env; \
		echo ".env created."; \
	fi

# ─────────────────────────────────────────────────────
# Status
# ─────────────────────────────────────────────────────

status: ## Show tool status
	@echo "=== Environment ==="
	@test -f .env && echo "  .env: exists" || echo "  .env: MISSING (run: make init-env)"
	@echo ""
	@echo "=== Memory ==="
	@test -d .hxsk/memories && echo "  .hxsk/memories/: exists ($$(ls .hxsk/memories/ | wc -l | tr -d ' ') type dirs)" || echo "  .hxsk/memories/: MISSING"

# ─────────────────────────────────────────────────────
# Full Setup
# ─────────────────────────────────────────────────────

setup: ## Full initial setup (install deps → env)
	@echo "========================================="
	@echo "  Boilerplate Full Setup"
	@echo "========================================="
	@$(MAKE) --no-print-directory install-deps
	@$(MAKE) --no-print-directory init-env
	@echo ""
	@echo "========================================="
	@echo "  Setup Complete!"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: /bootstrap to initialize HXSK workflow"

# ─────────────────────────────────────────────────────
# Build Targets
# ─────────────────────────────────────────────────────

build: build-plugin build-antigravity build-opencode ## Build all targets
	@echo ""
	@echo "========================================="
	@echo "  All builds complete!"
	@echo "========================================="
	@echo "  - hxsk-plugin/             (Claude Code)"
	@echo "  - antigravity-boilerplate/ (Antigravity IDE)"
	@echo "  - opencode-boilerplate/    (OpenCode)"

build-plugin: ## Build Claude Code plugin (hxsk-plugin/)
	@bash scripts/build-plugin.sh

build-antigravity: ## Build Antigravity workspace (antigravity-boilerplate/)
	@bash scripts/build-antigravity.sh

build-opencode: ## Build OpenCode workspace (opencode-boilerplate/)
	@bash scripts/build-opencode.sh

# ─────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf hxsk-plugin/ antigravity-boilerplate/ opencode-boilerplate/

# ─────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
