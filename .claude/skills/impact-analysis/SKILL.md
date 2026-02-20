---
name: impact-analysis
description: Analyzes change impact before code modifications to prevent regression
version: 4.0.0
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
trigger: "Before ANY code modification or refactoring"
---

## Quick Reference
- **필수**: 모든 파일 수정 전 실행 (신규 standalone 파일 제외)
- **의존성 추적**: `Grep(pattern: "from {module} import|import {module}", path: "src/")`
- **Impact score**: 1-10, score > 7이면 human approval 필요
- **Memory recall**: `md-recall-memory.sh "{module}"` 로 과거 변경 이력 확인
- **Output**: 구조화된 영향도 리포트

---

# Skill: Impact Analysis

> **Goal**: Prevent regression by understanding dependency chains before code changes.
> **Priority**: MANDATORY - Must be executed before any file modification.
> **Scope**: Grep/Glob 네이티브 도구로 의존성 분석. 외부 종속성 없음.

---

## Procedure

### Step 1: Identify Targets

List the files you intend to modify.

```
target_files = ["src/utils.ts", "src/models.ts"]
```

### Step 2: Run Impact Analysis

Grep을 사용하여 의존성 체인을 분석한다.

```
# import/require 검색으로 의존성 추적
Grep(pattern: "from.*utils.*import|import.*utils|require.*utils", path: "src/", output_mode: "files_with_matches")
Grep(pattern: "from.*models.*import|import.*models|require.*models", path: "src/", output_mode: "files_with_matches")

# 테스트 커버리지 확인
Grep(pattern: "utils|models", path: "tests/", output_mode: "files_with_matches")
```

### Step 3: Memory Recall (과거 변경 이력)

```bash
bash scripts/md-recall-memory.sh "utils" "." 5 compact
```

과거 deviation이나 root-cause가 있으면 주의 필요.

### Step 4: Review Impact Report

Check the following areas in the report:

| Area | What to Look For |
|------|------------------|
| **Incoming Dependencies** | Who calls these files? |
| **Outgoing Dependencies** | What do these files call? |
| **High-Risk Warnings** | Circular dependencies, core API usage |
| **Test Coverage** | Which tests cover this code? |

### Step 5: Calculate Impact Score

| Factor | Score |
|--------|-------|
| 0-2 dependents | +1 |
| 3-5 dependents | +3 |
| 6+ dependents | +5 |
| Core/shared module | +2 |
| Has test coverage | -1 |
| No test coverage | +2 |

**Impact Score > 7**: Require human approval before proceeding.

### Step 6: Plan Mitigation

If high impact is detected:
1. Update `.gsd/STATE.md` to include verification steps
2. Add affected dependent modules to test scope
3. Consider incremental rollout strategy

---

## Compliance Rules

| Rule | Description |
|------|-------------|
| **Mandatory** | You MUST NOT skip this step for any file modification |
| **Exception** | New standalone files don't require analysis |
| **Escalation** | If impact score > 7, require human approval before proceeding |

---

## Output Format

```
=== Impact Analysis Report ===
Target: src/utils.ts
Impact Score: 5/10

Incoming Dependencies (3):
  - src/api.ts:15
  - src/services/auth.ts:8
  - tests/test_utils.ts:1

Outgoing Dependencies (1):
  - src/constants.ts

Test Coverage: YES (tests/test_utils.ts)

Recommendation: Safe to proceed with standard testing
===
```
