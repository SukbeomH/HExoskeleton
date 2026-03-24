# Linting & Code Quality 상세 문서

이 프로젝트는 **Ruff** (린터/포매터)와 **Mypy** (타입 체커)를 사용하여 코드 품질을 관리합니다. 모든 설정은 `pyproject.toml`에 정의되어 있습니다.

---

## 개요

| 도구 | 역할 | 버전 |
|------|------|------|
| **Ruff** | 린터 + 포매터 | >= 0.8 |
| **Mypy** | 타입 체커 | >= 1.13 |
| **pytest** | 테스트 프레임워크 | >= 8.0 |

---

## 명령어

### Make 명령어

```bash
make lint         # Ruff 린트 체크
make lint-fix     # Ruff 자동 수정
make typecheck    # Mypy 타입 체크
make test         # pytest 실행
```

### uv 명령어

```bash
uv run ruff check .          # 린트 체크
uv run ruff check . --fix    # 자동 수정
uv run ruff format .         # 포맷팅
uv run mypy .                # 타입 체크
uv run pytest tests/ -v      # 테스트
```

---

## Ruff 설정

### pyproject.toml

```toml
[tool.ruff]
target-version = "py311"
line-length = 100
exclude = [
    "awesome-claude-code",
    "claude-code-tips",
    "everything-claude-code",
    "ralph",
]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "W",    # pycodestyle warnings
    "B",    # flake8-bugbear
    "C90",  # McCabe complexity
    "PL",   # Pylint
    "TC",   # flake8-type-checking
]
ignore = [
    "E501",    # line-length (formatter가 처리)
    "PLR2004", # magic-value-comparison
]

[tool.ruff.lint.mccabe]
max-complexity = 10

[tool.ruff.lint.pylint]
max-args = 6
max-returns = 6
max-statements = 50

[tool.ruff.lint.pep8-naming]
extend-ignore-names = ["*Factory", "Create*"]

[tool.ruff.lint.flake8-type-checking]
strict = true
```

---

## 활성화된 규칙

### E - pycodestyle errors

| 규칙 | 설명 |
|------|------|
| E1xx | 들여쓰기 |
| E2xx | 공백 |
| E3xx | 빈 줄 |
| E4xx | import |
| E7xx | 문장 |
| E9xx | 런타임 |

### F - pyflakes

| 규칙 | 설명 |
|------|------|
| F401 | 사용되지 않는 import |
| F403 | `from X import *` 사용 |
| F405 | 정의되지 않은 이름 |
| F811 | 재정의 |
| F841 | 사용되지 않는 변수 |

### I - isort

| 규칙 | 설명 |
|------|------|
| I001 | import 순서 |
| I002 | 누락된 필수 import |

### N - pep8-naming

| 규칙 | 설명 |
|------|------|
| N801 | 클래스명 CapWords |
| N802 | 함수명 lowercase |
| N803 | 인자명 lowercase |
| N806 | 변수명 lowercase |

### W - pycodestyle warnings

| 규칙 | 설명 |
|------|------|
| W291 | 줄 끝 공백 |
| W292 | 파일 끝 줄바꿈 없음 |
| W293 | 빈 줄에 공백 |

### B - flake8-bugbear

| 규칙 | 설명 |
|------|------|
| B006 | mutable default argument |
| B007 | 사용되지 않는 loop variable |
| B008 | function call in default argument |
| B011 | `assert False` 대신 `raise AssertionError` |
| B017 | `with pytest.raises()` 범위 문제 |

### C90 - McCabe complexity

| 규칙 | 설명 |
|------|------|
| C901 | 함수 복잡도 > 10 |

### PL - Pylint

| 규칙 | 설명 |
|------|------|
| PLR0913 | 인자 수 > 6 |
| PLR0911 | return 문 수 > 6 |
| PLR0915 | 문장 수 > 50 |
| PLW1510 | `subprocess.run` missing `check` |

### TC - flake8-type-checking

| 규칙 | 설명 |
|------|------|
| TC001 | TYPE_CHECKING 블록 이동 |
| TC002 | 타입 전용 import |
| TC003 | 문자열 어노테이션 |

---

## 무시되는 규칙

| 규칙 | 이유 |
|------|------|
| E501 | line-length — Ruff formatter가 처리 |
| PLR2004 | magic-value-comparison — 상수 비교 허용 |

---

## 제한 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| `line-length` | 100 | 최대 줄 길이 |
| `max-complexity` | 10 | McCabe 복잡도 |
| `max-args` | 6 | 함수 인자 수 |
| `max-returns` | 6 | return 문 수 |
| `max-statements` | 50 | 함수 내 문장 수 |

---

## 네이밍 예외

```toml
[tool.ruff.lint.pep8-naming]
extend-ignore-names = ["*Factory", "Create*"]
```

`*Factory`, `Create*` 패턴은 PEP8 네이밍 규칙에서 제외됩니다.

---

## Mypy 설정

### pyproject.toml

```toml
[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
exclude = [
    "awesome-claude-code",
    "claude-code-tips",
    "everything-claude-code",
    "ralph",
]
```

### 주요 설정

| 설정 | 값 | 설명 |
|------|-----|------|
| `python_version` | "3.11" | 대상 Python 버전 |
| `warn_return_any` | true | `Any` 반환 경고 |
| `warn_unused_configs` | true | 미사용 설정 경고 |

---

## 자동 포맷팅 훅

### auto-format-py.sh

Python 파일 수정 시 자동으로 Ruff 포맷팅이 적용됩니다.

```bash
#!/bin/bash
# PostToolUse: Python 파일 자동 포맷

if [[ "$FILE_PATH" == *.py ]]; then
    ruff format "$FILE_PATH" 2>/dev/null || true
    ruff check --fix "$FILE_PATH" 2>/dev/null || true
fi
```

**훅 설정** (`.claude/settings.json`):
```json
{
  "PostToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/auto-format-py.sh",
          "timeout": 30
        }
      ]
    }
  ]
}
```

---

## Clean 스킬

코드 품질 도구를 일괄 실행하는 스킬입니다.

```bash
# 스킬 호출
/clean
```

**실행 내용**:
1. `ruff check . --fix` — 린트 + 자동 수정
2. `ruff format .` — 포맷팅
3. `mypy .` — 타입 체크

---

## CI/CD 통합

### .github/workflows/ci.yml

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run ruff check .

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv sync --frozen
      - run: uv run mypy .

  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          enable-cache: true
      - run: uv python install ${{ matrix.python-version }}
      - run: uv sync --frozen
      - run: uv run --python ${{ matrix.python-version }} pytest tests/ -v
```

---

## 규칙 참조

### Ruff 전체 규칙

모든 Ruff 규칙은 공식 문서에서 확인할 수 있습니다:
- https://docs.astral.sh/ruff/rules/

### 규칙 카테고리별 문서

| 카테고리 | 문서 |
|----------|------|
| pycodestyle (E, W) | [docs](https://docs.astral.sh/ruff/rules/#pycodestyle-e-w) |
| pyflakes (F) | [docs](https://docs.astral.sh/ruff/rules/#pyflakes-f) |
| isort (I) | [docs](https://docs.astral.sh/ruff/rules/#isort-i) |
| pep8-naming (N) | [docs](https://docs.astral.sh/ruff/rules/#pep8-naming-n) |
| flake8-bugbear (B) | [docs](https://docs.astral.sh/ruff/rules/#flake8-bugbear-b) |
| mccabe (C90) | [docs](https://docs.astral.sh/ruff/rules/#mccabe-c90) |
| pylint (PL) | [docs](https://docs.astral.sh/ruff/rules/#pylint-pl) |

---

## Troubleshooting

### 린트 오류 무시

특정 줄에서 규칙 무시:
```python
x = 1  # noqa: F841
```

특정 파일에서 규칙 무시:
```python
# ruff: noqa: F401
```

### 타입 오류 무시

```python
x = some_value  # type: ignore
```

또는 특정 오류만:
```python
x = some_value  # type: ignore[assignment]
```

---

## 관련 문서

- [Hooks 상세](./HOOKS.md) — auto-format-py.sh 훅
- [Skills 상세](./SKILLS.md) — clean 스킬
- [GitHub Workflow 상세](./GITHUB-WORKFLOW.md) — CI/CD 설정
