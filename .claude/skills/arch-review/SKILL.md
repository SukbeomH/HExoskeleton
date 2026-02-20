---
name: arch-review
description: Validates architectural rules and ensures design quality
version: 4.0.0
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
trigger: "Before merging PRs or completing major features"
---

## Quick Reference
- **순환 import**: `Grep(pattern: "from.*import", path: "src/")` → 그래프 분석
- **복잡도 검사**: `bash .claude/skills/arch-review/scripts/check_complexity.sh`
- **레이어 검증**: UI → Service → Repository 순방향만 허용
- **Severity**: LOW (log), MEDIUM (DECISIONS.md 기록), HIGH (block), CRITICAL (stop)
- **Memory recall**: `md-recall-memory.sh "architecture"` 검색 후 일관성 확인

---

# Skill: Architecture Review

> **Goal**: Validate code changes against architectural rules and patterns.
> **Scope**: Uses Grep/Glob/Read로 architecture validation 수행. 외부 종속성 없음.

---

## Pre-Review: Memory Recall

아키텍처 리뷰 전 과거 결정 사항을 recall하여 일관성을 검증한다:

```bash
bash scripts/md-recall-memory.sh "architecture" "." 5 compact
```

또는 네이티브 도구:
```
Grep(pattern: "architecture|arch.*decision", path: ".gsd/memories/architecture-decision/", output_mode: "files_with_matches")
```

---

## Procedure

### Step 1: Run Architecture Check

Grep/Glob을 사용하여 구조 검증:

```
# 순환 import 후보 검출 (같은 디렉토리 내 상호 참조)
Grep(pattern: "from \\.\\. import|from \\. import", path: "src/", output_mode: "files_with_matches")

# 레이어 위반 검출 (예: UI가 Repository를 직접 호출)
Grep(pattern: "from.*repository.*import|import.*repository", path: "src/ui/", output_mode: "files_with_matches")
Grep(pattern: "from.*ui.*import|import.*ui", path: "src/repository/", output_mode: "files_with_matches")
```

복잡도 검사 (shellcheck 기반):
```bash
bash .claude/skills/arch-review/scripts/check_complexity.sh
```

### Step 2: Verify Boundary Compliance

Cross-check against defined boundaries:

| Boundary | Check |
|----------|-------|
| Layer isolation | UI → Service → Repository only |
| Circular deps | No cycles in call graph |
| External calls | Only via approved adapters |

### Step 3: Generate Report & Store Memory

Compile findings into a structured report.
중요한 아키텍처 결정은 메모리에 저장:

```bash
bash scripts/md-store-memory.sh \
  "Architecture Decision: {title}" \
  "{context and decision}" \
  "architecture,decision" \
  "architecture-decision"
```

---

## Output Format

```json
{
  "status": "PASS | WARN | FAIL",
  "violations": [
    {
      "type": "layer_violation",
      "source": "src/ui/Dashboard.tsx",
      "target": "src/repository/UserRepo.ts",
      "severity": "HIGH",
      "recommendation": "Add service layer"
    }
  ],
  "patterns_matched": ["repository-pattern", "facade-pattern"]
}
```

---

## Escalation Matrix

| Severity | Action |
|----------|--------|
| LOW | Log warning, proceed |
| MEDIUM | Require acknowledgment in DECISIONS.md |
| HIGH | Block and require human approval |
| CRITICAL | Stop all work, escalate to tech lead |

## Scripts

- `scripts/check_complexity.sh`: Check shell script complexity via shellcheck
