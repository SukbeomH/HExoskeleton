#!/usr/bin/env bash
# generate-claude-md.sh — project-config.yaml 기반 CLAUDE.md 동적 생성
# 언어별 Commands 섹션 + Qlty Quality 섹션 포함
#
# Usage: bash scripts/generate-claude-md.sh [output_path]
# Default output: CLAUDE.md in project root

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
OUTPUT="${1:-$PROJECT_DIR/CLAUDE.md}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# load-config.sh에서 환경변수 로드
source "$SCRIPT_DIR/load-config.sh"

# ── 언어별 Commands 섹션 생성 ──
generate_commands_section() {
    local lang="${PRIMARY_LANGUAGE:-python}"
    local pkg="${PKG_MANAGER_NAME:-uv}"
    local install="${PKG_INSTALL_CMD:-uv sync}"
    local add="${PKG_ADD_CMD:-uv add}"
    local test_cmd="${TEST_RUNNER_CMD:-}"

    cat <<CMDS
## Commands

**Package manager: \`${pkg}\` only. Never use other package managers.**

\`\`\`bash
${install}                              # Install/sync dependencies
${add} <package>                        # Add dependency
CMDS

    if [[ -n "$test_cmd" ]]; then
        echo "${test_cmd}                        # Run tests"
    fi

    echo '```'
}

# ── Qlty Quality 섹션 생성 ──
generate_quality_section() {
    if [[ "${QLTY_ENABLED:-false}" == "true" ]]; then
        cat <<QLTY

## Code Quality

**Qlty CLI를 사용한 코드 품질 관리:**

\`\`\`bash
qlty check                       # Lint (all detected linters)
qlty check --fix                 # Lint with auto-fix
qlty fmt                         # Format changed files
qlty fmt --all                   # Format entire project
\`\`\`

> Qlty 미설치 시 fallback: 언어별 기본 도구 사용 (ruff, eslint 등)
QLTY
    else
        # Python fallback
        cat <<PYQUALITY

## Code Quality

\`\`\`bash
uv run ruff check . [--fix]          # Lint
uv run ruff format .                 # Format
uv run mypy .                        # Type check
\`\`\`
PYQUALITY
    fi
}

# ── Makefile 타겟 섹션 생성 ──
generate_make_section() {
    cat <<MAKE

## Make Targets

\`\`\`bash
make setup                    # Full setup (install → env → index)
make status                   # Tool & environment status
make index                    # code-graph-rag indexing
make lint                     # Run linter
make lint-fix                 # Run linter with auto-fix
make fmt                      # Format code
make test                     # Run tests
make typecheck                # Type check
make clean                    # Cleanup
\`\`\`
MAKE
}

# ── 메인 생성 ──
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
LANG_DISPLAY="${LANGUAGE_NAME:-Python}"
LANG_VERSION="${LANGUAGE_VARIANT:+($LANGUAGE_VARIANT)}"

cat > "$OUTPUT" <<EOF
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

${PROJECT_NAME} — Primary language is ${LANG_DISPLAY} ${LANG_VERSION}.

$(generate_commands_section)

$(generate_quality_section)

$(generate_make_section)

## Architecture

- **code-graph-rag** (MCP): Tree-sitter + SQLite based AST code analysis
- **memory-graph** (MCP): Agent persistent memory
- **HXSK Workflow**: SPEC.md → PLAN.md → EXECUTE → VERIFY

## Code Style

See project configuration files for full linter/formatter settings.

## Validation & Testing

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력

## Agent Boundaries

### Always
- Verify empirically — 명령 실행 결과로 증명
- Atomic commits per task

### Ask First
- Adding external dependencies
- Deleting files outside task scope
- Changing public API signatures

### Never
- Read/print .env or credential files
- Commit hardcoded secrets or API keys
- Skip failing tests to "fix later"
EOF

echo "[generate-claude-md] Generated: $OUTPUT"
