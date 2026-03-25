# RESEARCH: Prior Art — Multi-Language Detection & Quality Tools

> **Date**: 2026-01-30
> **Purpose**: 다국어 프로젝트 감지 및 품질 도구 자동 설정을 이미 구현한 프로젝트/도구 조사
> **Context**: SPEC.md (Multi-Language Bootstrap Support) 작성 전 선행 사례 조사

---

## 1. 범용 다국어 품질 도구 (가장 관련도 높음)

### 1.1 Trunk.io — `trunk init`

- **GitHub**: [trunk-io/trunk-action](https://github.com/trunk-io/trunk-action)
- **Docs**: [docs.trunk.io/references/cli/getting-started](https://docs.trunk.io/references/cli/getting-started)
- **핵심 기능**: `trunk init` 실행 시 프로젝트를 스캔하여 `.trunk/trunk.yaml` 자동 생성
- **감지 방식**: 코드베이스의 파일 타입/config 파일을 분석하여 적합한 린터/포맷터/보안 분석기 활성화
- **세밀한 제어**:
  - `--only-detected-formatters`: 이미 사용 중인 포맷터만 활성화
  - `--only-detected-linters`: 이미 사용 중인 린터만 활성화
- **버전 고정**: `.trunk/trunk.yaml`에 Trunk 버전 고정 → 팀 전체 동일 결과
- **Single-player mode**: `trunk init --single-player-mode` — 팀 롤아웃 전 개인 사용

**우리 프로젝트와의 관련성**: ★★★★★
- `trunk init`의 "프로젝트 스캔 → config 자동 생성" 패턴이 우리의 Detect-Ask-Confirm과 거의 동일
- `--only-detected-*` 플래그가 "기존 설정 존중" 원칙과 일치
- **차이점**: Trunk은 자체 런타임으로 린터 실행, 우리는 프로젝트의 기존 도구를 그대로 사용

---

### 1.2 Qlty CLI — `qlty init`

- **GitHub**: [qltysh/qlty](https://github.com/qltysh/qlty) (★ 다수)
- **Docs**: [docs.qlty.sh/analysis-configuration](https://docs.qlty.sh/analysis-configuration)
- **핵심 기능**: `qlty init` 실행 시 파일 타입과 config 파일을 스캔하여 `.qlty/qlty.toml` 자동 생성
- **지원 범위**: 70+ 정적 분석 도구, 40+ 언어
- **플러그인 구조**: 60+ 린터 플러그인, 20,000+ 코드 품질 규칙
- **기존 설정 활용**: 플러그인은 자체 config 파일(`.eslintrc` 등)을 사용. `.qlty/configs/` 디렉토리에 저장 가능
- **특징**: Docker 미사용 (네이티브 바이너리), Git-aware (변경분만 검사), Fair Source 라이선스

**우리 프로젝트와의 관련성**: ★★★★☆
- "init 시 기존 config 파일 감지 → 설정 자동 생성" 패턴 동일
- 기존 린터 config 파일을 그대로 활용하는 점이 우리 접근법과 일치
- **차이점**: Qlty는 독립 CLI 도구, 우리는 Claude Code 플러그인/부트스트랩

---

### 1.3 GitHub Super-Linter

- **GitHub**: [super-linter/super-linter](https://github.com/super-linter/super-linter) (★ 매우 많음)
- **핵심 기능**: 언어 자동 감지 → 해당 린터 자동 실행
- **감지 방식**: 파일 확장자 기반 자동 감지. `VALIDATE_[LANGUAGE]` 환경변수로 제어
- **Fix mode**: `FIX_<language>` 변수로 자동 수정 활성화
- **Config 활용**: `.github/linters/` 디렉토리에 커스텀 규칙 파일 배치 → 자동 감지/사용
- **제한**: GitHub Actions 전용 (CI 환경), Docker 기반

**우리 프로젝트와의 관련성**: ★★★☆☆
- 언어 자동 감지 패턴은 참고 가능
- **차이점**: CI 전용 도구이고 Docker 기반. 로컬 개발 환경 부트스트랩과는 용도가 다름

---

### 1.4 MegaLinter

- **GitHub**: [oxsecurity/megalinter](https://github.com/oxsecurity/megalinter) (★ 매우 많음)
- **핵심 기능**: 50+ 언어, 22개 포맷, 21개 도구 형식 분석
- **감지 방식**: 모든 린터 기본 활성화, `ENABLE`/`DISABLE` 변수로 제어
- **Config**: `.mega-linter.yml` 파일로 설정
- **특징**: Docker 기반, GitHub Action + 독립 CLI 모두 지원

**우리 프로젝트와의 관련성**: ★★☆☆☆
- 다국어 린터 통합 참고. 하지만 Docker 기반이고 "모든 린터 기본 활성화" 접근법은 우리와 다름

---

### 1.5 pre-commit Framework

- **GitHub**: [pre-commit/pre-commit](https://github.com/pre-commit/pre-commit) (★ 매우 많음)
- **Site**: [pre-commit.com](https://pre-commit.com/)
- **핵심 기능**: 다국어 pre-commit 훅 관리 프레임워크
- **감지 방식**: `.pre-commit-config.yaml`에 훅 정의 → 자동 환경 구성
- **환경 관리**: 언어별 격리 환경 자동 구성 (virtualenvs, Node, Ruby 등)
- **특징**: Node 미설치 상태에서도 JavaScript 파일 수정 시 자동으로 Node 다운로드/빌드하여 eslint 실행

**우리 프로젝트와의 관련성**: ★★★☆☆
- 다국어 훅 관리 패턴 참고 (언어별 격리 환경)
- **차이점**: 사용자가 `.pre-commit-config.yaml`을 직접 작성해야 함. 자동 감지 기능 없음

---

## 2. 언어 감지 라이브러리

### 2.1 GitHub Linguist

- **GitHub**: [github-linguist/linguist](https://github.com/github-linguist/linguist) (★ 매우 많음)
- **감지 전략 (우선순위 순서)**:
  1. Vim/Emacs modeline
  2. 파일명 매칭 (`Makefile`, `Dockerfile`)
  3. Shebang (`#!/usr/bin/env python`)
  4. 파일 확장자
  5. XML 헤더
  6. Man page 섹션
  7. 휴리스틱 (정규표현식 기반)
  8. Naive Bayesian 분류기 (최종 fallback)
- **데이터**: `languages.yml`에 모든 언어의 확장자/shebang/파일명 정의

**우리 프로젝트와의 관련성**: ★★★★☆
- 감지 전략 체인 패턴 참고 가능
- **차이점**: 파일 수준 언어 감지. 우리는 프로젝트 수준 감지 (marker file 기반)

### 2.2 go-enry / hyperpolyglot

- [go-enry](https://github.com/src-d/enry) — Linguist의 Go 포팅
- [hyperpolyglot](https://github.com/monkslc/hyperpolyglot) — Linguist의 Rust 포팅. 빠른 성능

---

## 3. Claude Code 생태계 내 관련 프로젝트

### 3.1 claude-bootstrap (alinaqi)

- **GitHub**: [alinaqi/claude-bootstrap](https://github.com/alinaqi/claude-bootstrap)
- **핵심**: Claude Code용 프로젝트 초기화 시스템. TDD-first, security-first, AI-native
- **특징**: 53개 스킬, 모노레포/멀티레포 인식, `/initialize-project` 명령어
- **다국어 지원**: 명시적 다국어 감지 기능은 문서화되어 있지 않음
- **관련성**: 부트스트랩 패턴 참고, 하지만 언어 감지 기능은 미구현으로 보임

### 3.2 Claude Code 공식 이슈 — 크로스 언어 훅 오류

- **Issue #5387**: [Node.js hooks on Python projects](https://github.com/anthropics/claude-code/issues/5387)
  - Python FastAPI 프로젝트에서 npm/biome PostToolUse 훅이 실행되어 ENOENT 에러 발생
  - **요청 사항**: 프로젝트 타입 감지 로직 추가, 크로스 언어 훅 오염 방지
- **Issue #5386**: [Wrong project hooks in multi-project workspace](https://github.com/anthropics/claude-code/issues/5386)
  - 멀티 프로젝트 워크스페이스에서 Python 프로젝트에 Node.js 훅이 실행됨
  - **요청**: `package.json`, `requirements.txt` 등 프로젝트 지표로 타입 감지 후 적절한 훅만 실행

**우리 프로젝트와의 관련성**: ★★★★★
- **정확히 우리가 해결하려는 문제**. Claude Code 공식 이슈에서도 프로젝트 타입 감지의 필요성이 제기됨
- Issue에서 요청하는 해결책이 우리의 Detect-Ask-Confirm 접근법과 일치

### 3.3 Claude Code Hooks 가이드 (커뮤니티)

- [Claude Code Hooks for uv Projects](https://pydevtools.com/blog/claude-code-hooks-for-uv/) — Python/uv 전용 훅 패턴
- [SmartScope Guide](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/) — 언어별 훅 패턴 (Python→black, JS→prettier, Rust→rustfmt)
- [공식 Hooks Docs](https://code.claude.com/docs/en/hooks-guide) — `detect_language()` 함수 패턴 예시

---

## 4. 종합 분석

### 4.1 공통 패턴 (Prior Art에서 추출)

| 패턴 | 사용하는 프로젝트 | 우리 적용 가능성 |
|---|---|---|
| **`init` 시 프로젝트 스캔 → config 자동 생성** | Trunk, Qlty | ★★★★★ (핵심 패턴) |
| **기존 린터 config 파일 존중** | Trunk (`--only-detected-*`), Qlty | ★★★★★ (핵심 원칙) |
| **파일 확장자 기반 언어 감지** | Linguist, Super-Linter, MegaLinter | ★★★★☆ |
| **marker file 기반 프로젝트 타입 감지** | Claude Code Issues, codebase-mapper | ★★★★★ |
| **언어별 격리 환경 관리** | pre-commit | ★★☆☆☆ (범위 밖) |
| **감지 전략 체인 (fallback)** | Linguist | ★★★☆☆ (참고) |
| **TOML/YAML config 파일** | Trunk (`.trunk/trunk.yaml`), Qlty (`.qlty/qlty.toml`) | ★★★★☆ |

### 4.2 우리 접근법의 차별점

| 기존 도구 | 우리 접근법 |
|---|---|
| 독립 CLI 도구 (Trunk, Qlty) | Claude Code 플러그인/부트스트랩 통합 |
| 자체 린터 런타임 사용 | **프로젝트의 기존 도구를 그대로 사용** |
| 자동 감지만 (사용자 확인 없음) | **Detect → Ask → Confirm** (사용자 확인 포함) |
| CI 환경 전용 (Super-Linter, MegaLinter) | **로컬 개발 환경 부트스트랩** |
| config 파일만 생성 | **훅 + 스킬 + CLAUDE.md 전체 연동** |

### 4.3 Prior Art에서 가져올 것

1. **Trunk의 `--only-detected-*` 패턴** → R2 (기존 도구 설정 감지)에 반영
2. **Qlty의 "기존 config 파일 그대로 사용" 원칙** → R4 (project-config.yaml)에 반영
3. **Linguist의 감지 전략 체인** → R1 (marker file → 파일 확장자 → 사용자 질의)
4. **Claude Code Issue #5387의 문제 정의** → SPEC Vision에 이미 반영됨

### 4.4 결론

- **동일한 문제를 해결하는 도구는 존재** (Trunk, Qlty) — 하지만 독립 CLI 도구이며, Claude Code 플러그인/훅 시스템과 통합된 것은 **없음**
- **Claude Code 공식 이슈에서도 동일 문제 제기** (Issue #5387, #5386) — 프로젝트 타입 감지의 필요성이 커뮤니티에서 인정됨
- **우리의 Detect-Ask-Confirm 접근법은 유효** — Trunk/Qlty의 자동 감지 + 사용자 확인 단계 추가로 오감지 방지

---

## 5. Deep Dive: Qlty CLI (가장 적합한 참조 모델)

### 5.1 Qlty + Claude Code 공식 통합

Qlty는 Claude Code와의 공식 통합 가이드를 제공한다: [docs.qlty.sh/cli/coding-with-ai-agents](https://docs.qlty.sh/cli/coding-with-ai-agents)

**통합 방식 3가지:**

1. **CLAUDE.md 기반 (권장)**:
   ```
   "Before committing, ALWAYS run auto-formatting with `qlty fmt`"
   "Before finishing, ALWAYS run `qlty check --fix --level=low`"
   ```

2. **Git Hooks**: pre-commit에 `qlty fmt`, pre-push에 `qlty check`

3. **Claude Code Hooks**: Claude Code 전용 훅으로 PostToolUse 등에 연결

**핵심 인사이트**: Qlty는 "AI 에이전트가 CLI 명령어를 실행 → stdout 결과 + exit code로 판단"하는 단순한 인터페이스를 제공. 복잡한 프로토콜 불필요.

### 5.2 플러그인 TOML 구조 (eslint 예시)

Qlty의 플러그인 정의는 프로젝트의 기존 config 파일을 **감지하여 활용**하는 구조:

```toml
config_version = "0"

[plugins.definitions.eslint]
runtime = "node"                    # 런타임
package = "eslint"                  # 패키지명
file_types = ["javascript", "typescript", "jsx", "tsx"]
latest_version = "9.39.1"
known_good_version = "9.7.0"
version_command = "eslint --version"
description = "Javascript and ECMAScript linter"
package_file_candidate = "package.json"    # 프로젝트 감지 마커
package_file_candidate_filters = ["eslint", "jest", "prettier"]  # package.json 내 키워드

# ESLint 9.x (flat config)
[[plugins.definitions.eslint.drivers.lint.version]]
version_matcher = ">=9.0.0"
config_files = [
  "eslint.config.js",
  "eslint.config.ts",
  "eslint.config.mjs",
  "eslint.config.cjs",
]
script = "eslint --config ${config_file} --output-file ${tmpfile} --format json ${target}"

# ESLint 5.x-8.x (legacy .eslintrc)
[[plugins.definitions.eslint.drivers.lint.version]]
version_matcher = ">=5.0.0, <9.0.0"
config_files = [
  ".eslintrc", ".eslintrc.cjs", ".eslintrc.mjs",
  ".eslintrc.js", ".eslintrc.json",
  ".eslintrc.yaml", ".eslintrc.yml",
]
```

**핵심 설계:**
- `config_files`: 프로젝트에 이미 존재하는 config 파일을 찾아서 사용
- `package_file_candidate`: 해당 도구가 프로젝트에 존재하는지 판단하는 마커
- `package_file_candidate_filters`: package.json 내 키워드로 도구 사용 여부 감지
- `version_matcher`: 버전별로 다른 config 형식 대응 (ESLint 9.x flat config vs 8.x .eslintrc)

### 5.3 Ruff 플러그인 (Python 예시)

```toml
[plugins.definitions.ruff]
runtime = "python"
package = "ruff"
file_types = ["python"]
config_files = ["ruff.toml"]

[plugins.definitions.ruff.drivers.lint]
script = "ruff check --exit-zero --output-format json --output-file ${tmpfile} ${target}"

[plugins.definitions.ruff.drivers.format]
script = "ruff format ${target}"
driver_type = "formatter"
```

### 5.4 `qlty init` 동작 방식

```
qlty init
  │
  ├─ 1. Git 저장소 루트 확인
  ├─ 2. 파일 타입/config 파일 스캔
  │     ├─ package.json 발견 → eslint, prettier 플러그인 후보
  │     ├─ .eslintrc.js 발견 → eslint 플러그인 활성화
  │     ├─ pyproject.toml 발견 → ruff 플러그인 후보
  │     └─ ...
  ├─ 3. package_file_candidate_filters로 실제 사용 여부 확인
  │     (package.json 내 "eslint" 키워드 존재 확인)
  ├─ 4. .qlty/qlty.toml 생성
  │     [[plugin]]
  │     name = "eslint"
  │     [[plugin]]
  │     name = "prettier"
  └─ 5. 기존 config 파일(.eslintrc 등)은 그대로 유지
```

### 5.5 지원 린터/포맷터 (70개)

```
actionlint, ast-grep, bandit, biome, black, brakeman, checkov,
checkstyle, clippy, coffeelint, dockerfmt, dotenv-linter, eslint,
flake8, gitleaks, gofmt, golangci-lint, google-java-format, hadolint,
haml-lint, knip, ktlint, kube-linter, markdownlint, mypy,
osv-scanner, oxc, php-codesniffer, php-cs-fixer, phpstan, pmd,
prettier, prisma, radarlint-*, redocly, reek, ripgrep, rubocop,
ruby-stree, ruff, rustfmt, semgrep, shellcheck, shfmt, sqlfluff,
standardrb, stringslint, stylelint, swiftformat, swiftlint, terraform,
tflint, trivy, trufflehog, tsc, vale, yamllint, zizmor
```

### 5.6 우리 프로젝트에 Qlty를 활용하는 두 가지 경로

#### 경로 A: Qlty를 직접 통합 (Delegate 방식)

부트스트랩에서 `qlty init`을 실행하여 도구 감지를 위임.

```
Bootstrap → qlty init → .qlty/qlty.toml 자동 생성
         → 훅에서 qlty check / qlty fmt 실행
         → project-config.yaml에 qlty 사용 기록
```

**장점:**
- 70+ 린터/40+ 언어 즉시 지원
- 감지 로직 직접 구현 불필요
- Claude Code 공식 통합 가이드 존재
- 버전 고정, 캐싱, Git-aware 기능 무료

**단점:**
- Qlty CLI 설치 의존성 추가
- Fair Source 라이선스 (완전 오픈소스 아님)
- 자체 런타임으로 린터 실행 (프로젝트의 node_modules 내 eslint과 별도)

#### 경로 B: Qlty의 감지 패턴만 차용 (Inspire 방식)

Qlty의 `plugin.toml` 구조와 `config_files` / `package_file_candidate` 패턴을 참고하여 자체 감지 로직 구현.

```
Bootstrap → 자체 감지 로직 (Qlty 패턴 차용)
         → project-config.yaml 생성
         → 훅에서 프로젝트의 기존 도구 직접 실행 (npx eslint, uv run ruff 등)
```

**장점:**
- 외부 의존성 없음
- 프로젝트의 기존 도구를 그대로 사용 (node_modules 내 eslint 등)
- 완전한 제어

**단점:**
- 감지 로직 직접 구현 필요
- 70+ 도구 지원에 훨씬 많은 작업량

---

*Generated: 2026-01-30*
*Updated: 2026-01-30 (Qlty deep dive 추가, Claude Code 통합 가이드 발견)*
*Related: [RESEARCH-multi-language-support.md](./RESEARCH-multi-language-support.md), [SPEC.md](../SPEC.md)*
