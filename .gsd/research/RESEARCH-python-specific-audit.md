# RESEARCH: Python-Specific Code Audit

> **Date**: 2026-01-30
> **Purpose**: 보일러플레이트 내 Python 언어에 종속된 모든 구현 항목 전수 조사
> **Scope**: Hooks, Skills, Agents, Workflows, Config files

---

## 1. Hooks

| 파일 | Python-Specific 내용 |
|---|---|
| `.claude/hooks/bash-guard.py` | Python 스크립트 자체 + `pip`/`poetry`/`conda` 차단 로직 |
| `.claude/hooks/file-protect.py` | Python 스크립트 자체 |
| `.claude/hooks/auto-format-py.sh` | `.py` 파일 감지 → `uv run ruff format` / `ruff check --fix` |
| `.claude/hooks/post-turn-verify.sh` | `.py` 파일 감지 → `uv run ruff check` |
| `.claude/hooks/session-start.sh` | `python3`으로 JSON 파싱 |
| `.claude/hooks/save-transcript.sh` | `python3`으로 JSON 파싱 |
| `.claude/hooks/save-session-changes.sh` | `python3`으로 JSON 파싱 |
| `.claude/hooks/post-turn-index.sh` | `python3`으로 JSON 파싱 |
| `.claude/settings.json` | 위 훅들의 등록 설정 (auto-format-py.sh 등) |

---

## 2. Skills — Python 스크립트 (13개)

| 스킬 | 스크립트 | Python 종속 내용 |
|---|---|---|
| `arch-review` | `find_circular_imports.py` | Python import 순환 탐지 |
| `arch-review` | `check_complexity.sh` | `ruff` C90 McCabe complexity |
| `codebase-mapper` | `analyze_imports.py` | Python import regex (`from X import` / `import X`) |
| `codebase-mapper` | `scan_structure.sh` | `__pycache__` 제외 |
| `commit` | `analyze_diff.py` | Python diff 분석 |
| `create-pr` | `prepare_pr_body.py` | PR body 생성 |
| `executor` | `parse_plan.py`, `update_prd.py` | Plan/PRD 파싱 |
| `impact-analysis` | `find_dependents.py` | Python import 패턴만 탐지 |
| `plan-checker` | `validate_plan.py` | Plan 검증 |
| `planner` | `assess_discovery_level.py`, `plan_to_json.py` | Discovery/Plan 변환 |
| `verifier` | `detect_stubs.py` | Python stub 탐지 |

## 3. Skills — SKILL.md 내 Python 참조

| 스킬 | 참조 내용 |
|---|---|
| `clean` | `uv run ruff check`, `ruff format`, `mypy`, `pytest` |
| `bootstrap` | Python 환경 설정 (`uv sync`, `.venv`, `pyproject.toml`) |
| `commit` | `ruff check`, `mypy`, `pytest` 사전 검증 |
| `create-pr` | `ruff`, `mypy`, `pytest` pre-commit 검증 |
| `pr-review` | "Ruff/mypy compliance" |
| `impact-analysis` | `.py` 파일 경로 참조, `find_dependents.py` |
| `arch-review` | `ruff`, circular imports |
| `codebase-mapper` | `pyproject.toml` 탐지, `__pycache__` 제외, `analyze_imports.py` |
| `verifier` | `detect_stubs.py` (Python stub 탐지) |
| `executor` | `update_prd.py`, `parse_plan.py` |
| `planner` | `assess_discovery_level.py`, `plan_to_json.py` |
| `plan-checker` | `validate_plan.py` |

---

## 4. Agents / Workflows

| 파일 | Python-Specific 내용 |
|---|---|
| `.github/agents/agent.md` | "Python Environment (uv ONLY)" 섹션, `TypedDict` 예시 |
| `.agent/workflows/bootstrap.md` | Python 환경 설정, `uv sync`, `.venv` |
| `.agent/workflows/quick-check.md` | `pytest`, `ruff`, `mypy`, `python -c "import ..."` |
| `.agent/workflows/feature-dev.md` | `uv run pytest` |
| `.agent/workflows/bug-fix.md` | `uv run pytest` |
| `.agent/workflows/map.md` | `__pycache__` 제외, `pip list --outdated` |
| `.agent/workflows/new-project.md` | `.py` 파일 탐색 |
| `.agent/workflows/web-search.md` | `docs.python.org` 예시 |

---

## 5. Config / Infra 파일

| 파일 | Python-Specific 내용 |
|---|---|
| `CLAUDE.md` | "Primary language is Python 3.12", `uv`/`ruff`/`mypy`/`pytest` 명령, `TypedDict` |
| `pyproject.toml` | Python 3.12, `ruff`/`mypy`/`pytest` 전체 설정 |
| `Makefile` | `lint`/`test`/`typecheck` 타겟 (ruff, pytest, mypy), `pipx install` |
| `.vscode/settings.json` | Python interpreter, Ruff/Mypy 확장 설정 |
| `.gitignore` | `.venv`, `__pycache__`, `*.pyc`, `.pytest_cache`, `.ruff_cache`, `.mypy_cache` |
| `.github/workflows/release-plugin.yml` | `__pycache__`, `*.pyc` 제외 |

---

## 6. GSD 문서

| 파일 | 참조 |
|---|---|
| `.gsd/ARCHITECTURE.md` | Python scripts, hooks, CI/CD, tests |
| `.gsd/STACK.md` | Python 3.12, uv, pytest, ruff, mypy, pipx |
| `.gsd/CHANGELOG.md` | `.py` 파일 경로 |

---

## 7. 분류 요약

Python 종속 항목은 **5가지 축**으로 분류:

1. **패키지 관리**: `uv`, `pip`/`poetry` 차단, `pipx`
2. **품질 도구**: `ruff` (lint/format), `mypy` (type check), `pytest` (test)
3. **Python 런타임**: `python3` JSON 파싱, `.py` 확장자 감지, `__pycache__`/`.pyc` 제외
4. **환경**: `.venv`, `pyproject.toml`, Python 3.12 요구사항
5. **코드 패턴**: `TypedDict`, circular import 탐지, Python import regex

**총 200+ 개소**, 30+ 파일에 분포.

---

*Generated: 2026-01-30*
