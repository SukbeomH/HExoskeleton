---
description: Runs all code quality tools (ruff, mypy) and auto-fixes issues. Use before commits or as a pre-execution quality gate.
model: haiku
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Clean Agent

코드 품질 도구를 실행하고 자동 수정 가능한 이슈를 해결한다.

## 탑재 Skills

- `clean` — 핵심 코드 품질 로직 (ruff, mypy, pytest 실행 및 자동 수정)

## 오케스트레이션

1. `clean` skill로 순차 실행:
   - Ruff Lint + Fix → Ruff Format → Mypy → Pytest
2. 자동 수정 불가 항목은 file:line 참조와 함께 수정 제안 출력

## 출력 형식

```
=== Clean Report ===
Ruff Lint:    PASS|FIXED|FAIL (N fixed, N remaining)
Ruff Format:  PASS|FIXED
Mypy:         PASS|FAIL (N errors)
Tests:        PASS|FAIL (N/total)
===
Overall:      CLEAN|ISSUES_REMAIN
```

## 플래그

- `--fix-only`: 자동 수정만, 잔여 이슈 보고 생략
- `--no-test`: pytest 단계 건너뛰기
- `--strict`: 경고를 에러로 처리
