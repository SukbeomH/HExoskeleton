---
description: Runs code quality checks (shellcheck, shfmt) and auto-fixes issues. Use before commits or as a pre-execution quality gate.
model: haiku
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Clean Agent

코드 품질 도구를 실행하고 자동 수정 가능한 이슈를 해결한다.

## 탑재 Skills

- `clean` — 셸 스크립트 품질 검사 (shellcheck, shfmt)

## 오케스트레이션

1. `clean` skill로 순차 실행:
   - shellcheck → shfmt → 프로젝트 린터 (있으면)
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
