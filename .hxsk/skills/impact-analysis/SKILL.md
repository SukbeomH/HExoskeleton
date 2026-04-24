---
allowed-tools:
- Read
- Grep
- Glob
- Bash
description: Use when modifying any existing file (excluding new standalone files)
  to analyze dependencies and calculate impact score.
name: impact-analysis
trigger: 영향 분석, 변경 영향 범위, 의존성 분석, impact analysis, check what this affects, before
  modifying files, 수정 전 영향도 확인, 리그레이션 방지, 의존성 추적, 파급 효과 분석, 영향도 점수 계산, impact score,
  변경 전 확인, 리팩토링 전 분석, code impact, dependency chain, affected files, 승인 필요 확인, high
  impact check, before code change, dependency analysis
version: 4.0.0
---

## Quick Reference
- **실행 조건**: 모든 파일 수정 전 필수 (신규 standalone 파일 제외)
- **승인 기준**: Impact Score > 7 일 경우 반드시 Human Approval 필요
- **의존성 확인**: Grep 으로 import/require 체인 및 테스트 커버리지 필수 점검
- **리스크 관리**: 과거 변경 이력 (Memory Recall) 에서 deviation 유무 확인
- **이행 조치**: 고위험 시 STATE.md 검증 단계 추가 및 점진적 롤아웃 계획 수립

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
bash .hxsk/hooks/md-recall-memory.sh "utils" "." 5 compact
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
1. Update `.hxsk/STATE.md` to include verification steps
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

## Iron Laws
NO FILE MODIFICATION WITHOUT IMPACT ANALYSIS FIRST
NO PROCEEDING WITHOUT HUMAN APPROVAL FIRST WHEN IMPACT SCORE > 7
NO IMPACT ANALYSIS COMPLETE WITHOUT DEPENDENCY TRACING AND MEMORY RECALL FIRST
NO SKIP OF ANALYSIS WITHOUT VERIFICATION OF STANDALONE STATUS FIRST
