#!/usr/bin/env bash
# load-config.sh — project-config.yaml 로더
# source하여 환경변수로 config 값 접근
#
# 내보내는 변수:
#   PROJECT_NAME, PRIMARY_LANGUAGE, LANGUAGE_NAME, LANGUAGE_VARIANT
#   PKG_MANAGER_NAME, PKG_INSTALL_CMD, PKG_ADD_CMD, PKG_RUN_CMD
#   QLTY_ENABLED, QLTY_CHECK_CMD, QLTY_FIX_CMD, QLTY_FMT_CMD
#   TEST_RUNNER_NAME, TEST_RUNNER_CMD
#   DEPENDENCY_DIR, DEPENDENCY_FILE

_load_project_config() {
    local project_dir="${CLAUDE_PROJECT_DIR:-.}"
    local config_file="$project_dir/.hxsk/project-config.yaml"

    # config 파일 없으면 Python 기본값 설정
    if [[ ! -f "$config_file" ]]; then
        export PROJECT_CONFIG_LOADED="false"
        export PRIMARY_LANGUAGE="python"
        export PKG_MANAGER_NAME="uv"
        export PKG_INSTALL_CMD="uv sync"
        export PKG_ADD_CMD="uv add"
        export PKG_RUN_CMD="uv run"
        export QLTY_ENABLED="false"
        export QLTY_CHECK_CMD=""
        export QLTY_FIX_CMD=""
        export QLTY_FMT_CMD=""
        export TEST_RUNNER_NAME="pytest"
        export TEST_RUNNER_CMD="uv run pytest tests/"
        export DEPENDENCY_DIR=".venv"
        export DEPENDENCY_FILE="pyproject.toml"
        return
    fi

    export PROJECT_CONFIG_LOADED="true"

    # YAML 값 추출 함수 (yq → python3 → grep fallback)
    _yaml_get() {
        local key="$1"
        local file="$2"

        # 1. yq
        if command -v yq &>/dev/null; then
            yq -r "$key // \"\"" "$file" 2>/dev/null
            return
        fi

        # 2. python3 (PyYAML 또는 간단한 파싱)
        if command -v python3 &>/dev/null; then
            python3 -c "
import sys
try:
    import yaml
    with open('$file') as f:
        data = yaml.safe_load(f)
    keys = '$key'.lstrip('.').split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    print(val if val is not None else '')
except ImportError:
    # PyYAML 없으면 간단한 grep 기반 파싱
    import re
    with open('$file') as f:
        content = f.read()
    # 마지막 키로 검색
    last_key = '$key'.split('.')[-1]
    pattern = rf'^\s*{re.escape(last_key)}:\s*(.+)'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        val = match.group(1).strip().strip('\"').strip(\"'\")
        print(val)
    else:
        print('')
except Exception:
    print('')
" 2>/dev/null
            return
        fi

        # 3. grep fallback (최소한의 flat key 파싱)
        local last_key="${key##*.}"
        grep -m1 "^[[:space:]]*${last_key}:" "$file" 2>/dev/null \
            | sed 's/^[^:]*:[[:space:]]*//' \
            | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/' \
            || echo ""
    }

    export PROJECT_NAME=$(_yaml_get ".project.name" "$config_file")
    export PRIMARY_LANGUAGE=$(_yaml_get ".project.primary_language" "$config_file")
    export LANGUAGE_NAME=$(_yaml_get ".language.name" "$config_file")
    export LANGUAGE_VARIANT=$(_yaml_get ".language.variant" "$config_file")
    export PKG_MANAGER_NAME=$(_yaml_get ".package_manager.name" "$config_file")
    export PKG_INSTALL_CMD=$(_yaml_get ".package_manager.install" "$config_file")
    export PKG_ADD_CMD=$(_yaml_get ".package_manager.add" "$config_file")
    export PKG_RUN_CMD=$(_yaml_get ".package_manager.run" "$config_file")
    export QLTY_ENABLED=$(_yaml_get ".qlty.enabled" "$config_file")
    export QLTY_CHECK_CMD=$(_yaml_get ".qlty.check_command" "$config_file")
    export QLTY_FIX_CMD=$(_yaml_get ".qlty.fix_command" "$config_file")
    export QLTY_FMT_CMD=$(_yaml_get ".qlty.format_command" "$config_file")
    export TEST_RUNNER_NAME=$(_yaml_get ".tools.test_runner.name" "$config_file")
    export TEST_RUNNER_CMD=$(_yaml_get ".tools.test_runner.command" "$config_file")
    export DEPENDENCY_DIR=$(_yaml_get ".environment.dependency_dir" "$config_file")
    export DEPENDENCY_FILE=$(_yaml_get ".environment.dependency_file" "$config_file")

    # 빈 값에 대한 기본값
    [[ -z "$PRIMARY_LANGUAGE" ]] && export PRIMARY_LANGUAGE="python"
    [[ -z "$PKG_MANAGER_NAME" ]] && export PKG_MANAGER_NAME="uv"
    [[ -z "$QLTY_ENABLED" ]] && export QLTY_ENABLED="false"
}

# 자동 로드
_load_project_config
