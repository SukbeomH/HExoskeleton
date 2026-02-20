# Use bash for all recipes (portable across macOS/Linux/CI)
SHELL := $(shell command -v bash)

# Load .env if exists
-include .env
export

.PHONY: status setup install-deps init-env check-deps clean \
        patch-prompt patch-restore patch-clean \
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
	@test -d .gsd/memories && echo "  .gsd/memories/: exists ($$(ls .gsd/memories/ | wc -l | tr -d ' ') type dirs)" || echo "  .gsd/memories/: MISSING"

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
	@echo "  1. Run: /new-project to start a GSD workflow"

# ─────────────────────────────────────────────────────
# System Prompt Patching
# ─────────────────────────────────────────────────────

CLAUDE_CODE_VERSION ?= $(shell claude --version 2>/dev/null | awk '{print $$1}')
PATCH_DIR ?= claude-code-tips/system-prompt

patch-prompt: ## Patch Claude Code system prompt (reduces token usage ~50%)
	@echo "=== System Prompt Patcher ==="
	@command -v node >/dev/null 2>&1 || { echo "[MISSING] node — install Node.js"; exit 1; }
	@echo "Claude Code version: $(CLAUDE_CODE_VERSION)"
	@test -d "$(PATCH_DIR)/$(CLAUDE_CODE_VERSION)" || { echo "[ERROR] No patches for v$(CLAUDE_CODE_VERSION) in $(PATCH_DIR)/"; echo "See: .gsd/GUIDE-system-prompt-patch.md > Version Upgrade"; exit 1; }
	@mkdir -p .patch-workspace
	npm install --prefix .patch-workspace @anthropic-ai/claude-code@$(CLAUDE_CODE_VERSION) --silent
	@cp .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js /tmp/_claude_cli.js
	@cp .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js /tmp/_claude_cli.js.backup
	@node "$(PATCH_DIR)/$(CLAUDE_CODE_VERSION)/patch-cli.js" /tmp/_claude_cli.js
	@cp /tmp/_claude_cli.js .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js
	@cp /tmp/_claude_cli.js.backup .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js.backup
	@rm -f /tmp/_claude_cli.js /tmp/_claude_cli.js.backup
	@echo ""
	@echo "Patched! Run with:"
	@echo "  DISABLE_AUTOUPDATER=1 npx --prefix .patch-workspace claude"

patch-restore: ## Restore original Claude Code CLI (undo patch)
	@test -f .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js.backup || { echo "[ERROR] No backup found. Nothing to restore."; exit 1; }
	@cp .patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js.backup \
		.patch-workspace/node_modules/@anthropic-ai/claude-code/cli.js
	@echo "Restored original cli.js from backup."

patch-clean: ## Remove patched Claude Code workspace
	rm -rf .patch-workspace/
	@echo "Removed .patch-workspace/"

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

clean: ## Remove index data and patch workspace
	rm -rf .code-graph-rag/ .patch-workspace/

# ─────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
