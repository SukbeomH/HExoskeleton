#!/usr/bin/env bash
# install-hooks.sh — HXSK Step 6 자동화: .claude/settings.json에 훅 설치
# Usage:
#   bash .hxsk/scripts/install-hooks.sh           # 신규 생성 (기존 파일 .before-hxsk.bak으로 백업)
#   bash .hxsk/scripts/install-hooks.sh --merge   # 기존 설정 보존하며 HXSK 훅만 병합
#   bash .hxsk/scripts/install-hooks.sh --harness claude-code  # (alias: 신규 생성과 동일)
#
# Requirements: bash, python3 (시스템 내장) — jq 불필요
set -euo pipefail

SETTINGS=".claude/settings.json"
MERGE=0

for arg in "$@"; do
  [[ "$arg" == "--merge" ]] && MERGE=1
done

# ─── HXSK 훅 정의 ────────────────────────────────────────────────────────────
# 현재 .claude/settings.json의 hooks 섹션에서 추출한 표준 정의
HXSK_HOOKS=$(cat <<'HXSK_JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Read",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/file-protect.py",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/read-before-edit.py",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/write-guard.py",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/bash-guard.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/track-read-history.py",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/auto-format.sh",
            "timeout": 30
          },
          {
            "type": "command",
            "command": ".hxsk/hooks/track-modifications.sh",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/track-modifications.sh",
            "timeout": 2
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto|manual",
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/pre-compact-save.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/post-turn-verify.sh",
            "timeout": 15
          },
          {
            "type": "command",
            "command": ".hxsk/hooks/stop-context-save.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": ".hxsk/hooks/collect-rationalization.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "## SubagentStop\n- 핵심 결과 2-3문장 요약\n- 코드 변경 시: `touch .hxsk/.modified-this-session`\n- 재사용 패턴 발견 시: PATTERNS.md에 추가 검토\n- 스킬 본문을 결과에 복제하지 말 것"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".hxsk/hooks/save-transcript.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": ".hxsk/hooks/save-session-changes.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HXSK_JSON
)

# ─── 설치 ────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$SETTINGS")"

if [[ -f "$SETTINGS" && "$MERGE" -eq 1 ]]; then
  # --merge: 기존 비훅 설정(enabledPlugins, model 등) 보존, hooks 키만 교체
  python3 - "$HXSK_HOOKS" <<'PYEOF'
import json, sys

settings_path = ".claude/settings.json"
hxsk_json = sys.argv[1]

with open(settings_path, "r", encoding="utf-8") as f:
    existing = json.load(f)

hxsk = json.loads(hxsk_json)

# hooks 키만 교체 — 나머지 최상위 키는 기존 값 유지
existing["hooks"] = hxsk.get("hooks", {})

tmp_path = settings_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
    f.write("\n")

import os
os.replace(tmp_path, settings_path)
print("[OK] 기존 settings.json에 HXSK 훅 병합 완료 (비훅 설정 보존)")
PYEOF
else
  # 신규 생성: 기존 파일이 있으면 백업
  if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "${SETTINGS}.before-hxsk.bak"
    echo "[INFO] 기존 settings.json → ${SETTINGS}.before-hxsk.bak 백업"
  fi
  python3 - "$HXSK_HOOKS" <<'PYEOF'
import json, sys

hxsk_json = sys.argv[1]
settings_path = ".claude/settings.json"

hxsk = json.loads(hxsk_json)

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(hxsk, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("[OK] settings.json 생성 완료")
PYEOF
fi

# ─── 검증 ────────────────────────────────────────────────────────────────────
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "[OK] JSON 유효"
