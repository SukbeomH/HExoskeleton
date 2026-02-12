#!/usr/bin/env python3
"""Hook: PreToolUse (Bash) — 파괴적 명령 + 패키지 관리자 차단

1. 파괴적 git 명령 차단 (push --force, reset --hard, checkout ., clean -f 등)
2. 프로젝트 설정 기반 패키지 관리자 차단 (project-config.yaml 참조)
3. Fallback: pip/poetry 차단 (uv 강제)
Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import os
import re
import sys

# ── 파괴적 git 명령 패턴 ──
DESTRUCTIVE_GIT = [
    (
        r"git\s+push\s+.*--force",
        "git push --force is blocked. Use --force-with-lease if absolutely necessary.",
    ),
    (
        r"git\s+push\s+-f\b",
        "git push -f is blocked. Use --force-with-lease if absolutely necessary.",
    ),
    (r"git\s+reset\s+--hard", "git reset --hard is blocked. This discards all local changes."),
    (
        r"git\s+checkout\s+\.\s*$",
        "git checkout . is blocked. This discards all uncommitted changes.",
    ),
    (r"git\s+clean\s+-f", "git clean -f is blocked. This permanently deletes untracked files."),
    (r"git\s+branch\s+-D\b", "git branch -D is blocked. Use -d (safe delete) instead."),
    (
        r"git\s+restore\s+\.\s*$",
        "git restore . is blocked. This discards all working tree changes.",
    ),
]

# ── 패키지 관리자별 차단 패턴 ──
PKG_MANAGER_BLOCKS = {
    "uv": [
        (r"\bpip\s+install\b", "Use 'uv add <package>' instead of 'pip install'."),
        (r"\bpip3\s+install\b", "Use 'uv add <package>' instead of 'pip3 install'."),
        (r"\bpoetry\s+add\b", "Use 'uv add <package>' instead of 'poetry add'."),
        (r"\bpoetry\s+install\b", "Use 'uv sync' instead of 'poetry install'."),
        (r"\bconda\s+install\b", "Use 'uv add <package>' instead of 'conda install'."),
    ],
    "npm": [
        (r"\byarn\s+add\b", "Use 'npm install <package>' instead of 'yarn add'."),
        (r"\bpnpm\s+add\b", "Use 'npm install <package>' instead of 'pnpm add'."),
        (r"\bbun\s+add\b", "Use 'npm install <package>' instead of 'bun add'."),
    ],
    "yarn": [
        (r"\bnpm\s+install\s+\S", "Use 'yarn add <package>' instead of 'npm install'."),
        (r"\bpnpm\s+add\b", "Use 'yarn add <package>' instead of 'pnpm add'."),
    ],
    "pnpm": [
        (r"\bnpm\s+install\s+\S", "Use 'pnpm add <package>' instead of 'npm install'."),
        (r"\byarn\s+add\b", "Use 'pnpm add <package>' instead of 'yarn add'."),
    ],
    "cargo": [
        (r"\bnpm\s+install\b", "This is a Rust project. Use 'cargo add <package>'."),
    ],
    "go": [
        (r"\bnpm\s+install\b", "This is a Go project. Use 'go get <package>'."),
    ],
}

# Fallback: uv 기본값
DEFAULT_BLOCKS = PKG_MANAGER_BLOCKS["uv"]


def load_pkg_manager():
    """project-config.yaml에서 package_manager.name 읽기"""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
    config_path = os.path.join(project_dir, ".gsd", "project-config.yaml")

    if not os.path.isfile(config_path):
        return None

    try:
        with open(config_path) as f:
            content = f.read()
    except OSError:
        return None

    # package_manager 섹션의 name 값을 regex로 추출
    # 예: package_manager:\n  name: uv
    match = re.search(
        r"package_manager:\s*\n\s+name:\s*[\"']?(\w+)[\"']?",
        content,
    )
    return match.group(1) if match else None


try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_input = data.get("tool_input", {})
command = tool_input.get("command", "")

if not command:
    sys.exit(0)

# 파괴적 git 명령 검사
for pattern, message in DESTRUCTIVE_GIT:
    if re.search(pattern, command):
        print(f"Blocked: {message}", file=sys.stderr)
        sys.exit(2)

# 패키지 관리자 검사 (project-config.yaml 기반 → fallback)
pkg_manager = load_pkg_manager()
blocks = PKG_MANAGER_BLOCKS.get(pkg_manager, DEFAULT_BLOCKS) if pkg_manager else DEFAULT_BLOCKS

for pattern, message in blocks:
    if re.search(pattern, command):
        print(f"Blocked: {message}", file=sys.stderr)
        sys.exit(2)

sys.exit(0)
