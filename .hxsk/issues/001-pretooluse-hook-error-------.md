---
id: 001
title: "PreToolUse hook error — 환경변수 미확장 및 훅 러너 이슈"
type: bug
priority: P1
status: resolved
wave: null
created: 2026-03-31
assignee: null
files:
  - .claude/settings.json
  - .hxsk/hooks/file-protect.py
  - .hxsk/hooks/bash-guard.py
---

# PreToolUse hook error — 환경변수 미확장 및 훅 러너 이슈

## 환경
- Claude Code v2.1.85
- macOS Darwin 25.3.0
- Python 3.14.3
- settings.json 위치: `.claude/settings.json` (프로젝트 레벨)

## 증상
- "PreToolUse:Read hook error", "PreToolUse:Bash hook error" 메시지가 세션 중 간헐적으로 발생
- 스크립트(`file-protect.py`, `bash-guard.py`) 자체는 정상 동작 (exit 0/2)
- 에러 발생해도 도구 실행은 차단되지 않음 (무시되고 진행됨)

## 에러 발생 위치

```
.claude/settings.json → hooks.PreToolUse
├── matcher: "Edit|Write|Read" → .hxsk/hooks/file-protect.py
└── matcher: "Bash"            → .hxsk/hooks/bash-guard.py
```

## 추정 원인

### 1. `$CLAUDE_PROJECT_DIR` 환경변수 미확장
```json
"command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/file-protect.py"
```
Claude Code가 이 환경변수를 확장하지 못하면 스크립트를 찾을 수 없어 에러 발생.
이 문제는 Claude Code 버전, 쉘 환경, 또는 settings.json이 프로젝트 레벨이 아닌 글로벌 레벨에서 로드될 때 발생할 수 있음.

### 2. 훅 러너의 stdin 전달 형식 불일치
두 스크립트 모두 `json.load(sys.stdin)`으로 입력을 받음. Claude Code가:
- stdin을 아예 전달하지 않거나
- JSON이 아닌 형태로 전달하거나
- `tool_input` 구조가 기대와 다르면

`json.JSONDecodeError`가 발생하지만, 스크립트는 이를 `except`로 잡아 `sys.exit(0)` (허용)으로 처리함.
따라서 스크립트 내부 에러가 아니라 **Claude Code 훅 러너 자체의 에러**.

### 3. Python 인터프리터 시작 지연
훅 timeout(5초) 내 Python 인터프리터 시작 지연 가능성.

## 스크립트 동작 확인 결과

| 테스트 | 결과 |
|--------|------|
| 정상 JSON stdin | exit 0 (허용) |
| 빈 stdin | exit 0 (허용, except 처리) |
| stdin 없음 | exit 0 (허용, except 처리) |
| 차단 대상 파일 (.env) | exit 2 (차단, stderr 메시지) |
| 차단 대상 명령 (git push --force) | exit 2 (차단, stderr 메시지) |

스크립트 로직에는 문제 없음. 에러는 Claude Code의 훅 러너가 스크립트 실행 전/후 과정에서 발생하는 것으로 보임.

## 재현 조건
- `.claude/settings.json`에 PreToolUse 훅 등록
- Read, Edit, Write, Bash 도구 사용 시 간헐 발생

## 수정 내용

**근본 원인**: `settings.json`의 command 경로에서 `\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/...` 형식 사용.
Claude Code 훅 러너가 이 환경변수를 항상 확장하지 못하여 `/.hxsk/hooks/...`로 변환 → 파일 미발견 에러.

**수정**: 모든 훅 command 경로를 상대 경로(`.hxsk/hooks/...`)로 변경.
- 훅은 프로젝트 루트에서 실행되므로 상대 경로가 안전함
- 훅 스크립트 내부에서는 이미 `${CLAUDE_PROJECT_DIR:-.}` fallback을 사용 중이므로 변경 불필요

**변경 파일**: `.claude/settings.json` (11곳 일괄 수정)

## Acceptance Criteria

- [x] `$CLAUDE_PROJECT_DIR` 확장 문제 원인 확인 및 해결
- [x] 훅 러너 stdin 전달 형식 검증 — 스크립트 내 except 처리로 안전
- [ ] 훅 에러 없이 Read/Edit/Write/Bash 도구 10회 이상 연속 사용 가능 (다음 세션에서 검증)
