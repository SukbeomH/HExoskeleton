---
name: Architecture Compliance Check
description: Validates code changes against architectural rules.
version: 1.0.0
---

# Skill: Architecture Review

> **Tool**: `codegraph_search` + Neo4j (Global)
> **Trigger**: When adding new dependencies or creating cross-module interactions.
> **Goal**: Detect architecture violations before they merge.

---

## 🚦 Procedure

1. **Identify Interaction**: Note the modules involved in your change.
2. **Check Local Graph**: Use `agentic_architecture` to validate patterns.
   ```python
   agentic_architecture(modules=["ServiceLayer", "RepositoryLayer"])
   ```
3. **Cross-Reference Global Rules** (if connected to Hub):
   - Query Neo4j for known architectural constraints.
   - Example: "Does module X have permission to call module Y?"
4. **Report Violations**: If a violation is found, document it in `DECISIONS.md` and seek approval.

## 🧱 Common Violations

| Violation | Description |
|-----------|-------------|
| **Circular Import** | Module A imports B, B imports A |
| **Layer Skip** | Controller directly accessing Repository (skipping Service) |
| **Boundary Breach** | Internal module exposed publicly |

## ⚠️ Compliance
- **Mandatory** for changes affecting more than one module.
- Log results in `.specs/PLAN.md` under "Verification".
