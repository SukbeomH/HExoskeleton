---
name: Impact Analysis
description: Analyzes the impact of code changes to prevent regressions.
version: 1.0.0
---

# Skill: Impact Analysis

> **Tool**: `agentic_impact`
> **Trigger**: Before ANY code modification or refactoring.
> **Goal**: Prevent regression by understanding dependency chains.

---

## 🚦 Procedure

1. **Identify Targets**: List the files you intend to modify.
2. **Run Analysis**: Execute the `agentic_impact` tool with the target file list.
   ```python
   agentic_impact(file_paths=["src/utils.py", "src/models.py"])
   ```
3. **Review Report**:
   - Check for **Incoming Dependencies** (who calls these files?).
   - Check for **Outgoing Dependencies** (what do these files call?).
   - Look for high-risk warnings (circular dependencies, core api usage).
4. **Plan Mitigation**: If high impact is detected, update your `PLAN.md` to include verification steps for affected dependent modules.

## ⚠️ Compliance
- **Mandatory**: You must NOT skip this step for any file modification logic.
- **Exception**: Creating new, standalone files does not require impact analysis, but `codegraph index` should be run afterwards.
