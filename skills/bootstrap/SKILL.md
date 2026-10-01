---
allowed-tools:
- Read
- Write
- Edit
- Bash
- Grep
- Glob
description: Use when .hxsk/.bootstrap-version is missing (fresh install) or exists
  (verify/update) to initialize HExoskeleton.
name: bootstrap
trigger: 프로젝트 초기화, 프로젝트 셋업, 처음 설정, 업데이트, 갱신, project setup, initialize project, after
  cloning, update, refresh, bootstrap 실행, bootstrap.sh, 환경 설정, 시스템 요구사항 확인, prerequisite
  check, fresh install, verify mode, update mode, 멱등성 실행, idempotent setup, .env 생성,
  메모리 초기화, memory init, 프로젝트 준비, project ready, converge, 상태 감지, 상태 확인, 설치 모드 감지,
  bootstrap 실패, bootstrap fail, exit code 1, system prerequisite missing, 필수 요구사항
  누락, codebase mapper 실행, codebase analysis, .hxsk 구조 확인, .hxsk directory check, 메모리
  디렉토리 생성, memory directory create, 상태 보고서 확인, status report, result passed, project
  ready 확인, fresh mode 실행, verify mode 실행, update mode 실행, idempotent convergence,
  수렴 엔진 실행, 환경 변수 복사, env example copy, 메모리 저장 실패, memory store fail, 경고 처리, warn
  handling, 에러 보고, error reporting, 초기 설치 모드, 초기화 모드, 프로젝트 컨텍스트 초기화, project context
  init, 스택 분석, stack analysis, 아키텍처 분석, architecture analysis
version: 5.1.0
---

## Quick Reference
- **실행**: `bash .hxsk/scripts/bootstrap.sh`로 시작 (모드 자동 감지)
- **즉시 중단**: Step 1에서 `[FAIL]` 또는 exit code 1 발생 시
- **경고 진행**: codebase-mapper 실패 (FAIL) 또는 메모리 저장 실패 (WARN) 시 보고까지 계속
- **완료 조건**: 최종 보고서 `RESULT: PASSED` 확인 시 프로젝트 READY
- **확인**: `.hxsk/.bootstrap-version` 파일 생성 여부로 상태 검증

## Iron Laws
- NO BOOTSTRAP EXECUTION WITHOUT STATE DETECTION FIRST
- NO ENVIRONMENT SETUP WITHOUT PREREQUISITE VERIFICATION FIRST
- NO PROCESS TERMINATION WITHOUT ERROR REPORTING FIRST
- NO PROJECT READY DECLARATION WITHOUT FINAL STATUS REPORT FIRST
- NO MEMORY STORAGE FAILURE WITHOUT CONTINUATION TO REPORTING FIRST
- NO PROJECT READY DECLARATION WITHOUT CODEBASE ANALYSIS SUCCESS FIRST

## Procedure

### Step 0: 모드 감지

```bash
test -f .hxsk/.bootstrap-version && echo "EXISTS" || echo "FRESH"
```

- **파일 없음** → 초기 설치 모드. Step 1~7 전체 실행.
- **파일 있음** → `bash .hxsk/scripts/bootstrap.sh` 실행. 스크립트가 자동으로 verify/update 판별.
  - 모든 항목 `[OK]` → 완료
  - `[NEW]`/`[UPDATED]` 있음 → Step 6 (메모리 저장) + Step 7 (보고) 실행

---

### Step 1: System Prerequisites Check

Run the idempotent convergence engine:

```bash
bash .hxsk/scripts/bootstrap.sh
```

**bootstrap.sh v5.1.0 출력 태그:**
- `[NEW]` — 새로 생성된 컴포넌트 (↳ 관련: 2-hop 컨텍스트)
- `[UPDATED]` — 변경 감지된 컴포넌트 (↳ 관련: 2-hop 컨텍스트)
- `[OK]` — 변경 없음, 정상
- `[PASS]` — 시스템 요구사항 충족
- `[FAIL]` — 필수 요구사항 미충족
- `[WARN]` — 선택 요구사항 미충족
- `[SKIP]` — 해당 없음

**If exit code 1:** STOP. Display the failing checks and provide installation instructions.

**If exit code 0:** Continue. `.hxsk/.bootstrap-version` 자동 생성/갱신됨.

---

### Step 2: Environment Setup

Copy `.env.example` to `.env` if `.env` does not already exist:

```bash
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
else
    echo ".env already exists"
fi
```

> bootstrap.sh가 이미 이 작업을 수행합니다. Step 1에서 `[NEW] .env`가 출력되었으면 건너뛰세요.

---

### Step 3: Memory Directory Verification

Verify `.hxsk/memories/` 디렉토리 구조:

```bash
ls .hxsk/memories/ | wc -l  # 14 directories + _schema expected
```

**If missing:** Create directories:
```bash
mkdir -p .hxsk/memories/{architecture-decision,root-cause,debug-eliminated,debug-blocked,health-event,session-handoff,execution-summary,deviation,pattern-discovery,bootstrap,session-summary,session-snapshot,security-finding,general,_schema}
```

> bootstrap.sh가 이미 이 작업을 수행합니다. Step 1에서 `[NEW] .hxsk/memories/`가 출력되었으면 건너뛰세요.

---

### Step 4: Context Structure Initialization

Verify context management structure:

```
.hxsk/
├── reports/           # Analysis reports (REPORT-*.md)
├── research/          # Research documents (RESEARCH-*.md)
├── archive/           # Monthly archives
├── issues/archive/    # Completed issue archive
├── PATTERNS.md        # Core patterns (2KB limit)
└── context-config.yaml # Cleanup rules
```

> bootstrap.sh가 자동 생성합니다.

---

### Step 5: Codebase Analysis

Delegate to the `codebase-mapper` skill to analyze the project:

- `.hxsk/ARCHITECTURE.md`
- `.hxsk/STACK.md`

**If codebase-mapper fails:** Mark FAIL. Continue to Step 6.

---

### Step 6: Memory Storage

Store the bootstrap record:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Project Bootstrap" \
  "Bootstrap completed. System prerequisites verified. Memory initialized." \
  "bootstrap,init,setup" \
  "bootstrap" \
  "bootstrap,init,setup,project" \
  "Initial project bootstrap completed successfully"
```

**If memory store fails:** Mark WARN. Continue to Step 7.

---

### Step 7: Status Report

bootstrap.sh가 이미 구조화된 보고서를 출력합니다:

```
================================================================
 BOOTSTRAP v5.1.0
 MODE: fresh | verify | update (vX.X.X → v5.1.0)
================================================================
...
 MODE: {mode}  |  PASS: N  FAIL: N  WARN: N  SKIP: N  NEW: N  UPDATED: N
 RESULT: ALL REQUIRED CHECKS PASSED / FAILED
================================================================
```

**RESULT = PASSED** → 프로젝트 READY.
**RESULT = FAILED** → NEEDS ATTENTION.

---

## Error Handling

| Error | Action |
|-------|--------|
| System prerequisite missing | STOP at Step 1. Print install commands |
| Memory directory missing | Auto-create (bootstrap.sh handles) |
| Schema files missing | Copy from templates or create minimal versions |
| codebase-mapper fails | FAIL the step, continue |
| Memory store fails | WARN the step, continue |

---

## Scripts

- `.hxsk/scripts/bootstrap.sh`: Idempotent convergence engine (fresh/verify/update 3-mode)
- `.hxsk/scripts/detect-language.sh`: Language, package manager detection functions (optional)