# RESEARCH: Multi-Language Support Feasibility Analysis

> **Date**: 2026-01-30
> **Purpose**: 보일러플레이트를 Python 전용에서 다국어(Node.js, Go, Rust 등) 지원으로 확장하기 위한 실현 가능성 분석
> **Prerequisite**: [RESEARCH-python-specific-audit.md](./RESEARCH-python-specific-audit.md)

---

## 1. 현재 상태 요약

### 1.1 이미 다국어를 지원하는 부분

| 컴포넌트 | 다국어 지원 현황 |
|---|---|
| **code-graph-rag** | Tree-sitter 기반 — 40+ 언어 자동 감지/인덱싱 |
| `scan_structure.sh` | `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.rs`, `.go`, `.java` LOC 카운팅 |
| `collect_diagnostics.sh` | `python3`, `node`, `cargo`, `go`, `java` 런타임 감지 |
| `codebase-mapper/SKILL.md` | `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod` 프로젝트 타입 감지 |
| `analyze_diff.py` | `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod` 의존성 파일 인식 |

### 1.2 Python 전용으로 하드코딩된 부분

- **품질 검사**: ruff, mypy, pytest (clean, commit, create-pr, quick-check)
- **자동 포맷팅 훅**: `.py` 파일만 대상 (auto-format-py.sh)
- **Import 분석**: Python regex 패턴만 (analyze_imports.py, find_dependents.py)
- **패키지 관리자 가드**: pip/poetry 차단만 (bash-guard.py)
- **환경 설정**: .venv, pyproject.toml, uv (bootstrap, CLAUDE.md, Makefile)

---

## 2. 제안 아키텍처

### 2.1 핵심 원칙: "감지 → 질의 → 확인" (Detect-Ask-Confirm)

기존 접근법(보일러플레이트가 언어별 도구 프리셋을 정의)의 문제점:
- 대상 프로젝트에는 **이미 자체 린트/포맷/테스트 설정이 존재**
- 보일러플레이트가 도구를 강제하면 기존 설정과 **충돌**
- 새 언어마다 프리셋을 유지관리해야 하는 **부담**

**개선된 원칙**: 대상 프로젝트의 기존 설정을 감지하고, 사용자에게 확인받는다.

| 기존 접근 | 개선 접근 |
|---|---|
| 보일러플레이트가 도구 프리셋 정의 | 대상 프로젝트의 **기존 설정 감지** |
| `ruff`, `eslint` 등 도구를 직접 지정 | 프로젝트에 이미 있는 도구를 **발견하여 사용** |
| 새 언어마다 프리셋 추가 필요 | config 파일 감지 패턴만 추가하면 됨 |

### 2.2 부트스트랩 플로우 (개선안)

```
[Bootstrap Start]
    │
    ├─ Step 1. 언어 감지 (Detect Language)
    │   ├─ Marker file 스캔:
    │   │   pyproject.toml → Python
    │   │   package.json → Node.js
    │   │   go.mod → Go
    │   │   Cargo.toml → Rust
    │   │   *.csproj → .NET
    │   │
    │   └─ 사용자 질의 (AskUserQuestion):
    │       "이 프로젝트는 Node.js(TypeScript)로 감지됩니다. 맞습니까?"
    │       (복수 언어 감지 시 primary language 선택)
    │
    ├─ Step 2. 기존 도구 설정 감지 (Detect Existing Tooling)
    │   ├─ Config 파일 스캔:
    │   │   .eslintrc.* / eslint.config.* → linter: eslint
    │   │   .prettierrc* / prettier.config.* → formatter: prettier
    │   │   jest.config.* / vitest.config.* → test_runner: jest/vitest
    │   │   tsconfig.json → type_checker: tsc
    │   │   (Python: pyproject.toml [tool.ruff] → linter: ruff, 등)
    │   │   (Go: .golangci.yml → linter: golangci-lint)
    │   │   (Rust: Cargo.toml → linter: clippy)
    │   │
    │   └─ package.json scripts 분석 (Node.js):
    │       "lint": "eslint ." → linter 명령어 추출
    │       "test": "jest" → test 명령어 추출
    │       "format": "prettier --write ." → formatter 명령어 추출
    │
    ├─ Step 3. 사용자 확인 (Confirm with User)
    │   └─ AskUserQuestion:
    │       "다음 도구 설정이 감지되었습니다:
    │        - Linter: eslint (.eslintrc.js)
    │        - Formatter: prettier (.prettierrc)
    │        - Test: jest (jest.config.js)
    │        - Type check: tsc (tsconfig.json)
    │        - Package manager: npm (package-lock.json)
    │        이 설정을 사용하시겠습니까?"
    │       Options: [그대로 사용] [일부 수정] [직접 설정]
    │
    ├─ Step 4. project-config.yaml 생성
    │   └─ 감지 결과 + 사용자 확인을 바탕으로 config 파일 자동 생성
    │
    ├─ Step 5. CLAUDE.md 동적 생성
    │   └─ project-config.yaml 기반으로 언어별 명령어/규칙 반영
    │
    ├─ Step 6. 훅 활성화
    │   └─ config에 정의된 도구만 훅에서 실행
    │
    └─ Step 7. 코드베이스 인덱싱 (code-graph-rag)
```

### 2.3 도구 감지 매트릭스

부트스트랩이 스캔해야 할 config 파일 목록:

#### Language Detection (Step 1)

| Marker File | Language | 비고 |
|---|---|---|
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | |
| `package.json` | Node.js | `tsconfig.json` 있으면 TypeScript |
| `go.mod` | Go | |
| `Cargo.toml` | Rust | |
| `*.csproj`, `*.sln` | .NET / C# | |
| `pom.xml`, `build.gradle` | Java / Kotlin | |

#### Tool Detection (Step 2)

**Node.js / TypeScript:**

| Config File Pattern | Tool | Role |
|---|---|---|
| `.eslintrc.*`, `eslint.config.*`, `eslint.config.mjs` | ESLint | linter |
| `.prettierrc*`, `prettier.config.*` | Prettier | formatter |
| `jest.config.*`, `jest` in package.json | Jest | test_runner |
| `vitest.config.*` | Vitest | test_runner |
| `mocha` in package.json, `.mocharc.*` | Mocha | test_runner |
| `tsconfig.json` | TypeScript Compiler | type_checker |
| `biome.json`, `biome.jsonc` | Biome | linter + formatter |

**Python:**

| Config File Pattern | Tool | Role |
|---|---|---|
| `pyproject.toml` → `[tool.ruff]` | Ruff | linter + formatter |
| `pyproject.toml` → `[tool.mypy]`, `mypy.ini` | mypy | type_checker |
| `pyproject.toml` → `[tool.pytest]`, `pytest.ini` | pytest | test_runner |
| `.flake8`, `setup.cfg` → `[flake8]` | Flake8 | linter (legacy) |
| `pyproject.toml` → `[tool.black]` | Black | formatter (legacy) |

**Go:**

| Config File Pattern | Tool | Role |
|---|---|---|
| `.golangci.yml`, `.golangci.yaml` | golangci-lint | linter |
| (built-in) | gofmt | formatter |
| (built-in) | go test | test_runner |

**Rust:**

| Config File Pattern | Tool | Role |
|---|---|---|
| `Cargo.toml` | clippy | linter |
| `rustfmt.toml`, `.rustfmt.toml` | rustfmt | formatter |
| (built-in) | cargo test | test_runner |

#### Package Manager Detection

| Lockfile / Marker | Package Manager |
|---|---|
| `uv.lock` | uv (Python) |
| `poetry.lock` | poetry (Python) |
| `Pipfile.lock` | pipenv (Python) |
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `pnpm-lock.yaml` | pnpm |
| `bun.lockb` | bun |
| `go.sum` | go mod |
| `Cargo.lock` | cargo |

### 2.4 project-config.yaml 스키마 (감지 결과 저장)

```yaml
# .gsd/project-config.yaml
# 부트스트랩이 감지 + 사용자 확인을 거쳐 자동 생성
# 이후 훅/스킬이 이 파일을 읽어서 도구 디스패치

project:
  name: "my-node-project"        # package.json name 또는 디렉토리명
  primary_language: node          # 감지된 주 언어
  detected_languages: [node, typescript]  # 감지된 모든 언어

language:
  name: node
  variant: typescript             # optional: typescript, commonjs, esm 등
  version: "12"                   # package.json engines 또는 .nvmrc

package_manager:
  name: npm                       # 감지된 패키지 관리자
  lockfile: package-lock.json     # 감지 근거
  install: "npm install"          # 전체 의존성 설치
  add: "npm install --save"       # 새 패키지 추가
  run: "npx"                      # 스크립트/바이너리 실행

tools:
  linter:
    name: eslint
    config_file: .eslintrc.js     # 감지된 설정 파일
    command: "npx eslint"         # 실행 명령어
    fix_command: "npx eslint --fix"
  formatter:
    name: prettier
    config_file: .prettierrc
    command: "npx prettier --write"
  type_checker:
    name: tsc
    config_file: tsconfig.json
    command: "npx tsc --noEmit"
  test_runner:
    name: jest
    config_file: jest.config.js
    command: "npm test"

environment:
  dependency_dir: node_modules    # Python: .venv, Rust: target
  dependency_file: package.json   # Python: pyproject.toml
  ignore_dirs:                    # .gitignore + 훅/스킬에서 제외할 디렉토리
    - node_modules
    - dist
    - build
    - coverage
    - .cache
  file_extensions: [.js, .jsx, .ts, .tsx, .mjs, .cjs]

# 감지 메타데이터
_meta:
  generated_by: bootstrap
  generated_at: "2026-01-30T10:00:00Z"
  detection_confidence: high      # high/medium/low
  user_confirmed: true            # 사용자가 Step 3에서 확인했는지
```

---

## 3. 수정 대상 파일 분석

### 3.1 Critical (다국어 지원의 전제 조건)

| 파일 | 작업 | 난이도 |
|---|---|---|
| `.gsd/project-config.yaml` | **신규 생성** — 언어 설정 스키마 | Medium |
| `scripts/detect-language.sh` | **신규 생성** — marker file 기반 감지 | Low |
| `.claude/hooks/auto-format-py.sh` | **리네임 + 수정** → `auto-format.sh` (확장자별 라우팅) | Low |
| `.claude/hooks/post-turn-verify.sh` | **수정** — 다국어 파일 감지 + 린터 라우팅 | Medium |
| `.claude/hooks/bash-guard.py` | **수정** — config 기반 패키지 관리자 차단 | Low |
| `.claude/skills/clean/scripts/run_quality_checks.sh` | **대폭 수정** — config에서 도구 명령어 읽기 | High |
| `Makefile` | **수정** — lint/test/typecheck 타겟 config 기반 디스패치 | Medium |
| `.claude/settings.json` | **수정** — 훅 파일명 변경 반영 | Low |

### 3.2 High Priority (스킬/워크플로우)

| 파일 | 작업 | 난이도 |
|---|---|---|
| `.claude/skills/bootstrap/SKILL.md` | **수정** — 언어 감지 + config 생성 플로우 | High |
| `.claude/skills/clean/SKILL.md` | **수정** — 추상화된 도구 참조 | Medium |
| `.claude/skills/commit/SKILL.md` | **수정** — pre-commit 도구 config 기반 | Medium |
| `.agent/workflows/bootstrap.md` | **수정** — 다국어 부트스트랩 플로우 | High |
| `.agent/workflows/quick-check.md` | **수정** — 언어별 검증 명령어 | Medium |
| `CLAUDE.md` | **템플릿화** — 또는 동적 생성 | Medium |

### 3.3 Medium Priority (Python 전용 스크립트 범용화)

| 파일 | 작업 | 난이도 |
|---|---|---|
| `analyze_imports.py` | **확장** — 언어별 import regex 추가 | High |
| `find_dependents.py` | **확장** — 다국어 의존성 탐지 | High |
| `find_circular_imports.py` | **확장** — 다국어 순환 의존성 | High |
| `check_complexity.sh` | **확장** — 언어별 복잡도 도구 | Medium |
| `detect_stubs.py` | **확장** — 다국어 stub 탐지 패턴 | Medium |

### 3.4 Low Priority (문서/설정)

| 파일 | 작업 |
|---|---|
| `.gitignore` | 다국어 아티팩트 추가 (node_modules, target, vendor 등) |
| `.vscode/settings.json` | 언어별 확장 설정 |
| `.gsd/STACK.md` | config 기반 동적 생성 |
| `.gsd/ARCHITECTURE.md` | 범용 구조 문서 |

---

## 4. 핵심 과제

### 4.1 실현 가능 (Feasible)

| 항목 | 근거 |
|---|---|
| **언어 감지** | marker file 기반 — 이미 `codebase-mapper`에 부분 구현 |
| **훅 범용화** | 파일 확장자 라우팅은 단순한 case/switch |
| **config 스키마** | YAML 기반 — 기존 `context-config.yaml` 패턴 재사용 |
| **code-graph-rag** | Tree-sitter가 이미 40+ 언어 지원 |
| **패키지 관리자 가드** | config에서 허용 목록 읽기 |

### 4.2 도전적 (Challenging)

| 항목 | 이유 |
|---|---|
| **Import 분석 범용화** | 언어마다 import 문법이 근본적으로 다름 (Python `from X import Y` vs Go `import "pkg"` vs Rust `use crate::module`) |
| **도구 출력 파싱** | ruff JSON vs eslint JSON vs golangci-lint JSON — 포맷이 다름 |
| **환경 검증** | Python `.venv` vs Node `node_modules` vs Go (없음) vs Rust `target` — 각각 다른 검증 로직 |
| **CLAUDE.md 동적 생성** | 템플릿 엔진 필요 (또는 셸 스크립트 기반 생성) |
| **복수 언어 프로젝트** | 모노레포에서 Python + TypeScript 혼합 시 훅/린터 공존 |

### 4.3 제약 사항

| 항목 | 설명 |
|---|---|
| **JSON 파싱에 python3 사용** | 6개 셸 훅이 `python3 -c "import json..."` 사용 — Node.js 환경에서는 `python3`이 없을 수 있음 → `jq` 또는 `node -e` 대체 필요 |
| **memorygraph 설치** | `pipx install memorygraphMCP` — Python 필수 의존 → 별도 설치 방안 필요 |
| **Python 스크립트 11개** | 스킬 스크립트가 Python으로 작성 — 대상 프로젝트에 Python 없으면 실행 불가 |

---

## 5. 전략 제안

### 접근법 D: Detect-Ask-Confirm (권장, 개선안)

**원칙**: 대상 프로젝트의 기존 설정을 감지하고, 사용자에게 확인받아 config를 생성한다.
보일러플레이트는 도구를 강제하지 않고, 프로젝트가 이미 사용하는 도구를 존중한다.

```
대상 프로젝트 config 파일 스캔
  → 도구 자동 감지 (eslint, prettier, jest, ...)
  → 사용자 확인 질의
  → project-config.yaml 생성
  → 훅/스킬이 config 읽어서 디스패치
```

**장점**:
- 대상 프로젝트의 기존 설정과 **충돌 없음**
- 보일러플레이트가 언어별 프리셋을 유지관리할 **필요 없음**
- 사용자가 최종 확인하므로 **오감지 방지**
- 점진적 도입 가능 (감지 패턴만 추가)

**단점**:
- config 파일 감지 패턴을 언어/도구별로 정의해야 함
- YAML 파싱에 추가 의존성 (`yq` 또는 런타임별 파서)
- 도구가 아예 없는 신규 프로젝트는 감지할 것이 없음 → fallback 필요

**Fallback 전략 (도구 미설정 프로젝트)**:
```
감지 결과 없음
  → "린터/포맷터가 감지되지 않았습니다. 설정하시겠습니까?"
  → [추천 도구 제안] / [건너뛰기]
  → 추천 시: 언어별 기본 도구 안내 (Node→eslint+prettier, Python→ruff, Go→golangci-lint)
```

### 이전 접근법 (참고용)

<details>
<summary>접근법 A: Config-Driven Dispatch (초기안)</summary>

**원칙**: 기존 구조 유지 + 보일러플레이트가 정의한 프리셋으로 도구 디스패치

**문제점**: 대상 프로젝트에 이미 자체 설정이 있을 경우 충돌. 새 언어마다 프리셋 유지 부담.
</details>

<details>
<summary>접근법 B: Language Plugin System (초기안)</summary>

**원칙**: 언어별 디렉토리에 도구 설정을 분리 (`./claude/languages/python/`, `node/`, ...)

**문제점**: 대규모 리팩토링 필요, 파일 수 대폭 증가. 프로젝트 기존 설정과 이중 관리.
</details>

---

## 6. 우선순위 구현 로드맵

### Phase 1: 감지 인프라 (Detection Infrastructure)
- `project-config.yaml` 스키마 정의
- 부트스트랩 스킬에 **Detect-Ask-Confirm** 플로우 구현
  - Step 1: marker file 기반 언어 감지 + 사용자 질의
  - Step 2: config 파일 기반 도구 감지 (감지 매트릭스 2.3절 참고)
  - Step 3: 감지 결과 사용자 확인
  - Step 4: `project-config.yaml` 자동 생성

### Phase 2: 훅 범용화 (Hooks)
- `auto-format-py.sh` → `auto-format.sh` (project-config.yaml 읽어서 디스패치)
- `post-turn-verify.sh` — config 기반 린터 실행
- `bash-guard.py` — config 기반 패키지 관리자 차단
- JSON 파싱: `python3` → `jq` 또는 조건부 런타임 선택

### Phase 3: 스킬 범용화 (Skills)
- `clean` 스킬: config 기반 도구 실행
- `commit` 스킬: config 기반 pre-commit 검증
- `bootstrap` 스킬: 전체 Detect-Ask-Confirm 플로우

### Phase 4: 분석 도구 범용화 (Analysis)
- `analyze_imports.py`: config의 `import_pattern` 활용 또는 code-graph-rag 위임
- `find_dependents.py`: code-graph-rag `analyze_code_impact` 활용 (이미 다국어 지원)
- `check_complexity.sh`: 언어별 복잡도 도구 (config 기반)

### Phase 5: 문서/템플릿 (Documentation)
- CLAUDE.md 동적 생성 (project-config.yaml 기반)
- Makefile config 기반 타겟
- .gsd 문서 범용화

---

## 7. Node.js 12 프로젝트 적용 시나리오

### 가정: 기존 Node 12 프로젝트에 eslint + mocha 설정이 이미 존재

```
1. 사용자가 Node 12 프로젝트 디렉토리에서 /bootstrap 실행

2. [Step 1] 언어 감지:
   - package.json 발견 → Node.js
   - package-lock.json 발견 → npm
   - tsconfig.json 없음 → JavaScript (CommonJS)
   → 질의: "Node.js (JavaScript) 프로젝트로 감지됩니다. 맞습니까?"
   → 사용자: "맞음"

3. [Step 2] 기존 도구 설정 감지:
   - .eslintrc.json 발견 → linter: eslint
   - .prettierrc 없음 → formatter: 미감지
   - .mocharc.yml 발견 → test_runner: mocha
   - tsconfig.json 없음 → type_checker: 없음
   - package.json scripts:
     "lint": "eslint src/" → linter command 확인
     "test": "mocha --recursive" → test command 확인

4. [Step 3] 사용자 확인:
   → "다음 도구 설정이 감지되었습니다:
      - Linter: eslint (.eslintrc.json)
      - Formatter: (미감지)
      - Test: mocha (.mocharc.yml)
      - Type check: (없음)
      - Package manager: npm (package-lock.json)
      이 설정을 사용하시겠습니까?"
   → 사용자: "그대로 사용"

5. [Step 4] project-config.yaml 생성:
   language.name: node
   language.variant: commonjs
   package_manager.name: npm
   tools.linter: { name: eslint, command: "npx eslint", config: .eslintrc.json }
   tools.formatter: null
   tools.test_runner: { name: mocha, command: "npm test", config: .mocharc.yml }
   tools.type_checker: null

6. [Step 5] CLAUDE.md 동적 생성:
   "Package manager: npm only."
   "npm install / npm test / npx eslint ."

7. [Step 6] 훅 활성화:
   - auto-format.sh: formatter 미설정 → .js 파일 포맷팅 훅 비활성화
   - post-turn-verify.sh: eslint로 린트 검증
   - bash-guard: yarn/pnpm 차단, npm만 허용

8. [Step 7] code-graph-rag 인덱싱 (Tree-sitter가 .js 자동 처리)
```

**주요 고려사항 (Node 12)**:
- ES Modules 미지원 (CommonJS만) → import 패턴: `require()` 우선
- `npx` 사용 가능 (npm 5.2+, Node 12에 포함)
- TypeScript 유무에 따라 type_checker 활성화 결정
- 도구 미감지 항목(formatter)은 훅에서 해당 기능 비활성화

---

## 8. 결론

| 관점 | 평가 |
|---|---|
| **실현 가능성** | **높음** — 핵심 인프라(code-graph-rag)가 이미 다국어 지원 |
| **수정 범위** | **대규모** — 30+ 파일, 200+ 개소 |
| **권장 접근법** | **D (Detect-Ask-Confirm)** — 대상 프로젝트 기존 설정 감지 + 사용자 확인 |
| **최우선 작업** | 부트스트랩에 Detect-Ask-Confirm 플로우 + project-config.yaml 스키마 |
| **주요 리스크** | Python 스크립트 11개가 `python3` 런타임 필요 — Node-only 환경에서 실행 불가 |
| **핵심 차별점** | 도구를 강제하지 않고, 프로젝트가 이미 사용하는 도구를 존중 |

---

*Generated: 2026-01-30*
*Updated: 2026-01-30 (Detect-Ask-Confirm 접근법 반영)*
*Related: [RESEARCH-python-specific-audit.md](./RESEARCH-python-specific-audit.md)*
