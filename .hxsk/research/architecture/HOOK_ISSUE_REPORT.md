# Claude Code Hook 문제 보고서

**작성일**: 2026-02-10
**환경**: macOS Darwin 24.5.0, Claude Code (Opus 4.6)
**플러그인**: GSD v1.8.0, Hookify (claude-plugins-official)

---

## 1. 증상 요약

세션 중반부터 **모든 Bash 도구 호출이 `Exit code 1`로 실패**하며, 에러 메시지 없이 무조건 실패함.
Read, Write, Glob, Grep 등 다른 도구는 정상 동작.

```
# 이 시점 이후 모든 Bash가 실패
Bash: pwd         → Exit code 1 (출력 없음)
Bash: echo test   → Exit code 1 (출력 없음)
Bash: true        → Exit code 1 (출력 없음)
Bash: /bin/ls     → Exit code 1 (출력 없음)

# 반면 다른 도구는 정상
Read: /Users/.../README.md  → 정상 읽기
Glob: *.py                  → 정상 검색
```

---

## 2. 근본 원인 분석

### 2.1 직접 원인: 삭제된 CWD (Working Directory)

Bash 도구의 핵심 특성:
> "Working directory persists between commands; shell state (everything else) does not."

**발생 경과:**

```
[정상] cd /tmp/autorag-verify && uv sync       # CWD → /tmp/autorag-verify
[정상] cd /tmp/autorag-verify && uv run ...     # 검증 작업 수행
[정상] rm -rf /tmp/autorag-verify               # ← 이 시점에서 CWD 디렉토리 삭제
[실패] echo test                                 # CWD가 존재하지 않아 쉘 시작 자체 실패
```

Read 도구의 에러 메시지에서 확인:
```
Current working directory: /private/tmp/autorag-verify
```

macOS에서 `/tmp`는 `/private/tmp`의 심볼릭 링크이므로, 삭제된 `/private/tmp/autorag-verify`가 CWD로 남아 있음.

**결론**: Bash 도구는 매 실행마다 새 쉘을 생성하면서 "저장된 CWD"로 이동하려 하지만, 해당 디렉토리가 삭제되어 쉘 초기화 자체가 실패. `cd /valid/path && ...` 패턴도 실패하는 이유는 쉘이 시작 전에 CWD 설정 단계에서 먼저 실패하기 때문.

### 2.2 복구 불가 이유

- Bash 도구 내에서 `cd`를 시도해도 쉘 시작 자체가 CWD 설정에서 실패하므로 명령이 도달하지 않음
- Claude Code의 CWD 상태를 리셋하는 방법이 세션 내에 없음
- **세션을 새로 시작하는 것만이 유일한 복구 방법**

---

## 3. Hook 시스템 구조 분석

### 3.1 등록된 Hook 체인 (GSD 플러그인)

| 이벤트 | 스크립트 | 타임아웃 | 역할 |
|--------|---------|---------|------|
| **SessionStart** | `session-start.sh` | 10s | 세션 초기화 |
| **PreToolUse (Edit\|Write\|Read)** | `file-protect.py` | 5s | 민감 파일 보호 (.env, .pem 등) |
| **PreToolUse (Bash)** | `bash-guard.py` | 5s | 파괴적 명령 차단 |
| **PostToolUse (Edit\|Write)** | `auto-format.sh` | 30s | 소스 자동 포맷 (ruff 등) |
| **PostToolUse (Edit\|Write)** | `track-modifications.sh` | 2s | 수정 플래그 설정 |
| **PostToolUse (Bash)** | `track-modifications.sh` | 2s | 수정 플래그 설정 |
| **PreCompact** | `pre-compact-save.sh` | 10s | 컴팩트 전 상태 저장 |
| **Stop** | `post-turn-index.sh` | 10s | code-graph-rag 인덱싱 (cache 버전만) |
| **Stop** | `post-turn-verify.sh` | 15s | lint/품질 검사 |
| **Stop** | `stop-context-save.sh` | 10s | CURRENT.md 생성 + 메모리 저장 |
| **SubagentStop** | (prompt) | - | 서브에이전트 완료 안내 |
| **SessionEnd** | `save-transcript.sh` | 10s | 대화 기록 저장 |
| **SessionEnd** | `save-session-changes.sh` | 10s | 변경사항 저장 |

추가로 **Hookify** 플러그인이 모든 이벤트에서 `.claude/hookify.*.local.md` 규칙을 평가하는 래퍼 훅을 등록 (pretooluse.py, posttooluse.py, stop.py).

### 3.2 Stop Hook 상세 분석

#### `post-turn-index.sh` (캐시 버전에만 존재)
- `git status --porcelain`으로 코드 변경 감지
- 변경 있으면 `npx @er77/code-graph-rag-mcp index` 백그라운드 실행
- **문제점**: `npx` 호출은 네트워크 의존적이며, 패키지 미설치 시 매번 다운로드 시도

#### `post-turn-verify.sh`
- 변경된 소스 파일에 CRLF → LF 변환
- `qlty check` 또는 `uv run ruff check` 실행
- **문제점**: `set -uo pipefail` 사용. 미정의 변수가 있으면 스크립트 자체가 실패할 수 있지만, 마지막에 `exit 0`으로 강제 종료

#### `stop-context-save.sh`
- `.gsd/.modified-this-session` 플래그 있을 때만 실행
- `claude -p` (haiku 모델)로 CURRENT.md 생성
- `mcp-store-memory.sh`로 메모리 서비스에 저장
- **문제점**: 백그라운드 서브프로세스에서 `claude -p` 호출 — 재귀적 Claude 호출이 예상치 못한 부하/지연 유발 가능

---

## 4. 세션 중 발생한 Hook 관련 이슈 목록

### 이슈 #1: `.env.example` 쓰기 차단
```
PreToolUse:Write hook error: [file-protect.py]
Blocked: path contains '.env' — protected file/directory.
```
- **원인**: `file-protect.py`가 `.env` 패턴을 포함하는 모든 경로를 차단
- **영향**: `.env.example` (비밀값 미포함 템플릿)도 생성 불가
- **패턴 범위 과도**: `.env.example`, `.env.sample`, `.env.template` 등 안전한 파일까지 차단

### 이슈 #2: Bash 도구 완전 마비 (본 보고서 주요 이슈)
- **원인**: CWD가 삭제된 임시 디렉토리를 가리킴
- **영향**: 이후 모든 Bash 명령 실행 불가, zip 파일 재생성 불가
- **복구**: 세션 재시작만 가능

---

## 5. 설계 취약점 및 개선 제안

### 5.1 Bash 도구 CWD 복원 메커니즘 부재

**현재**: CWD가 유효하지 않으면 복구 방법 없음
**제안**:
- Bash 도구가 CWD 접근 실패 시 프로젝트 루트(`CLAUDE_PROJECT_DIR`)로 자동 폴백
- 또는 `cd`가 포함된 명령이면 CWD 무관하게 실행 허용

### 5.2 file-protect.py 패턴 매칭 과도

**현재**: `".env"` 문자열이 경로에 포함되기만 하면 차단
```python
BLOCKED_PATTERNS = [".env", ...]  # "path contains '.env'"
```
**제안**:
- `.env.example`, `.env.sample`, `.env.template` 등은 허용 목록(allowlist)에 추가
- 또는 정확한 파일명 매칭만 차단하고, 패턴 매칭은 제거

### 5.3 Stop Hook 과부하

**현재**: 매 턴 종료 시 최대 3개의 셸 스크립트가 실행되며, 그 중 하나는 `claude -p`로 하위 모델을 재귀 호출
**제안**:
- `stop-context-save.sh`의 `claude -p` 호출을 일정 간격(예: 5분)으로 제한
- `post-turn-index.sh`의 `npx` 호출을 로컬 설치 체크 후에만 실행
- 모든 Stop 훅에 실패 로깅 추가 (현재 stdout/stderr가 사용자에게 보이지 않음)

### 5.4 프로젝트-레벨 vs 캐시-레벨 Hook 불일치

**현재**:
- 캐시 버전: `post-turn-index.sh` + `post-turn-verify.sh` + `stop-context-save.sh` (3개)
- 프로젝트 버전: `post-turn-verify.sh` + `stop-context-save.sh` (2개)

동일 플러그인(GSD)인데 등록된 Stop 훅 수가 다름. 어떤 것이 실제로 실행되는지 불명확.

---

## 6. 즉시 조치 사항

1. **세션 재시작**으로 Bash CWD 문제 해결
2. 재시작 후 아래 명령으로 zip 재생성:
   ```bash
   cd /Users/sukbeom/Desktop/autorag && \
   zip -r /Users/sukbeom/Desktop/autorag-benchmark.zip . \
     -x '.venv/*' '.git/*' '.mypy_cache/*' '.gsd/*' \
     '.sessions/*' '.claude/*' '*.DS_Store' \
     '*_executed.ipynb' '*.pyc'
   ```

---

## 7. 참조 파일 경로

| 파일 | 역할 |
|------|------|
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/hooks/hooks.json` | GSD 훅 등록 (캐시) |
| `<project>/.claude/plugins/gsd/hooks/hooks.json` | GSD 훅 등록 (프로젝트) |
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/scripts/bash-guard.py` | Bash 명령 차단 |
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/scripts/file-protect.py` | 파일 보호 |
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/scripts/post-turn-verify.sh` | Stop: lint 검사 |
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/scripts/post-turn-index.sh` | Stop: 코드 인덱싱 |
| `~/.claude/plugins/cache/gsd-local/gsd/1.8.0/scripts/stop-context-save.sh` | Stop: 컨텍스트 저장 |
| `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/hookify/` | Hookify 규칙 엔진 |
