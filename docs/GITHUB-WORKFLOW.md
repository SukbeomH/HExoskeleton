# GitHub Workflow 상세 문서

이 프로젝트의 GitHub Actions CI/CD 파이프라인과 Issue Templates 설정을 설명합니다.

---

## 개요

| 항목 | 위치 |
|------|------|
| **CI 워크플로우** | `.github/workflows/ci.yml` |
| **Issue 템플릿** | `.github/ISSUE_TEMPLATE/*.yml` |
| **GitHub Agent** | `.github/agents/agent.md` |

---

## CI 워크플로우

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

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

## Jobs 상세

### 1. lint

**역할**: Ruff 린터로 코드 스타일 검사

```yaml
lint:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: astral-sh/setup-uv@v4
      with:
        enable-cache: true
    - run: uv sync --frozen
    - run: uv run ruff check .
```

**실행 조건**:
- `push` to master
- `pull_request` to master

**캐싱**: `astral-sh/setup-uv@v4`의 `enable-cache: true`로 의존성 캐싱

---

### 2. typecheck

**역할**: Mypy로 타입 검사

```yaml
typecheck:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: astral-sh/setup-uv@v4
      with:
        enable-cache: true
    - run: uv sync --frozen
    - run: uv run mypy .
```

---

### 3. test

**역할**: pytest로 테스트 실행 (다중 Python 버전)

```yaml
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

**테스트 매트릭스**:
- Python 3.11
- Python 3.12
- Python 3.13

---

## Concurrency 설정

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

| 설정 | 설명 |
|------|------|
| `group` | 워크플로우 + 브랜치별 그룹 |
| `cancel-in-progress` | 새 실행 시 진행 중인 실행 취소 |

**효과**:
- 같은 브랜치에서 새 push 시 이전 실행 자동 취소
- 리소스 절약 및 빠른 피드백

---

## 트리거 조건

```yaml
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
```

| 이벤트 | 대상 |
|--------|------|
| `push` | master 브랜치 |
| `pull_request` | master 브랜치로의 PR |

---

## 사용 Actions

### actions/checkout@v4

```yaml
- uses: actions/checkout@v4
```

리포지토리 체크아웃.

### astral-sh/setup-uv@v4

```yaml
- uses: astral-sh/setup-uv@v4
  with:
    enable-cache: true
```

uv 패키지 매니저 설정 + 캐싱.

**옵션**:
| 옵션 | 설명 |
|------|------|
| `enable-cache` | 의존성 캐싱 활성화 |

---

## 의존성 설치

```yaml
- run: uv sync --frozen
```

`--frozen` 플래그로 lockfile 기준 정확한 버전 설치.

---

## Issue Templates

### 위치

```
.github/ISSUE_TEMPLATE/
├── bug_report.yml
├── feature_request.yml
└── config.yml
```

### bug_report.yml (예시)

```yaml
name: Bug Report
description: Report a bug
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!

  - type: textarea
    id: description
    attributes:
      label: Describe the bug
      description: A clear description of what the bug is.
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
      description: Steps to reproduce the behavior.
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
      description: What you expected to happen.
    validations:
      required: true

  - type: dropdown
    id: version
    attributes:
      label: Version
      options:
        - "latest"
        - "0.1.0"
    validations:
      required: true
```

### feature_request.yml (예시)

```yaml
name: Feature Request
description: Suggest a new feature
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem statement
      description: What problem does this solve?
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
      description: How should this work?
    validations:
      required: true
```

---

## GitHub Agent

### .github/agents/agent.md

GitHub Copilot Workspace 또는 GitHub-hosted agents를 위한 설정 파일입니다.

**역할**:
- MCP 서버 도구 목록 제공
- 코드베이스 구조 설명
- 개발 규칙 정의

**주요 내용**:
- graph-code MCP 도구 (19개)
- mcp-memory-service MCP 도구 (8개)
- context7 MCP 도구 (2개)
- 코드 스타일 규칙
- 커밋 규칙

---

## 워크플로우 확장

### 추가 가능한 Jobs

**Coverage Report**:
```yaml
coverage:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: astral-sh/setup-uv@v4
    - run: uv sync --frozen
    - run: uv run pytest tests/ --cov=src --cov-report=xml
    - uses: codecov/codecov-action@v4
```

**Security Scan**:
```yaml
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: astral-sh/setup-uv@v4
    - run: uv sync --frozen
    - run: uv run bandit -r src/
```

**Build & Publish** (PyPI):
```yaml
publish:
  runs-on: ubuntu-latest
  needs: [lint, typecheck, test]
  if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
  steps:
    - uses: actions/checkout@v4
    - uses: astral-sh/setup-uv@v4
    - run: uv build
    - run: uv publish
```

---

## 로컬 테스트

### Act 사용

[act](https://github.com/nektos/act)를 사용하여 로컬에서 워크플로우 테스트:

```bash
# 설치
brew install act

# 실행
act push
```

### 수동 실행

```bash
# lint
uv run ruff check .

# typecheck
uv run mypy .

# test
uv run pytest tests/ -v
```

---

## Troubleshooting

### 캐시 문제

캐시가 손상된 경우 수동으로 삭제:

1. GitHub → Settings → Actions → Caches
2. 해당 캐시 삭제

### 의존성 버전 불일치

```bash
# lockfile 재생성
uv lock

# 커밋
git add uv.lock
git commit -m "chore: update lockfile"
```

### 타임아웃

기본 타임아웃은 6시간. 필요시 조정:

```yaml
jobs:
  test:
    timeout-minutes: 30
```

---

## 관련 문서

- [Linting 상세](./LINTING.md) — 린트/타입체크 설정
- [MCP 상세](./MCP.md) — GitHub Agent가 사용하는 MCP 도구
- [README](../README.md) — 프로젝트 개요
