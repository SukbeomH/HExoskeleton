# 보일러플레이트 안전 적용 방법론 연구 보고서

> **목적**: 활발히 개발 중인 기존 프로젝트에 본 보일러플레이트를 적용할 때, 기존 설정 및 코드를 덮어쓰지 않기 위한 대안과 방법론 조사

---

## 1. 문제 정의

본 보일러플레이트는 다음과 같은 루트 레벨 파일/디렉토리를 포함한다:

| 충돌 위험도 | 파일/디렉토리 | 이유 |
|------------|-------------|------|
| **HIGH** | `pyproject.toml` | 프로젝트 메타데이터, 의존성, ruff/mypy 규칙 전체 정의 |
| **HIGH** | `Makefile` | 20+ 타겟 — 기존 Makefile 완전 대체 |
| **HIGH** | `.gitignore` | 129줄의 광범위한 패턴 |
| **HIGH** | `.mcp.json` | MCP 서버 설정 (graph-code, memorygraph, context7) |
| **HIGH** | `.github/workflows/ci.yml` | CI 파이프라인 대체 |
| **MEDIUM** | `.vscode/settings.json` | Ruff/Python 린터 설정 충돌 가능 |
| **MEDIUM** | `.claude/settings.json` | Hook 정의 병합 필요 |
| **MEDIUM** | `tests/conftest.py` | 기존 fixture 덮어쓰기 위험 |
| **LOW** | `.claude/skills/`, `.claude/agents/` | 모듈형 — 안전하게 추가 가능 |
| **LOW** | `.agent/workflows/` | 템플릿 — 확장 가능 |
| **LOW** | `.gsd/templates/` | 참조용 문서 |

단순 복사(`cp -r`)는 HIGH 위험도 파일에서 **기존 설정을 파괴**한다.

---

## 2. 접근 방식 비교

### 2.1 Copier — 3-Way Merge 기반 템플릿 라이프사이클 관리

**개요**: Python 기반 프로젝트 스캐폴딩 도구. 템플릿 적용 후 **지속적 업데이트**를 3-way merge로 지원하는 유일한 도구.

**동작 원리 (`copier update`)**:
1. `.copier-answers.yml`에 저장된 이전 답변으로 **이전 템플릿 출력** 재생성 (BASE)
2. 사용자의 현재 프로젝트와 BASE의 차이 계산 (사용자 수정사항 캡처)
3. 새 템플릿 버전으로 **새 템플릿 출력** 생성 (OTHER)
4. 사용자의 diff를 새 출력에 적용 — 충돌 시 Git 스타일 conflict marker 삽입

**주요 기능**:
- `--skip`: 특정 파일은 복사하지 않되 기존 파일 유지
- `--exclude`: 템플릿에서 완전히 제외
- `when` 조건: 선택적 컴포넌트 포함 ("MCP 설정 필요? GSD 워크플로우 필요?")
- Git 태그 기반 버전 추적

**장점**:
- 기존 파일 수정사항 보존하면서 템플릿 업데이트 가능
- 선택적 컴포넌트 적용 (조건부 파일 포함)
- `uv` 생태계와 호환

**단점**:
- 템플릿 저장소에 Git 태그 필요
- 최초 적용 시 `--skip`/`--exclude` 세밀한 설정 필요
- Jinja2 템플릿으로 변환 작업 필요

**적합도**: ★★★★★ — 본 프로젝트에 가장 적합

---

### 2.2 Git Remote + Merge — 순수 Git 기반 접근

**동작 원리**:
```bash
# 1. 보일러플레이트를 remote로 추가
git remote add boilerplate <template-repo-url>
git fetch boilerplate

# 2. 관련 없는 히스토리 허용하여 병합
git merge boilerplate/main --allow-unrelated-histories

# 3. 충돌 해결 후 커밋
git mergetool   # 또는 수동 해결
git commit
```

**후속 업데이트**:
```bash
git fetch boilerplate
git merge boilerplate/main
```

**장점**:
- 추가 도구 불필요 — 순수 Git
- 표준 충돌 해결 워크플로우
- `git merge` 반복으로 지속적 동기화

**단점**:
- 모든 겹치는 파일에서 충돌 발생
- 파일 선택적 적용 불가 (전체 병합)
- 보일러플레이트 히스토리가 프로젝트에 혼입

**적합도**: ★★★☆☆ — 간단하지만 충돌 해결 부담

---

### 2.3 셸 스크립트 기반 선택적 병합 (Custom Installer)

**동작 원리**: 각 파일/디렉토리별로 "안전 복사" 로직을 구현한 설치 스크립트 작성.

```bash
#!/bin/bash
# apply-boilerplate.sh

BOILERPLATE_DIR="$(dirname "$0")"
TARGET_DIR="${1:-.}"

# --- 안전 복사 함수 ---
safe_copy() {
    local src="$1" dst="$2"
    if [[ -e "$dst" ]]; then
        echo "[SKIP] $dst already exists"
        return 1
    fi
    cp -r "$src" "$dst"
    echo "[COPY] $dst"
}

# --- 병합 함수 (append) ---
merge_append() {
    local src="$1" dst="$2" marker="$3"
    if [[ -e "$dst" ]]; then
        if ! grep -q "$marker" "$dst"; then
            echo -e "\n# --- Boilerplate additions ($marker) ---" >> "$dst"
            cat "$src" >> "$dst"
            echo "[MERGE] Appended to $dst"
        else
            echo "[SKIP] $dst already contains boilerplate section"
        fi
    else
        cp "$src" "$dst"
        echo "[COPY] $dst"
    fi
}

# --- JSON 병합 함수 ---
merge_json() {
    local src="$1" dst="$2"
    if [[ -e "$dst" ]]; then
        # jq로 deep merge
        jq -s '.[0] * .[1]' "$dst" "$src" > "${dst}.tmp"
        mv "${dst}.tmp" "$dst"
        echo "[MERGE] $dst"
    else
        cp "$src" "$dst"
        echo "[COPY] $dst"
    fi
}

# --- 실행 ---
# LOW RISK: 안전하게 디렉토리 복사
safe_copy "$BOILERPLATE_DIR/.claude/skills"    "$TARGET_DIR/.claude/skills"
safe_copy "$BOILERPLATE_DIR/.claude/agents"    "$TARGET_DIR/.claude/agents"
safe_copy "$BOILERPLATE_DIR/.agent"            "$TARGET_DIR/.agent"
safe_copy "$BOILERPLATE_DIR/.gsd/templates"    "$TARGET_DIR/.gsd/templates"

# MEDIUM RISK: 병합 필요
merge_json  "$BOILERPLATE_DIR/.mcp.json"       "$TARGET_DIR/.mcp.json"
merge_append "$BOILERPLATE_DIR/.gitignore"     "$TARGET_DIR/.gitignore" "BOILERPLATE"

# HIGH RISK: 수동 확인 필요
echo ""
echo "[WARN] 다음 파일은 수동 병합이 필요합니다:"
echo "  - pyproject.toml (의존성 + 도구 설정)"
echo "  - Makefile (타겟 충돌 확인)"
echo "  - .github/workflows/ci.yml (CI 파이프라인)"
```

**장점**:
- 완전한 제어 — 파일별 전략 지정
- 추가 도구 의존성 없음 (bash + jq)
- 즉시 구현 가능

**단점**:
- 수동 유지보수 부담
- 업데이트 메커니즘 없음 (1회성)
- TOML 병합이 복잡 (전용 파서 필요)

**적합도**: ★★★★☆ — 즉시 적용 가능한 실용적 방안

---

### 2.4 Cruft — Cookiecutter 기반 업데이트 지원

**동작 원리**: Cookiecutter 템플릿에 업데이트 기능을 추가한 래퍼. `.cruft.json`에 템플릿 커밋 해시와 컨텍스트 변수를 저장.

```bash
# 기존 프로젝트를 템플릿에 연결 (retroactive)
cruft link <template-url>

# 템플릿 변경 감지
cruft check    # CI에 추가 가능

# 업데이트 적용
cruft update   # .rej 파일로 실패한 패치 출력
```

**장점**:
- `cruft link`로 기존 프로젝트에 소급 적용 가능
- CI에서 `cruft check`로 드리프트 감지
- Cookiecutter 생태계 활용

**단점**:
- `.rej` 파일만 생성 (inline conflict marker 없음)
- 부분 실패 시에도 `.cruft.json`의 커밋 해시 업데이트 → CI 오탐
- Copier 대비 병합 정교함이 떨어짐

**적합도**: ★★★☆☆ — Cookiecutter 사용자에게 적합

---

### 2.5 Git Subtree — 하위 디렉토리 격리

**동작 원리**: 보일러플레이트를 프로젝트의 하위 디렉토리로 통합.

```bash
git subtree add --prefix=.boilerplate origin/boilerplate main --squash
git subtree pull --prefix=.boilerplate origin/boilerplate main --squash
```

이후 심볼릭 링크 또는 래퍼 스크립트로 필요한 파일 참조.

**장점**:
- 보일러플레이트를 격리된 디렉토리에 유지
- `--squash`로 히스토리 압축
- 양방향 동기화 가능 (`subtree push`)

**단점**:
- 루트 레벨 파일(`.gitignore`, `pyproject.toml`)은 별도 처리 필요
- 심볼릭 링크 관리 복잡성
- 디렉토리 접두사 기억 필요

**적합도**: ★★☆☆☆ — 루트 레벨 설정 파일이 많아 부적합

---

### 2.6 Hygen — 컴포넌트 단위 생성기

**동작 원리**: 전체 프로젝트가 아닌 **개별 컴포넌트**를 생성/주입하는 방식.

```bash
# 각 컴포넌트를 독립적으로 적용
hygen claude-skill add --name=commit
hygen gsd init
hygen mcp add --server=graph-code
```

**장점**:
- 완전한 선택적 적용 — 덮어쓰기 불가능
- 기존 파일에 코드 주입 (`inject: true`) 지원
- 프로젝트 내 템플릿 관리 (`_templates/`)

**단점**:
- Node.js 의존성
- 각 컴포넌트별 템플릿 작성 필요 (높은 초기 비용)
- 전체 프로젝트 수준 동기화 불가

**적합도**: ★★☆☆☆ — 초기 비용 대비 효과 낮음

---

## 3. 파일 유형별 병합 전략

### 3.1 구조화된 설정 파일

| 파일 | 포맷 | 권장 병합 전략 |
|------|------|---------------|
| `pyproject.toml` | TOML | **Deep merge** — `[project.dependencies]`는 합집합, `[tool.ruff]` 규칙은 보일러플레이트 우선 |
| `.mcp.json` | JSON | **Deep merge** — `mcpServers` 키를 합집합으로 병합 (`jq -s '.[0] * .[1]'`) |
| `package.json` (있을 경우) | JSON | **Deep merge** — scripts, dependencies 각각 합집합 |

### 3.2 텍스트 기반 설정 파일

| 파일 | 권장 병합 전략 |
|------|---------------|
| `.gitignore` | **Append** — 보일러플레이트 패턴을 섹션 구분자와 함께 추가 |
| `Makefile` | **Include** — 보일러플레이트 타겟을 별도 파일(`Makefile.boilerplate`)로 분리 후 `include` |
| `.env.example` | **Append** — 새 키만 추가 (기존 키 유지) |

### 3.3 디렉토리 기반 컴포넌트

| 디렉토리 | 권장 전략 |
|----------|----------|
| `.claude/skills/` | **Safe copy** — 개별 스킬 디렉토리 단위로 복사 (기존 스킬 보존) |
| `.claude/agents/` | **Safe copy** — 기존 에이전트 보존 |
| `.agent/workflows/` | **Safe copy** — 기존 워크플로우 보존 |
| `.gsd/templates/` | **Safe copy** — 기존 템플릿 보존 |
| `.github/ISSUE_TEMPLATE/` | **Safe copy** — 기존 템플릿 보존 |
| `tests/` | **Manual merge** — conftest.py는 수동 병합, 샘플 테스트는 skip |

### 3.4 Makefile Include 패턴

기존 `Makefile`을 보존하면서 보일러플레이트 타겟을 추가하는 방법:

```makefile
# 기존 프로젝트 Makefile (변경 없음)
.PHONY: build deploy
build:
	...
deploy:
	...

# 보일러플레이트 타겟 포함
-include Makefile.boilerplate
```

```makefile
# Makefile.boilerplate (보일러플레이트에서 복사)
.PHONY: bp-setup bp-index bp-lint bp-test
bp-setup: bp-check-deps bp-install bp-init-env bp-index
bp-index:
	npx -y @er77/code-graph-rag-mcp . --index
bp-lint:
	uv run ruff check . --fix
bp-test:
	uv run pytest tests/
```

---

## 4. 권장 방안: 계층적 적용 전략

최적의 접근은 **단일 도구에 의존하지 않고**, 파일 충돌 위험도에 따라 다른 전략을 적용하는 것이다.

### Phase 1: 안전 복사 (LOW RISK — 자동화 가능)

대상: `.claude/skills/`, `.claude/agents/`, `.agent/workflows/`, `.gsd/templates/`, `.gsd/examples/`, `.github/ISSUE_TEMPLATE/`

```bash
# 디렉토리가 없으면 생성, 있으면 기존 파일 보존하고 새 파일만 추가
rsync -av --ignore-existing "$BOILERPLATE/.claude/skills/" "$TARGET/.claude/skills/"
rsync -av --ignore-existing "$BOILERPLATE/.agent/workflows/" "$TARGET/.agent/workflows/"
rsync -av --ignore-existing "$BOILERPLATE/.gsd/templates/" "$TARGET/.gsd/templates/"
```

### Phase 2: 구조적 병합 (MEDIUM RISK — 도구 지원)

대상: `.mcp.json`, `.gitignore`, `.env.example`

```bash
# .mcp.json: JSON deep merge
jq -s '.[0] * .[1]' "$TARGET/.mcp.json" "$BOILERPLATE/.mcp.json" > tmp && mv tmp "$TARGET/.mcp.json"

# .gitignore: 섹션 구분 append
echo -e "\n# === Boilerplate patterns ===" >> "$TARGET/.gitignore"
cat "$BOILERPLATE/.gitignore" >> "$TARGET/.gitignore"
sort -u "$TARGET/.gitignore" -o "$TARGET/.gitignore"  # 중복 제거
```

### Phase 3: 수동 병합 (HIGH RISK — 사람 개입)

대상: `pyproject.toml`, `Makefile`, `.github/workflows/ci.yml`, `.vscode/settings.json`

이 파일들은 **diff 출력과 병합 가이드**를 제공하고, 사용자가 직접 병합한다:

```bash
# diff 출력
diff -u "$TARGET/pyproject.toml" "$BOILERPLATE/pyproject.toml" > pyproject.toml.patch
echo "=== pyproject.toml 병합 가이드 ==="
echo "1. [dependency-groups].dev 에 pytest, ruff, mypy 추가"
echo "2. [tool.ruff] 섹션 추가 (line-length=100, target-version=py311)"
echo "3. [tool.mypy] 섹션 추가"
echo "4. [tool.pytest.ini_options] 섹션 추가"
```

### Phase 4: 장기 동기화 (선택)

보일러플레이트가 자주 업데이트되는 경우 **Copier**로 전환:

```bash
# 1. 보일러플레이트를 Copier 템플릿으로 변환 (1회)
#    copier.yml 작성 + Jinja2 조건부 파일 설정

# 2. 기존 프로젝트에 적용
copier copy gh:user/boilerplate . --skip-tasks

# 3. 이후 업데이트
copier update --skip-tasks
```

---

## 5. 구현 우선순위 및 로드맵

| 단계 | 작업 | 복잡도 | 즉시 효과 |
|------|------|--------|----------|
| **1** | `apply-boilerplate.sh` 스크립트 작성 (Phase 1-3 구현) | 낮음 | 높음 |
| **2** | `Makefile.boilerplate` 분리 + include 패턴 적용 | 낮음 | 중간 |
| **3** | 파일별 병합 가이드 문서화 (`MERGE-GUIDE.md`) | 낮음 | 중간 |
| **4** | Copier 템플릿 변환 (`copier.yml` + Jinja2) | 중간 | 높음 (장기) |
| **5** | GitHub Actions `template-sync` 워크플로우 추가 | 중간 | 높음 (자동화) |
| **6** | Dry-run 모드 (`--dry-run` 플래그) | 낮음 | 중간 |

---

## 6. 결론

| 시나리오 | 권장 방식 |
|----------|----------|
| **즉시 적용, 1회성** | 셸 스크립트 (`apply-boilerplate.sh`) + 수동 병합 가이드 |
| **팀 내 여러 프로젝트에 반복 적용** | Copier 템플릿 변환 |
| **보일러플레이트 지속 업데이트 추적** | Copier + Git 태그 기반 버전 관리 |
| **최소한의 도구 의존성** | Git remote merge + `rsync --ignore-existing` |
| **CI에서 드리프트 감지** | Cruft (`cruft check`) 또는 Copier |

**핵심 원칙**: 파일을 3가지 범주(안전 복사 / 구조적 병합 / 수동 병합)로 분류하고, 각 범주에 맞는 전략을 적용한다. "모든 파일에 하나의 전략"은 반드시 문제를 일으킨다.
