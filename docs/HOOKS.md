# Hooks 상세 문서

Claude Code의 **Hooks**는 특정 이벤트에 자동으로 응답하는 스크립트입니다. 세션 시작, 도구 사용 전/후, 세션 종료 등의 이벤트에서 자동화된 작업을 수행합니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **설정 파일** | `.claude/settings.json` |
| **스크립트 위치** | `.claude/hooks/` |
| **개수** | 8개 스크립트 |
| **이벤트 종류** | SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SessionEnd |

---

## 훅 이벤트 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ SessionStart│────▶│  작업 수행   │────▶│ SessionEnd  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
  session-start.sh    PreToolUse         memory 저장
  (상태 로드)         PostToolUse        (prompt hook)
                      Stop
                      PreCompact
```

---

## 훅 목록

| 이벤트 | 스크립트 | 타입 | 기능 | 타임아웃 |
|--------|----------|------|------|----------|
| **SessionStart** | `session-start.sh` | command | GSD STATE.md 로드, git status 주입 | 10s |
| **PreToolUse** (Edit/Write/Read) | `file-protect.py` | command | .env, 시크릿 파일 보호 | 5s |
| **PreToolUse** (Bash) | `bash-guard.py` | command | 위험한 명령어 차단 | 5s |
| **PostToolUse** (Edit/Write) | `auto-format-py.sh` | command | Python 파일 자동 포맷 (ruff) | 30s |
| **PreCompact** | `pre-compact-save.sh` | command | 컴팩트 전 상태 저장 | 10s |
| **Stop** | `post-turn-index.sh` | command | 변경된 코드 인덱싱 | 10s |
| **Stop** | `post-turn-verify.sh` | command | 작업 검증 | 15s |
| **SessionEnd** | `save-transcript.sh` | command | 대화 내역 .sessions/에 저장 | 10s |
| **SessionEnd** | (prompt) | prompt | memory-graph에 세션 요약 저장 | - |

---

## 설정 파일 구조

### settings.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh",
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
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/file-protect.py",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/bash-guard.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format-py.sh",
            "timeout": 30
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
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact-save.sh",
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
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-turn-index.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-turn-verify.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Session is ending. Store a concise session summary in memory-graph..."
          }
        ]
      }
    ]
  }
}
```

---

## 훅 타입

### Command Hook

외부 스크립트를 실행합니다.

```json
{
  "type": "command",
  "command": "path/to/script.sh",
  "timeout": 10
}
```

**Exit Codes**:
- `0`: 허용 (계속 진행)
- `2`: 차단 (stderr가 Claude에게 전달됨)

### Prompt Hook

Claude에게 프롬프트를 주입합니다.

```json
{
  "type": "prompt",
  "prompt": "Do something specific..."
}
```

---

## 스크립트 상세

### 1. session-start.sh

**이벤트**: SessionStart
**역할**: 세션 시작 시 GSD 상태와 git status를 컨텍스트에 주입

```bash
#!/bin/bash
# Hook: SessionStart — GSD 상태 자동 로드
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.gsd/STATE.md"

# 1. GSD STATE.md 로드 (상위 80줄)
if [ -f "$STATE_FILE" ]; then
    STATE_CONTENT=$(head -80 "$STATE_FILE" 2>/dev/null || true)
    # JSON으로 additionalContext 출력
fi

# 2. Git 미커밋 변경사항 요약
GIT_STATUS=$(git -C "$PROJECT_DIR" status --short 2>/dev/null || true)

# 3. 최근 커밋 3개
RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null || true)

# JSON 출력 (hookSpecificOutput.additionalContext)
```

**출력 형식**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "## GSD State\n...\n## Uncommitted Changes\n..."
  }
}
```

---

### 2. file-protect.py

**이벤트**: PreToolUse (Edit/Write/Read)
**역할**: 민감 파일 보호 (`.env`, 시크릿, 인증서)

```python
#!/usr/bin/env python3
"""Hook: PreToolUse (Edit|Write) — 민감 파일 보호"""

BLOCKED_PATTERNS = [
    ".env", ".env.local", ".env.mcp",
    ".pem", ".key", "secrets/", ".git/",
    "id_rsa", "id_ed25519", "credentials",
]

BLOCKED_EXACT = [".env", ".env.local", ".env.mcp"]

# stdin에서 tool_input 읽기
data = json.load(sys.stdin)
file_path = data.get("tool_input", {}).get("file_path", "")

# 차단 체크
for exact in BLOCKED_EXACT:
    if basename == exact:
        print(f"Blocked: '{basename}' is a protected file.", file=sys.stderr)
        sys.exit(2)  # 차단

sys.exit(0)  # 허용
```

**차단 패턴**:
| 패턴 | 설명 |
|------|------|
| `.env*` | 환경변수 파일 |
| `.pem`, `.key` | 인증서/키 |
| `secrets/` | 시크릿 디렉토리 |
| `.git/` | Git 내부 |
| `id_rsa`, `id_ed25519` | SSH 키 |
| `credentials` | 자격 증명 |

---

### 3. bash-guard.py

**이벤트**: PreToolUse (Bash)
**역할**: 파괴적 git 명령 + pip/poetry 차단

```python
#!/usr/bin/env python3
"""Hook: PreToolUse (Bash) — 파괴적 명령 + pip/poetry 차단"""

# 파괴적 git 명령 패턴
DESTRUCTIVE_GIT = [
    (r"git\s+push\s+.*--force", "Use --force-with-lease instead"),
    (r"git\s+reset\s+--hard", "This discards all local changes"),
    (r"git\s+checkout\s+\.\s*$", "This discards uncommitted changes"),
    (r"git\s+clean\s+-f", "This permanently deletes untracked files"),
    (r"git\s+branch\s+-D\b", "Use -d (safe delete) instead"),
]

# pip/poetry 차단 (uv 강제)
WRONG_PKG_MANAGER = [
    (r"\bpip\s+install\b", "Use 'uv add <package>' instead"),
    (r"\bpoetry\s+add\b", "Use 'uv add <package>' instead"),
    (r"\bconda\s+install\b", "Use 'uv add <package>' instead"),
]
```

**차단 명령**:

| 명령 | 이유 | 대안 |
|------|------|------|
| `git push --force` | 원격 히스토리 덮어쓰기 | `--force-with-lease` |
| `git reset --hard` | 로컬 변경 삭제 | `git stash` |
| `git checkout .` | 미커밋 변경 삭제 | `git stash` |
| `git clean -f` | 미추적 파일 영구 삭제 | 수동 삭제 |
| `pip install` | 패키지 관리자 불일치 | `uv add` |

---

### 4. auto-format-py.sh

**이벤트**: PostToolUse (Edit/Write)
**역할**: Python 파일 자동 포맷 (ruff)

```bash
#!/bin/bash
# PostToolUse: Python 파일 자동 포맷

# .py 파일인 경우에만 실행
if [[ "$FILE_PATH" == *.py ]]; then
    ruff format "$FILE_PATH" 2>/dev/null || true
    ruff check --fix "$FILE_PATH" 2>/dev/null || true
fi
```

---

### 5. pre-compact-save.sh

**이벤트**: PreCompact
**역할**: 컨텍스트 압축 전 상태 저장

```bash
#!/bin/bash
# PreCompact: 상태 저장

# STATE.md 업데이트
echo "## Pre-Compact State Dump" >> .gsd/STATE.md
echo "Timestamp: $(date -Iseconds)" >> .gsd/STATE.md
```

---

### 6. post-turn-index.sh

**이벤트**: Stop
**역할**: 변경된 코드 인덱싱 (code-graph-rag)

```bash
#!/bin/bash
# Stop: 변경된 파일 인덱싱

# 변경된 파일 목록
CHANGED=$(git diff --name-only HEAD~1 2>/dev/null || true)

# code-graph-rag 인덱싱 (MCP 도구로 호출)
```

---

### 7. post-turn-verify.sh

**이벤트**: Stop
**역할**: 작업 검증

```bash
#!/bin/bash
# Stop: 작업 검증

# 린트 체크
ruff check . --quiet || true

# 타입 체크
mypy . --quiet || true
```

---

### 8. save-transcript.sh

**이벤트**: SessionEnd
**역할**: 대화 내역을 프로젝트에 저장

```bash
#!/bin/bash
# SessionEnd: 대화 내역 저장

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_DIR="$PROJECT_DIR/.sessions"

mkdir -p "$SESSION_DIR"

# Claude 프로젝트 경로에서 최신 transcript 복사
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
PROJECT_PATH_ESCAPED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
CLAUDE_PROJECT_PATH="$CLAUDE_PROJECTS_DIR/$PROJECT_PATH_ESCAPED"

LATEST_TRANSCRIPT=$(ls -t "$CLAUDE_PROJECT_PATH"/*.jsonl 2>/dev/null | head -1)

if [ -f "$LATEST_TRANSCRIPT" ]; then
    SESSION_ID=$(basename "$LATEST_TRANSCRIPT" .jsonl)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    cp "$LATEST_TRANSCRIPT" "$SESSION_DIR/${SESSION_ID}-${TIMESTAMP}.jsonl"
fi
```

**저장 위치**: `.sessions/{session-id}-{timestamp}.jsonl`

**파일 형식** (JSONL):
```json
{"type":"user","content":"안녕하세요"}
{"type":"assistant","content":"안녕하세요!"}
{"type":"tool_use","name":"Bash","input":{...}}
{"type":"tool_result","content":"..."}
```

---

## 훅 작동 예시

### file-protect.py — 민감 파일 보호

```
User: ".env 파일 읽어줘"
     │
     ▼
PreToolUse(Read) → file-protect.py 실행
     │
     ▼
차단됨: ".env is a protected file"
```

### session-start.sh — 세션 시작 시 상태 로드

```
Claude Code 시작
     │
     ▼
SessionStart → session-start.sh 실행
     │
     ▼
.gsd/STATE.md + git status가 컨텍스트에 주입됨
```

### bash-guard.py — 파괴적 명령 차단

```
User: "git push --force"
     │
     ▼
PreToolUse(Bash) → bash-guard.py 실행
     │
     ▼
차단됨: "Use --force-with-lease instead"
```

### save-transcript.sh — 대화 내역 저장

```
세션 종료 (/exit 또는 창 닫기)
     │
     ▼
SessionEnd → save-transcript.sh 실행
     │
     ▼
.sessions/49d4a1ae-20260129-110300.jsonl 저장됨
```

---

## 환경변수

훅 스크립트에서 사용 가능한 환경변수:

| 변수 | 설명 |
|------|------|
| `CLAUDE_PROJECT_DIR` | 프로젝트 루트 디렉토리 |
| `CLAUDE_PLUGIN_ROOT` | 플러그인 루트 (플러그인에서 사용 시) |

---

## 플러그인에서의 훅

플러그인에서 훅을 사용할 때는 `hooks/hooks.json` 파일에 정의합니다.

### 경로 변환

| 프로젝트 | 플러그인 |
|----------|----------|
| `"$CLAUDE_PROJECT_DIR"/.claude/hooks/X` | `${CLAUDE_PLUGIN_ROOT}/scripts/X` |

### hooks.json 형식

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bash-guard.py"
          }
        ]
      }
    ]
  }
}
```

---

## 훅 작성 가이드

### 1. Exit Code 규칙

```python
sys.exit(0)  # 허용 — 작업 계속 진행
sys.exit(2)  # 차단 — stderr가 Claude에게 전달됨
```

### 2. 타임아웃 설정

훅이 무한 대기하지 않도록 적절한 타임아웃을 설정합니다.

```json
{
  "type": "command",
  "command": "...",
  "timeout": 10  // 초 단위
}
```

### 3. 에러 처리

```bash
set -euo pipefail  # 엄격 모드

# 또는 에러 무시
command || true
```

### 4. JSON 출력 (additionalContext)

```python
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "..."
    }
}))
```

---

## 관련 문서

- [Agents 상세](./AGENTS.md) — 서브에이전트
- [Skills 상세](./SKILLS.md) — 자율 호출 스킬
- [Workflows 상세](./WORKFLOWS.md) — 슬래시 명령어
