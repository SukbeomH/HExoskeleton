#!/usr/bin/env bash
# detect-language.sh — 언어/패키지 관리자/테스트 러너 감지
# source하여 함수 사용

# detect_language [project_dir]
# qlty.toml 분석 → marker file fallback
# 출력: python | node | go | rust | unknown
detect_language() {
    local dir="${1:-.}"

    # 1. .qlty/qlty.toml 플러그인 기반 감지
    #    실제 형식: [[plugin]]\nname = "ruff"
    local qlty_toml="$dir/.qlty/qlty.toml"
    if [[ -f "$qlty_toml" ]]; then
        if grep -q 'name = "ruff"' "$qlty_toml" 2>/dev/null || \
           grep -q 'name = "bandit"' "$qlty_toml" 2>/dev/null || \
           grep -q 'name = "radarlint-python"' "$qlty_toml" 2>/dev/null; then
            echo "python"; return
        fi
        if grep -q 'name = "eslint"' "$qlty_toml" 2>/dev/null || \
           grep -q 'name = "radarlint-js"' "$qlty_toml" 2>/dev/null; then
            echo "node"; return
        fi
        if grep -q 'name = "clippy"' "$qlty_toml" 2>/dev/null || \
           grep -q 'name = "rustfmt"' "$qlty_toml" 2>/dev/null; then
            echo "rust"; return
        fi
        if grep -q 'name = "golangci-lint"' "$qlty_toml" 2>/dev/null || \
           grep -q 'name = "radarlint-go"' "$qlty_toml" 2>/dev/null; then
            echo "go"; return
        fi
    fi

    # 2. Marker file fallback
    [[ -f "$dir/pyproject.toml" ]] && { echo "python"; return; }
    [[ -f "$dir/package.json" ]] && { echo "node"; return; }
    [[ -f "$dir/go.mod" ]] && { echo "go"; return; }
    [[ -f "$dir/Cargo.toml" ]] && { echo "rust"; return; }

    echo "unknown"
}

# detect_pkg_manager [project_dir]
# lockfile 기반 감지
# 출력: uv | poetry | npm | yarn | pnpm | bun | go | cargo | unknown
detect_pkg_manager() {
    local dir="${1:-.}"

    [[ -f "$dir/uv.lock" ]] && { echo "uv"; return; }
    [[ -f "$dir/poetry.lock" ]] && { echo "poetry"; return; }
    [[ -f "$dir/pnpm-lock.yaml" ]] && { echo "pnpm"; return; }
    [[ -f "$dir/yarn.lock" ]] && { echo "yarn"; return; }
    [[ -f "$dir/bun.lockb" ]] && { echo "bun"; return; }
    [[ -f "$dir/package-lock.json" ]] && { echo "npm"; return; }
    [[ -f "$dir/go.sum" ]] && { echo "go"; return; }
    [[ -f "$dir/Cargo.lock" ]] && { echo "cargo"; return; }

    # marker fallback
    [[ -f "$dir/pyproject.toml" ]] && { echo "uv"; return; }
    [[ -f "$dir/package.json" ]] && { echo "npm"; return; }
    [[ -f "$dir/go.mod" ]] && { echo "go"; return; }
    [[ -f "$dir/Cargo.toml" ]] && { echo "cargo"; return; }

    echo "unknown"
}

# detect_test_runner [project_dir]
# config file 기반 감지
# 출력: pytest | jest | vitest | mocha | go_test | cargo_test | unknown
detect_test_runner() {
    local dir="${1:-.}"

    # Python
    if [[ -f "$dir/pyproject.toml" ]]; then
        if grep -q '\[tool\.pytest' "$dir/pyproject.toml" 2>/dev/null || \
           grep -q '\[tool\.pytest' "$dir/setup.cfg" 2>/dev/null || \
           [[ -f "$dir/pytest.ini" ]] || [[ -f "$dir/conftest.py" ]]; then
            echo "pytest"; return
        fi
    fi

    # Node.js
    if [[ -f "$dir/vitest.config.ts" ]] || [[ -f "$dir/vitest.config.js" ]] || [[ -f "$dir/vitest.config.mts" ]]; then
        echo "vitest"; return
    fi
    if [[ -f "$dir/jest.config.ts" ]] || [[ -f "$dir/jest.config.js" ]] || [[ -f "$dir/jest.config.mjs" ]]; then
        echo "jest"; return
    fi
    if [[ -f "$dir/package.json" ]]; then
        if grep -q '"jest"' "$dir/package.json" 2>/dev/null; then
            echo "jest"; return
        fi
    fi
    if [[ -f "$dir/.mocharc.yml" ]] || [[ -f "$dir/.mocharc.yaml" ]] || [[ -f "$dir/.mocharc.js" ]]; then
        echo "mocha"; return
    fi

    # Go
    [[ -f "$dir/go.mod" ]] && { echo "go_test"; return; }

    # Rust
    [[ -f "$dir/Cargo.toml" ]] && { echo "cargo_test"; return; }

    echo "unknown"
}

# get_install_cmd <pkg_manager>
get_install_cmd() {
    case "$1" in
        uv)      echo "uv sync" ;;
        poetry)  echo "poetry install" ;;
        npm)     echo "npm install" ;;
        yarn)    echo "yarn install" ;;
        pnpm)    echo "pnpm install" ;;
        bun)     echo "bun install" ;;
        go)      echo "go mod download" ;;
        cargo)   echo "cargo build" ;;
        *)       echo "" ;;
    esac
}

# get_add_cmd <pkg_manager>
get_add_cmd() {
    case "$1" in
        uv)      echo "uv add" ;;
        poetry)  echo "poetry add" ;;
        npm)     echo "npm install --save" ;;
        yarn)    echo "yarn add" ;;
        pnpm)    echo "pnpm add" ;;
        bun)     echo "bun add" ;;
        go)      echo "go get" ;;
        cargo)   echo "cargo add" ;;
        *)       echo "" ;;
    esac
}

# get_run_cmd <pkg_manager>
get_run_cmd() {
    case "$1" in
        uv)      echo "uv run" ;;
        poetry)  echo "poetry run" ;;
        npm)     echo "npx" ;;
        yarn)    echo "yarn" ;;
        pnpm)    echo "pnpm exec" ;;
        bun)     echo "bunx" ;;
        go)      echo "go run" ;;
        cargo)   echo "cargo run" ;;
        *)       echo "" ;;
    esac
}

# get_test_cmd <test_runner> <pkg_manager>
get_test_cmd() {
    local runner="$1"
    local pkg="$2"

    case "$runner" in
        pytest)     echo "$(get_run_cmd "$pkg") pytest tests/" ;;
        jest)
            case "$pkg" in
                npm)  echo "npm test" ;;
                yarn) echo "yarn test" ;;
                pnpm) echo "pnpm test" ;;
                bun)  echo "bun test" ;;
                *)    echo "npx jest" ;;
            esac ;;
        vitest)     echo "$(get_run_cmd "$pkg") vitest" ;;
        mocha)      echo "$(get_run_cmd "$pkg") mocha" ;;
        go_test)    echo "go test ./..." ;;
        cargo_test) echo "cargo test" ;;
        *)          echo "" ;;
    esac
}

# get_lockfile <pkg_manager>
get_lockfile() {
    case "$1" in
        uv)      echo "uv.lock" ;;
        poetry)  echo "poetry.lock" ;;
        npm)     echo "package-lock.json" ;;
        yarn)    echo "yarn.lock" ;;
        pnpm)    echo "pnpm-lock.yaml" ;;
        bun)     echo "bun.lockb" ;;
        go)      echo "go.sum" ;;
        cargo)   echo "Cargo.lock" ;;
        *)       echo "" ;;
    esac
}

# get_dependency_dir <language>
get_dependency_dir() {
    case "$1" in
        python) echo ".venv" ;;
        node)   echo "node_modules" ;;
        go)     echo "" ;;
        rust)   echo "target" ;;
        *)      echo "" ;;
    esac
}

# get_dependency_file <language>
get_dependency_file() {
    case "$1" in
        python) echo "pyproject.toml" ;;
        node)   echo "package.json" ;;
        go)     echo "go.mod" ;;
        rust)   echo "Cargo.toml" ;;
        *)      echo "" ;;
    esac
}

# get_file_extensions <language>
get_file_extensions() {
    case "$1" in
        python) echo ".py" ;;
        node)   echo ".ts,.tsx,.js,.jsx,.mjs,.cjs" ;;
        go)     echo ".go" ;;
        rust)   echo ".rs" ;;
        *)      echo "" ;;
    esac
}
