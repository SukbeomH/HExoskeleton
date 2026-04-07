#!/usr/bin/env python3
"""Hook: PostToolUse (Read) — Read 이력 기록

read-before-edit.py와 연동. Read 도구 사용 시 파일 경로를 기록합니다.
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

if tool_name != "Read" or not file_path:
    sys.exit(0)

# 절대 경로와 원본 경로 모두 기록
abs_path = os.path.abspath(file_path)

os.makedirs(os.path.dirname(READ_HISTORY), exist_ok=True)

# 중복 방지: 이미 기록된 경로는 건너뜀
existing = set()
if os.path.exists(READ_HISTORY):
    with open(READ_HISTORY, "r") as f:
        existing = {line.strip() for line in f if line.strip()}

with open(READ_HISTORY, "a") as f:
    if abs_path not in existing:
        f.write(abs_path + "\n")
    if file_path not in existing and file_path != abs_path:
        f.write(file_path + "\n")

sys.exit(0)
