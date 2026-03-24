#!/usr/bin/env python3
"""Hook: PreToolUse (Edit|Write) — 민감 파일 보호

.env, 시크릿, 인증서 파일 등의 수정을 차단합니다.
Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import os
import sys

BLOCKED_PATTERNS = [
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

# .env 패턴 중 허용되는 안전한 파일 (비밀값 미포함 템플릿)
ALLOWED_ENV_SUFFIXES = (
    ".example",
    ".sample",
    ".template",
    ".defaults",
    ".test",
)

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")

if not file_path:
    sys.exit(0)

# 보안: 경로 순회 공격 차단
if ".." in file_path:
    print(
        "Blocked: path traversal detected ('..') — potential security risk.",
        file=sys.stderr,
    )
    sys.exit(2)

basename = os.path.basename(file_path)
rel_path = file_path

# .env 계열: 안전한 템플릿 파일은 허용, 실제 시크릿 파일만 차단
if basename.startswith(".env"):
    if not basename.endswith(ALLOWED_ENV_SUFFIXES):
        print(
            f"Blocked: '{basename}' is a protected file. "
            "Never read/write .env or credential files.",
            file=sys.stderr,
        )
        sys.exit(2)
    # 허용된 .env 템플릿 → 나머지 검사 스킵
    sys.exit(0)

# 정확한 파일명 매칭 (비 .env 계열)
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
