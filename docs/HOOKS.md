# Hooks 상세 문서

Claude Code의 **Hooks**는 특정 이벤트에 자동으로 응답하는 스크립트입니다. 세션 시작, 도구 사용 전/후, 세션 종료 등의 이벤트에서 자동화된 작업을 수행합니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **설정 파일** | `.claude/settings.json` |
| **스크립트 위치** | `.hxsk/hooks/` |
| **개수** | 27개 스크립트 (`.hxsk/hooks/INDEX.md` 기준) |
| **이벤트 종류** | SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SubagentStop, SessionEnd |

---

## 훅 이벤트 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ SessionStart│────▶│  작업 수행   │────▶│ SessionEnd  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
  session-start.sh    PreToolUse         save-transcript.sh
  (상태 로드)         PostToolUse        save-session-changes.sh
                      Stop
                      PreCompact
                      SubagentStop
```

---

## 훅 목록

### 이벤트별 훅

| 이벤트 | 스크립트 | 타입 | 기능 | 타임아웃 |
|--------|----------|------|------|----------|
| **SessionStart** | `session-start.sh` | command | source 기반 분기 로드 (startup=풀/resume=최소/compact=핵심) | 10s |
| **PreToolUse** (Edit/Write/Read) | `file-protect.py` | command | .env, 시크릿 파일 보호 | 5s |
| **PreToolUse** (Bash) | `bash-guard.py` | command | 위험한 명령어 차단 | 5s |
| **PostToolUse** (Edit/Write) | `auto-format.sh` | command | Python 파일 자동 포맷 (ruff) | 30s |
| **PostToolUse** (Edit/Write/Bash) | `track-modifications.sh` | command | 변경 파일 추적 | 2s |
| **PreCompact** | `pre-compact-save.sh` | command | 컴팩트 전 세션 스냅샷 저장 | 10s |
| **Stop** | `post-turn-verify.sh` | command | 작업 검증 | 15s |
| **Stop** | `stop-context-save.sh` | command | 세션 컨텍스트 저장 | 10s |
| **SubagentStop** | (prompt) | prompt | 서브에이전트 결과 요약 | - |
| **SessionEnd** | `save-transcript.sh` | command | 대화 내역 .sessions/에 저장 | 10s |
| **SessionEnd** | `save-session-changes.sh` | command | 세션 변경사항 추적 | 10s |

### 유틸리티 스크립트

| 스크립트 | 기능 |
|----------|------|
| `md-store-memory.sh` | 파일 기반 메모리 저장 |
| `md-recall-memory.sh` | 파일 기반 메모리 검색 |
| `scaffold-hxsk.sh` | HXSK 문서 초기화 |
| `compact-context.sh` | 컨텍스트 압축 |
| `organize-docs.sh` | 문서 정리/아카이브 |
| `scaffold-infra.sh` | 인프라 스캐폴딩 |
| `_json_parse.sh` | JSON 파싱 유틸리티 |

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

## 메모리 시스템 훅

순수 bash 기반 메모리 시스템 스크립트입니다.

### md-store-memory.sh

**역할**: 파일 기반 메모리 저장

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "<title>" \
  "<content>" \
  "[tags]" \
  "[type]" \
  "[keywords]" \
  "[contextual_description]" \
  "[related]"
```

**매개변수**:
| 매개변수 | 필수 | 설명 |
|----------|------|------|
| `title` | Yes | 메모리 제목 |
| `content` | Yes | 메모리 내용 |
| `tags` | No | 쉼표 구분 태그 |
| `type` | No | 메모리 타입 (기본: general) |
| `keywords` | No | A-Mem 검색 키워드 |
| `contextual_description` | No | 1줄 요약 (검색 압축용) |
| `related` | No | 관련 메모리 파일명 |

**출력**:
```
./.hxsk/memories/root-cause/2026-02-06_jwt.md
```

**중복 방지** (Nemori Predict-Calibrate):
```
[SKIP:DUPLICATE] ./.hxsk/memories/root-cause/2026-02-06_jwt.md
```

---

### md-recall-memory.sh

**역할**: 파일 기반 메모리 검색

```bash
bash .hxsk/hooks/md-recall-memory.sh \
  "<query>" \
  "[project_path]" \
  "[limit]" \
  "[mode]" \
  "[hop]"
```

**매개변수**:
| 매개변수 | 기본값 | 설명 |
|----------|--------|------|
| `query` | - | 검색어 (필수) |
| `project_path` | `.` | 프로젝트 경로 |
| `limit` | `5` | 최대 결과 수 |
| `mode` | `compact` | compact (요약) 또는 full (전체) |
| `hop` | `2` | 1 (직접만) 또는 2 (related 포함) |

**compact 모드 출력**:
```
- **JWT 토큰 만료 처리** [root-cause] 2026-02-06
  JWT 토큰 만료 처리 누락으로 인한 401 오류
```

**full 모드 출력**:
```markdown
### JWT 토큰 만료 처리 [root-cause]
📁 `./.hxsk/memories/root-cause/2026-02-06_jwt.md`

## JWT 토큰 만료 처리
내용...
```

---

## 주요 스크립트 상세

### 1. session-start.sh

**이벤트**: SessionStart
**역할**: 세션 시작 시 HXSK 상태와 git status를 컨텍스트에 주입

```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.hxsk/STATE.md"

# 1. HXSK STATE.md 로드 (상위 80줄)
if [ -f "$STATE_FILE" ]; then
    STATE_CONTENT=$(head -80 "$STATE_FILE" 2>/dev/null || true)
fi

# 2. Git 미커밋 변경사항 요약
GIT_STATUS=$(git -C "$PROJECT_DIR" status --short 2>/dev/null || true)

# 3. 최근 커밋 3개
RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --oneline -3 2>/dev/null || true)

# JSON 출력 (hookSpecificOutput.additionalContext)
```

---

### 2. file-protect.py

**이벤트**: PreToolUse (Edit/Write/Read)
**역할**: 민감 파일 보호 (`.env`, 시크릿, 인증서)

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

**차단 명령**:

| 명령 | 이유 | 대안 |
|------|------|------|
| `git push --force` | 원격 히스토리 덮어쓰기 | `--force-with-lease` |
| `git reset --hard` | 로컬 변경 삭제 | `git stash` |
| `git checkout .` | 미커밋 변경 삭제 | `git stash` |
| `git clean -f` | 미추적 파일 영구 삭제 | 수동 삭제 |
| `pip install` | 패키지 관리자 불일치 | `uv add` |

---

### 4. pre-compact-save.sh

**이벤트**: PreCompact
**역할**: 컨텍스트 압축 전 세션 스냅샷 저장

메모리에 `session-snapshot` 타입으로 자동 저장됩니다.

---

### 5. stop-context-save.sh

**이벤트**: Stop
**역할**: 세션 컨텍스트 저장

메모리에 `session-summary` 타입으로 자동 저장됩니다.

---

### 6. save-transcript.sh

**이벤트**: SessionEnd
**역할**: 대화 내역을 프로젝트에 저장

**저장 위치**: `.sessions/{session-id}-{timestamp}.jsonl`

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
.hxsk/STATE.md + git status가 컨텍스트에 주입됨
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

---

## 환경변수

훅 스크립트에서 사용 가능한 환경변수:

| 변수 | 설명 |
|------|------|
| `CLAUDE_PROJECT_DIR` | 프로젝트 루트 디렉토리 |
| `CLAUDE_PLUGIN_ROOT` | 플러그인 루트 (플러그인에서 사용 시) |

> **주의**: `settings.json`의 `command` 경로에는 상대 경로(`.hxsk/hooks/...`)를 사용하세요.
> `"$CLAUDE_PROJECT_DIR"`는 훅 러너가 확장하지 못할 수 있습니다.
> 스크립트 내부에서는 `${CLAUDE_PROJECT_DIR:-.}` (fallback 포함) 패턴을 사용하세요.

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
  "timeout": 10
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
- [Memory 상세](./MEMORY.md) — 파일 기반 메모리 시스템
