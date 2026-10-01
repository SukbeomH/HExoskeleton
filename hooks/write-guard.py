#!/usr/bin/env python3
"""Hook: PreToolUse (Write) — 기존 파일 덮어쓰기 방지

Iron Law: NO WRITE TO EXISTING FILES — Use Edit for modifications.
Write 도구로 이미 존재하는 파일을 덮어쓰려 하면 경고합니다.

Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import os
import sys

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")

if tool_name != "Write" or not file_path:
    sys.exit(0)

if os.path.exists(file_path):
    print(
        f"Warning: '{os.path.basename(file_path)}' already exists. "
        "Iron Law: NO WRITE TO EXISTING FILES — use Edit for modifications.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
