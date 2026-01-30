# SPEC.md — Multi-Language Bootstrap Support (Qlty Integration)

> **Status**: `FINALIZED`
>
> **Approved**: 2026-01-30

## Vision

현재 보일러플레이트는 Python 3.12 전용으로 설계되어 있다. 훅, 스킬, 워크플로우 전반에 ruff/mypy/pytest/uv가 하드코딩되어 있어 Node.js, Go, Rust 등 다른 언어 프로젝트에 적용할 수 없다.

[Qlty CLI](https://github.com/qltysh/qlty)를 통합하여 이 문제를 해결한다. Qlty는 70+ 정적 분석 도구와 40+ 언어를 지원하며, `qlty init`으로 프로젝트의 기존 도구를 자동 감지하고, Claude Code와의 [공식 통합 가이드](https://docs.qlty.sh/cli/coding-with-ai-agents)를 제공한다.

부트스트랩에서 **Detect(감지) → Ask(질의) → Confirm(확인)** 플로우를 통해 `qlty init`을 실행하고, 그 결과를 `project-config.yaml`에 저장하여 훅/스킬이 `qlty check` / `qlty fmt`로 통일된 인터페이스를 사용하도록 한다.

## Goals

1. **Qlty CLI 통합** — 부트스트랩에서 `qlty init`을 실행하여 프로젝트의 언어/도구를 자동 감지하고 `.qlty/qlty.toml`을 생성한다
2. **Detect-Ask-Confirm 부트스트랩** — 감지된 언어와 도구를 사용자에게 확인받은 뒤 `project-config.yaml`을 생성한다
3. **통일된 훅 인터페이스** — 훅이 `qlty check` / `qlty fmt`를 호출하여 언어에 무관하게 동작한다
4. **스킬 범용화** — clean, commit, create-pr 등 품질 검사 스킬이 `qlty` 명령어 기반으로 동작한다
5. **기존 설정 존중** — Qlty가 프로젝트의 기존 config 파일(`.eslintrc`, `ruff.toml` 등)을 그대로 활용한다

## Non-Goals (Out of Scope)

- 자체 언어별 도구 감지 로직 구현 (Qlty에 위임)
- code-graph-rag의 다국어 지원 확장 (이미 Tree-sitter 기반으로 40+ 언어 지원)
- Python 스킬 스크립트(11개)를 다른 언어로 재작성하는 것 (별도 검토)
- 모노레포 내 복수 언어 동시 지원 (단일 primary language, 향후 확장)
- Qlty가 지원하지 않는 도구(테스트 러너 등)의 자체 감지 로직

## Constraints

- **하위 호환**: `project-config.yaml` 및 `.qlty/qlty.toml` 미존재 시 현재 Python 기본 동작 유지
- **Qlty 설치 필수**: 부트스트랩에서 Qlty CLI 설치 여부 확인 후 없으면 설치 안내
- **Qlty 라이선스**: Fair Source License — 상용 포함 무료 사용 가능하나 완전 오픈소스는 아님
- **테스트 러너**: Qlty는 린터/포맷터 전문. 테스트 러너(`pytest`, `jest`, `go test`)는 `project-config.yaml`에 별도 기록하여 스킬에서 사용
- **memorygraph 의존**: `pipx install memorygraphMCP`는 Python 필수. 비-Python 환경에서는 선택적 처리

## Architecture

### Qlty의 역할 범위

```
┌─────────────────────────────────────────────┐
│              Qlty CLI 담당                    │
│  ✅ 언어 감지 (40+ languages)                 │
│  ✅ 린터 감지/실행 (70+ tools)                │
│  ✅ 포맷터 실행                               │
│  ✅ 기존 config 파일 활용                      │
│  ✅ Git-aware 변경분 검사                      │
│  ✅ 버전 고정 (.qlty/qlty.toml)               │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         project-config.yaml 담당              │
│  ✅ primary language 기록                     │
│  ✅ 패키지 관리자 정보                         │
│  ✅ 테스트 러너 명령어                         │
│  ✅ 환경 정보 (dependency_dir, extensions)     │
│  ✅ Qlty 통합 여부 플래그                      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│           훅/스킬 담당                        │
│  ✅ 포맷팅: qlty fmt                          │
│  ✅ 린트 검증: qlty check                     │
│  ✅ 테스트: project-config.yaml의 test 명령어  │
│  ✅ 패키지 관리자 가드: project-config.yaml     │
│  ✅ CLAUDE.md 동적 생성                       │
└─────────────────────────────────────────────┘
```

### 명령어 매핑

| 현재 (Python 하드코딩) | Qlty 통합 후 |
|---|---|
| `uv run ruff check .` | `qlty check` |
| `uv run ruff check --fix .` | `qlty check --fix` |
| `uv run ruff format .` | `qlty fmt` |
| `uv run mypy .` | `qlty check` (mypy 플러그인 포함) |
| `uv run pytest tests/` | `project-config.yaml`의 `tools.test_runner.command` |

## Requirements

### R1. Qlty CLI 설치 및 초기화

부트스트랩에서 Qlty CLI 존재 여부를 확인하고, `qlty init`을 실행한다.

**설치 확인:**
```bash
if ! command -v qlty &>/dev/null; then
  # 사용자에게 설치 안내
  # macOS/Linux: curl https://qlty.sh | sh
fi
```

**초기화:**
```bash
qlty init                          # 프로젝트 스캔 → .qlty/qlty.toml 생성
qlty plugins list                  # 활성화된 플러그인 확인
```

**결과**: `.qlty/qlty.toml` 생성 — 감지된 린터/포맷터 플러그인 자동 활성화

### R2. 언어 감지 (Detect Language)

`qlty init` 실행 후 생성된 `.qlty/qlty.toml`과 marker file을 함께 분석하여 언어를 감지한다.

**감지 소스 (우선순위):**
1. `.qlty/qlty.toml`의 활성화된 플러그인에서 언어 추론
   - `eslint` 활성화 → Node.js/TypeScript
   - `ruff` 활성화 → Python
   - `clippy` 활성화 → Rust
   - `golangci-lint` 활성화 → Go
2. Marker file 확인 (보조)
   - `package.json` → Node.js
   - `pyproject.toml` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust

**동작:**
- 단일 언어 감지 → 자동 설정 + 사용자 확인
- 복수 언어 감지 → `AskUserQuestion`으로 primary language 선택
- 미감지 → 사용자에게 언어 직접 입력 요청

### R3. 패키지 관리자 및 테스트 러너 감지

Qlty가 담당하지 않는 영역을 별도 감지한다.

**패키지 관리자 (lockfile 기반):**

| Lockfile | Package Manager |
|---|---|
| `uv.lock` | uv |
| `poetry.lock` | poetry |
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `pnpm-lock.yaml` | pnpm |
| `bun.lockb` | bun |
| `go.sum` | go |
| `Cargo.lock` | cargo |

**테스트 러너 (config file 기반):**

| Config File | Test Runner | 실행 명령어 |
|---|---|---|
| `pyproject.toml` → `[tool.pytest]` | pytest | `uv run pytest tests/` |
| `jest.config.*` / package.json `"jest"` | jest | `npm test` |
| `vitest.config.*` | vitest | `npx vitest` |
| `.mocharc.*` | mocha | `npx mocha` |
| `go.mod` (built-in) | go test | `go test ./...` |
| `Cargo.toml` (built-in) | cargo test | `cargo test` |

### R4. 사용자 확인 (Confirm with User)

감지 결과를 `AskUserQuestion`으로 사용자에게 보여주고 확인받는다.

**질의 흐름:**
```
Step 1: "이 프로젝트는 [Node.js (TypeScript)]로 감지됩니다. 맞습니까?"
        Options: [맞음] [다른 언어]

Step 2: "Qlty가 다음 도구를 감지했습니다:
         - Linter: eslint (eslint.config.mjs)
         - Formatter: prettier (.prettierrc)
         - Type check: tsc (tsconfig.json)

         추가 감지:
         - Test runner: jest (jest.config.js)
         - Package manager: npm (package-lock.json)

         이 설정을 사용하시겠습니까?"
        Options: [그대로 사용] [일부 수정] [직접 설정]
```

### R5. project-config.yaml 생성

감지 결과 + 사용자 확인 + Qlty 정보를 바탕으로 `.gsd/project-config.yaml`을 생성한다.

**스키마:**
```yaml
project:
  name: string                    # 프로젝트명
  primary_language: string        # python | node | go | rust

language:
  name: string
  variant: string | null          # typescript, commonjs, esm 등
  version: string | null

package_manager:
  name: string                    # npm, yarn, pnpm, uv, cargo, go
  lockfile: string
  install: string                 # "npm install"
  add: string                     # "npm install --save"
  run: string                     # "npx"

qlty:
  enabled: true
  config_file: .qlty/qlty.toml
  check_command: "qlty check"
  fix_command: "qlty check --fix"
  format_command: "qlty fmt"

tools:
  # Qlty가 담당하지 않는 영역
  test_runner:
    name: string | null           # jest, pytest, go test, cargo test
    config_file: string | null
    command: string | null         # "npm test", "uv run pytest tests/"

environment:
  dependency_dir: string | null   # node_modules, .venv, target
  dependency_file: string         # package.json, pyproject.toml
  ignore_dirs: string[]
  file_extensions: string[]

_meta:
  generated_by: bootstrap
  generated_at: string
  user_confirmed: boolean
  qlty_version: string
```

### R6. Hook Dispatch (훅 범용화)

훅이 `qlty` 명령어를 사용하여 언어에 무관하게 동작한다.

**대상 훅:**

| 훅 | 현재 | Qlty 통합 후 |
|---|---|---|
| `auto-format-py.sh` → `auto-format.sh` | `.py` 파일만, `ruff format` | `qlty fmt ${FILE_PATH}` |
| `post-turn-verify.sh` | `.py` 파일만, `ruff check` | `qlty check` (변경된 파일 대상) |
| `bash-guard.py` | `pip`/`poetry` 차단 | `project-config.yaml`의 `package_manager.name` 기반 차단 |

**auto-format.sh (개선):**
```bash
#!/bin/bash
set -uo pipefail
INPUT=$(cat)

# Claude Code hook input에서 파일 경로 추출
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Qlty가 설치되어 있으면 qlty fmt 사용
if command -v qlty &>/dev/null; then
  qlty fmt "$FILE_PATH" 2>/dev/null || true
else
  # Fallback: Python 기본 동작 (하위 호환)
  if [[ "$FILE_PATH" == *.py ]]; then
    uv run ruff format "$FILE_PATH" 2>/dev/null || true
    uv run ruff check --fix "$FILE_PATH" 2>/dev/null || true
  fi
fi
exit 0
```

**post-turn-verify.sh (개선):**
```bash
# 변경된 파일에 대해 qlty check 실행
if command -v qlty &>/dev/null; then
  qlty check 2>&1 | head -20
else
  # Fallback: Python 기본 동작
  uv run ruff check --no-fix $CHANGED_FILES 2>&1
fi
```

**Fallback 규칙:**
- `qlty` 명령어 미존재 시 → 현재 Python 기본 동작 유지 (하위 호환)
- `project-config.yaml` 미존재 시 → 현재 Python 기본 동작 유지 (하위 호환)

### R7. 스킬 범용화

품질 검사 관련 스킬이 `qlty` 명령어 기반으로 동작한다.

**대상 스킬:**

| 스킬 | 현재 | Qlty 통합 후 |
|---|---|---|
| `clean` | `ruff check`, `ruff format`, `mypy`, `pytest` | `qlty check --fix`, `qlty fmt`, + `project-config.yaml`의 test 명령어 |
| `commit` | `ruff check`, `mypy`, `pytest` | `qlty check`, + test 명령어 |
| `create-pr` | `ruff`, `mypy`, `pytest` | `qlty check`, + test 명령어 |
| `bootstrap` | Python 환경 (`uv sync`, `.venv`) | `qlty init` + Detect-Ask-Confirm |

**clean 스킬 예시:**
```bash
# Step 1: Qlty lint + fix
qlty check --fix

# Step 2: Qlty format
qlty fmt --all

# Step 3: Test (project-config.yaml에서 읽기)
TEST_CMD=$(grep 'command:' .gsd/project-config.yaml | ... )
eval "$TEST_CMD"
```

### R8. CLAUDE.md 동적 생성

부트스트랩 완료 후 `project-config.yaml` 기반으로 `CLAUDE.md`를 동적 생성한다.

**공통 섹션 (언어 무관):**
```markdown
## Code Quality

**Qlty CLI를 사용한 코드 품질 관리:**

qlty check                       # Lint (all detected linters)
qlty check --fix                 # Lint with auto-fix
qlty fmt                         # Format
qlty fmt --all                   # Format entire project
```

**언어별 섹션 (project-config.yaml 기반):**
```markdown
## Commands

**Package manager: `npm` only. Never use yarn or pnpm.**

npm install                      # Install dependencies
npm test                         # Run tests
```

### R9. JSON 파싱 런타임 추상화

현재 6개 훅이 `python3 -c "import json..."` 사용. `jq`를 우선하고, 없으면 가용 런타임으로 fallback.

**우선순위:**
1. `jq` (가장 경량, 플랫폼 독립)
2. `python3` (Python 프로젝트)
3. `node -e` (Node.js 프로젝트)

## Bootstrap Flow (전체)

```
[/bootstrap 실행]
    │
    ├─ Step 1. Qlty CLI 확인
    │   ├─ 설치됨 → 계속
    │   └─ 미설치 → "Qlty CLI가 필요합니다. 설치하시겠습니까?"
    │              → curl https://qlty.sh | sh
    │
    ├─ Step 2. qlty init
    │   └─ .qlty/qlty.toml 자동 생성
    │      (프로젝트 스캔 → 린터/포맷터 플러그인 활성화)
    │
    ├─ Step 3. 언어 감지 (R2)
    │   ├─ .qlty/qlty.toml 분석 + marker file 확인
    │   └─ AskUserQuestion: "Node.js (TypeScript)로 감지됩니다. 맞습니까?"
    │
    ├─ Step 4. 추가 감지 (R3)
    │   ├─ 패키지 관리자 (lockfile 기반)
    │   └─ 테스트 러너 (config file 기반)
    │
    ├─ Step 5. 사용자 확인 (R4)
    │   └─ AskUserQuestion: 감지 결과 확인
    │
    ├─ Step 6. project-config.yaml 생성 (R5)
    │
    ├─ Step 7. CLAUDE.md 동적 생성 (R8)
    │   └─ qlty 명령어 + 언어별 명령어 반영
    │
    ├─ Step 8. 훅 활성화 (R6)
    │   └─ auto-format.sh, post-turn-verify.sh, bash-guard.py 설정
    │
    └─ Step 9. code-graph-rag 인덱싱
        └─ Tree-sitter가 감지된 언어 자동 처리
```

## Success Criteria

- [x] `qlty init`이 Python 프로젝트에서 `ruff` 플러그인을 자동 감지한다 (mypy는 qlty 미지원 — 별도 처리 필요)
- [x] `qlty init`이 Node.js 프로젝트에서 `eslint`, `prettier` 플러그인을 자동 감지한다 (qlty init 검증 완료 — eslint 자동 감지 확인, prettier는 설정 파일 부재 시 미감지로 정상)
- [ ] 감지 결과가 사용자에게 표시되고, 확인/수정 선택이 가능하다 (부트스트랩 스킬의 AskUserQuestion 플로우 — 스크립트 단위 검증 범위 밖)
- [x] `project-config.yaml`이 생성된다 (qlty 정보 + 패키지 관리자 + 테스트 러너)
- [x] 훅(`auto-format.sh`)이 `qlty fmt`를 호출하여 모든 언어에서 동작한다
- [x] 훅(`post-turn-verify.sh`)이 `qlty check`를 호출하여 모든 언어에서 동작한다
- [x] `clean` 스킬이 `qlty check --fix` + `qlty fmt` + test 명령어를 실행한다 (fallback 경로 Ruff 정상 동작 확인)
- [x] `qlty` 미설치 시 현재 Python 기본 동작을 유지한다 (하위 호환)
- [x] CLAUDE.md에 `qlty` 명령어가 포함된다 (`generate-claude-md.sh` — qlty.enabled 분기 검증됨)

## Implementation Phases

### Phase 1: Qlty 통합 + project-config.yaml
- R1 (Qlty 설치/초기화), R2 (언어 감지), R3 (추가 감지), R4 (사용자 확인), R5 (config 생성)
- 부트스트랩 스킬에 Detect-Ask-Confirm + `qlty init` 플로우 구현

### Phase 2: 훅 범용화
- R6 (Hook Dispatch), R9 (JSON 파싱 런타임)
- `auto-format.sh` (`qlty fmt`), `post-turn-verify.sh` (`qlty check`), `bash-guard.py` 수정

### Phase 3: 스킬 범용화 + CLAUDE.md
- R7 (스킬 범용화), R8 (CLAUDE.md 동적 생성)
- `clean`, `commit`, `create-pr`, `bootstrap` 스킬 수정

## Risks

| 리스크 | 영향 | 완화 |
|---|---|---|
| Qlty CLI 설치 실패 | 부트스트랩 중단 | Fallback으로 현재 Python 동작 유지. 수동 설치 안내 |
| Qlty Fair Source 라이선스 변경 | 사용 제한 가능성 | 현재 무료 사용 가능. 라이선스 모니터링. Fallback 경로 유지 |
| `qlty init` 오감지 | 불필요한 플러그인 활성화 | Step 5 사용자 확인으로 방지. `qlty plugins disable` 가능 |
| 테스트 러너 자체 감지 필요 | Qlty 미지원 영역 | R3에서 별도 감지 로직 구현 (config file 기반) |
| Python 스킬 스크립트 11개 | Node-only 환경에서 실행 불가 | Phase 1-3에서는 미수정. 별도 검토 |
| memorygraph Python 의존 | 비-Python 환경에서 설치 불가 | 부트스트랩에서 선택적 처리 |

## References

- [Qlty CLI GitHub](https://github.com/qltysh/qlty)
- [Qlty + AI Agents 통합 가이드](https://docs.qlty.sh/cli/coding-with-ai-agents)
- [Qlty Analysis Configuration](https://docs.qlty.sh/analysis-configuration)
- [Claude Code Issue #5387](https://github.com/anthropics/claude-code/issues/5387) — 크로스 언어 훅 오류
- [RESEARCH-python-specific-audit.md](.gsd/research/RESEARCH-python-specific-audit.md)
- [RESEARCH-multi-language-support.md](.gsd/research/RESEARCH-multi-language-support.md)
- [RESEARCH-prior-art-multi-language.md](.gsd/research/RESEARCH-prior-art-multi-language.md)

---

*Last updated: 2026-01-30*
