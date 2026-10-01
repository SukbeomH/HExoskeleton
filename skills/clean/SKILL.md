---
name: clean
description: "Lints and formats shell scripts with shellcheck and shfmt and fixes the findings. Use before running or committing shell scripts, or when asked to lint, format or clean up scripts (린트, 포맷팅, 스크립트 정리)."
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
git ls-files -z '*.sh' | xargs -0 shfmt -w -i 4
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

## Iron Laws
NO EXECUTE WITHOUT CLEAN FIRST
NO COMMIT WITHOUT CLEAN CHECK FIRST
NO FORMAT WITHOUT LINT FIRST
NO FINAL_REPORT WITHOUT LINT_AND_FORMAT RESULTS
