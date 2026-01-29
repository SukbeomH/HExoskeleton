#!/usr/bin/env python3
"""Hook: PreToolUse (Edit|Write) — 민감 파일 보호

.env, 시크릿, 인증서 파일 등의 수정을 차단합니다.
Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import sys

BLOCKED_PATTERNS = [
    ".env",
    ".env.local",
    ".env.mcp",
    ".pem",
    ".key",
    "secrets/",
    ".git/",
    "id_rsa",
    "id_ed25519",
    "credentials",
]

BLOCKED_EXACT = [
    ".env",
    ".env.local",
    ".env.mcp",
]

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")

if not file_path:
    sys.exit(0)

# 정규화: 절대경로에서 파일명 추출
import os

# 보안: 경로 순회 공격 차단
if ".." in file_path:
    print(
        "Blocked: path traversal detected ('..') — potential security risk.",
        file=sys.stderr,
    )
    sys.exit(2)

basename = os.path.basename(file_path)
rel_path = file_path

# 정확한 파일명 매칭
for exact in BLOCKED_EXACT:
    if basename == exact:
        print(
            f"Blocked: '{basename}' is a protected file. "
            "Never read/write .env or credential files.",
            file=sys.stderr,
        )
        sys.exit(2)

# 패턴 매칭 (경로에 포함)
for pattern in BLOCKED_PATTERNS:
    if pattern in rel_path:
        print(
            f"Blocked: path contains '{pattern}' — protected file/directory. "
            "Never read/write credential or secret files.",
            file=sys.stderr,
        )
        sys.exit(2)

sys.exit(0)
