#!/usr/bin/env python3
"""Hook: PreToolUse (Edit|Write) — 민감 파일 보호

.env, 시크릿, 인증서 파일 등의 수정을 차단합니다.
Codex apply_patch·Hermes V4A patch 는 file_path 없이 tool_input.command 의 패치 본문으로 오므로
`*** Add/Update/Delete/Move File:`·`*** Move to:` 줄의 경로를 같은 규칙으로 검사합니다.
Exit code 2 = 차단 (stderr가 Claude에게 전달됨)
Exit code 0 = 허용
"""

import json
import os
import re
import sys

BLOCKED_PATTERNS = [
    ".pem",
    ".key",
    "secrets/",
    "secrets.",   # secrets.json, secrets.yaml, secrets.toml
    ".secrets",   # private.secrets, app.secrets
    ".git/",
    ".gitconfig",
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

def check(file_path):
    """차단 사유(stderr 메시지)를 돌려준다. 허용이면 None."""
    # 보안: 경로 순회 공격 차단
    if ".." in file_path:
        return "Blocked: path traversal detected ('..') — potential security risk."

    basename = os.path.basename(file_path)

    # .env 계열: 안전한 템플릿 파일은 허용, 실제 시크릿 파일만 차단
    if basename.startswith(".env"):
        if not basename.endswith(ALLOWED_ENV_SUFFIXES):
            return (
                f"Blocked: '{basename}' is a protected file. "
                "Never read/write .env or credential files."
            )
        # 허용된 .env 템플릿 → 나머지 검사 스킵
        return None

    # 정확한 파일명 매칭 (비 .env 계열)
    if basename in BLOCKED_EXACT:
        return (
            f"Blocked: '{basename}' is a protected file. "
            "Never read/write .env or credential files."
        )

    # 패턴 매칭 (경로에 포함)
    for pattern in BLOCKED_PATTERNS:
        if pattern in file_path:
            return (
                f"Blocked: path contains '{pattern}' — protected file/directory. "
                "Never read/write credential or secret files."
            )
    return None


try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")
# Codex apply_patch·Hermes V4A patch: file_path 없음 → 패치 본문의 모든 대상 경로(이동 대상 포함).
# Hermes 파서는 공백을 느슨하게 받고 이동을 `*** Move File: a -> b` 로 쓴다 (tools/patch_parser.py).
paths = [file_path] if file_path else [
    p
    for m in re.findall(
        r"^\*\*\*\s*(?:(?:Add|Update|Delete|Move)\s+File|Move\s+to):\s*(.+)$",
        str(tool_input.get("command", "")),
        re.M,
    )
    for p in m.split("->")
]

for path in paths:
    reason = check(path.strip())
    if reason:
        print(reason, file=sys.stderr)
        sys.exit(2)

sys.exit(0)
