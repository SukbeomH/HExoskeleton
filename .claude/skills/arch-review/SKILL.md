---
name: arch-review
description: 아키텍처 규칙 위반을 검사하고 설계 품질을 보장합니다.
version: 1.2.0
allowed-tools:
  - agentic_architecture
  - read_file
trigger: "Before merging PRs or completing major features"
---

# Skill: Architecture Review

> **Goal**: Validate code changes against architectural rules and patterns.
> **Scope**: Uses Local (CodeGraph) knowledge for architecture validation.

---

## 📋 Prerequisites

- CodeGraph index must be up-to-date (`codegraph index . -r`)

---

## 🚦 Procedure

### Step 1: Run Local Architecture Check
Use CodeGraph to verify local structure compliance.

```python
# Check for layering violations
result = await agentic_architecture(
    check_type="layer_dependency",
    scope="src/"
)
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

## 📊 Output Format

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

## ⚠️ Escalation Matrix

| Severity | Action |
|----------|--------|
| LOW | Log warning, proceed |
| MEDIUM | Require acknowledgment in DECISIONS.md |
| HIGH | Block and require human approval |
| CRITICAL | Stop all work, escalate to tech lead |
