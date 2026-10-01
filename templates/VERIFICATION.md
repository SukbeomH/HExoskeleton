# VERIFICATION.md Template

> Copy this template when creating phase verification reports.

```markdown
---
phase: {N}
verified_at: {YYYY-MM-DD HH:MM}
verdict: PASS | FAIL | PARTIAL
pass_count: {X}
total_count: {Y}
blockers: {0}
high: {0}
---

# Phase {N} Verification Report

## Summary

**{X}/{Y}** must-haves verified
**Verdict:** {PASS | FAIL | PARTIAL}

| Severity | Count |
|----------|-------|
| Blocker  | {0}   |
| High     | {0}   |
| Medium   | {0}   |
| Nitpick  | {0}   |

## Must-Haves

### ✅ 1. {Must-have description}
**Status:** PASS
**Method:** {How this was verified}
**Evidence:**
```
{Actual command output or screenshot reference}
```

### ❌ 2. {Must-have description}
**Status:** FAIL
**Severity:** {Blocker | High | Medium | Nitpick}
**Method:** {How this was verified}
**Expected:** {What should happen}
**Actual:** {What actually happened}
**Evidence:**
```
{Actual command output}
```
**Gap:** {What needs to be fixed}

### ⏭️ 3. {Must-have description}
**Status:** SKIPPED
**Reason:** {Why this couldn't be verified}

## Gap Closure Required

{If verdict is FAIL or PARTIAL, list by severity}

### Blockers (must fix before proceeding)
1. **{Gap}:** {Description and fix approach}

### High Priority (should fix before proceeding)
1. **{Gap}:** {Description and fix approach}

### Medium (can fix in follow-up)
1. **{Gap}:** {Description}

## Next Steps

{Based on verdict}

- If PASS: Proceed to next phase
- If Blockers exist: Run `/execute {N} --gaps-only` immediately
- If High only: Fix then re-verify with `/verify {N}`
- If Medium only: Proceed, track in TODO.md
```

## Severity Classification

| Severity | Definition | Action |
|----------|-----------|--------|
| **Blocker** | 기능 장애, 보안 취약점, 데이터 손실 위험 | 즉시 수정, 다음 단계 진행 불가 |
| **High** | 주요 품질 문제, 테스트 누락, 성능 저하 | 다음 단계 전 수정 권장 |
| **Medium** | 리팩토링, 문서화 개선, 더 나은 패턴 | 후속 작업에서 처리 가능 |
| **Nitpick** | 스타일, 네이밍 제안, 코드 포맷 | 선택적 반영 |

## Evidence Types

| Verification | Evidence Required |
|--------------|-------------------|
| API endpoint | curl command + response |
| UI behavior | Screenshot |
| Test suite | Test output |
| File exists | `ls` or `dir` output |
| Build passes | Build command output |
| Type check | `mypy` output |
| Lint clean | `ruff check` output |
