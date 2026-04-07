#!/usr/bin/env python3
"""Hook: PreToolUse (Edit) — Read 없이 Edit 차단

Iron Law: NO EDIT WITHOUT READ FIRST
세션 내에서 대상 파일을 Read한 적이 없으면 경고를 반환합니다.

Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import os
import sys

HXSK_DIR = os.environ.get("HXSK_DIR", ".hxsk")
READ_HISTORY = os.path.join(HXSK_DIR, ".read-history.log")

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")

if not file_path:
    sys.exit(0)

# Edit 도구만 검사
if tool_name != "Edit":
    sys.exit(0)

# Read history 확인
read_files = set()
if os.path.exists(READ_HISTORY):
    with open(READ_HISTORY, "r") as f:
        read_files = {line.strip() for line in f if line.strip()}

# 절대 경로 정규화
abs_path = os.path.abspath(file_path)

if abs_path not in read_files and file_path not in read_files:
    print(
        f"Warning: '{os.path.basename(file_path)}' has not been Read in this session. "
        "Iron Law: NO EDIT WITHOUT READ FIRST — please Read the file before editing.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
