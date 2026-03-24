---
name: clean
description: Runs shell script quality checks (shellcheck, shfmt) across the codebase
trigger: "코드 품질 검사, 린트, 포맷팅 수정, shellcheck, shfmt, pre-commit quality gate"
---

## Quick Reference
- **Lint**: `shellcheck *.sh` (shell script 정적 분석)
- **Format**: `shfmt -w -i 4 *.sh` (shell script 포맷팅)
- **Script**: `bash .claude/skills/clean/scripts/run_quality_checks.sh`
- **Output**: `=== Clean Report ===` 형식, Overall CLEAN/ISSUES_REMAIN

---

# HXSK Clean Skill

<role>
You fix all shell script linting and formatting issues in the codebase.
Use this before committing or as a pre-execution quality gate.
</role>

---

## Workflow

### Step 1: ShellCheck (Lint)

```bash
# 모든 shell 스크립트 린트
find . -name "*.sh" -exec shellcheck {} \;

# 또는 스크립트 사용
bash .claude/skills/clean/scripts/run_quality_checks.sh
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

- `scripts/run_quality_checks.sh`: Run shellcheck and shfmt with structured report output
