---
name: arch-review
description: Validates architectural rules and ensures design quality
version: 2.0.0
allowed-tools:
  - query
  - analyze_hotspots
  - list_entity_relationships
  - detect_code_clones
  - Read
trigger: "Before merging PRs or completing major features"
---

# Skill: Architecture Review

> **Goal**: Validate code changes against architectural rules and patterns.
> **Scope**: Uses code-graph-rag for architecture validation.

---

## Prerequisites

- Node.js must be installed (`node --version`)
- code-graph-rag MCP server must be configured in `.mcp.json` (`@er77/code-graph-rag-mcp`)

---

## Pre-Review: Memory Recall

아키텍처 리뷰 전 과거 결정 사항을 recall하여 일관성을 검증한다:

```
memory_search(query: "architecture decision", mode: "semantic")
```

과거 `architecture-decision` 메모리와 현재 변경의 일관성을 확인.
semantic 결과가 부족하면 `memory_search(query: "architecture", tags: ["arch", "decision"])` 로 보충.

---

## Procedure

### Step 1: Run Local Architecture Check
Use code-graph-rag to verify local structure compliance.

```
query("check architecture layering violations in src/")
```

### Step 2: Verify Boundary Compliance
Cross-check against defined boundaries:

| Boundary | Check |
|----------|-------|
| Layer isolation | UI → Service → Repository only |
| Circular deps | No cycles in call graph |
| External calls | Only via approved adapters |

### Step 3: Generate Report
Compile findings into a structured report.

---

## Output Format

```json
{
  "status": "PASS | WARN | FAIL",
  "violations": [
    {
      "type": "layer_violation",
      "source": "src/ui/Dashboard.tsx",
      "target": "src/repository/UserRepo.py",
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

- `scripts/check_complexity.sh`: Check McCabe complexity, argument counts, and naming conventions via ruff
- `scripts/find_circular_imports.py`: Detect circular import dependencies using DFS cycle detection. Output: JSON
