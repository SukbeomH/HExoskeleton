---
description: Use when shell scripts need linting/formatting before execution or commit
  to ensure code quality.
name: clean
trigger: 코드 품질 검사, 린트, 포맷팅 수정, shellcheck, shfmt, pre-commit quality gate, 코드 정리,
  스크립트 정리, shell script clean, bash lint, bash format, 코드 정제, linting, formatting,
  fix shell, clean up scripts, shell script check, 코드 개선, commit 전 검사, 배포 전 검사, shell
  오류 수정, 포맷팅 자동화
---

## Quick Reference
- **Lint & Fix**: `shellcheck` 및 `shfmt`로 모든 shell 스크립트 오류 자동 수정
- **Report Format**: `=== Clean Report ===` 헤더와 `Overall: CLEAN|ISSUES_REMAIN` 포함
- **Execution Timing**: 커밋 전 또는 실행 전(`/execute`) 필수 품질 게이트 수행
- **Error Handling**: 이슈 발생 시 파일:라인 참조와 함께 구체적인 수정 내용 보고
- **Scope**: 코드베이스 내 모든 `*.sh` 파일 대상 전량 검사 및 수정

## Workflow

### Step 1: ShellCheck (Lint)

```bash
# 모든 shell 스크립트 린트
find . -name "*.sh" -exec shellcheck {} \;

# shfmt 포맷팅
shfmt -w -i 4 .hxsk/hooks/*.sh
```

Report what was found:
```
SHELLCHECK_ISSUES: <N> issues found
```

If issues exist, list them with file:line references.

### Step 2: shfmt (Format)

```bash
# 포맷 검사
shfmt -d -i 4 script.sh

# 자동 수정
shfmt -w -i 4 script.sh
```

Report results:
```
FORMAT: PASS | NEEDS_FORMAT | FIXED
```

---

## Output Summary

```
=== Clean Report ===
ShellCheck:   <PASS|FAIL|SKIP> (<N> issues)
Format:       <PASS|NEEDS_FORMAT|FIXED|SKIP>
===
Overall:      <CLEAN|ISSUES_REMAIN>
```

---

## Flags

- `--fix-only`: Only auto-fix formatting, don't report remaining issues

---

## Installation

```bash
# macOS
brew install shellcheck shfmt

# Ubuntu/Debian
apt install shellcheck
go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

---

## HXSK Integration

- **Pre-execute**: Run `/clean` before `/execute` to ensure clean baseline
- **Pre-commit**: Clean checks can be run before committing shell scripts

## Scripts

(없음 — shellcheck, shfmt 등 에이전트 네이티브 도구로 직접 수행)

## Iron Laws
NO EXECUTE WITHOUT CLEAN FIRST
NO COMMIT WITHOUT CLEAN CHECK FIRST
NO FORMAT WITHOUT LINT FIRST
NO FINAL_REPORT WITHOUT LINT_AND_FORMAT RESULTS
