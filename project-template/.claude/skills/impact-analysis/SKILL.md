---
name: impact-analysis
description: 코드 변경 전 영향도를 분석하여 리그레션을 방지합니다.
version: 1.2.0
allowed-tools:
  - agentic_impact
  - codegraph_call_graph
  - read_file
trigger: "Before ANY code modification or refactoring"
---

# Skill: Impact Analysis

> **Goal**: Prevent regression by understanding dependency chains before code changes.
> **Priority**: MANDATORY - Must be executed before any file modification.

---

## 📋 Prerequisites

- CodeGraph index must be up-to-date (`codegraph index --tier balanced`)
- MCP server must be running (`python mcp/server.py`)

---

## 🚦 Procedure

### Step 1: Identify Targets
List the files you intend to modify.

```python
target_files = ["src/utils.py", "src/models.py"]
```

### Step 2: Run Impact Analysis
Execute the `agentic_impact` tool with the target file list.

```python
# Using MCP tool
result = await agentic_impact(file_paths=target_files)
```

### Step 3: Review Impact Report

Check the following areas in the report:

| Area | What to Look For |
|------|------------------|
| **Incoming Dependencies** | Who calls these files? |
| **Outgoing Dependencies** | What do these files call? |
| **High-Risk Warnings** | Circular dependencies, core API usage |
| **Test Coverage** | Which tests cover this code? |

### Step 4: Cross-Reference with Global DB (Optional)
For high-impact changes, query Neo4j for historical context:

```cypher
MATCH (f:Function {urn: $urn})-[:RELATED_TO]->(issue:Issue)
WHERE issue.type = 'regression'
RETURN issue.description, issue.resolution
```

### Step 5: Plan Mitigation
If high impact is detected:
1. Update `.specs/PLAN.md` to include verification steps
2. Add affected dependent modules to test scope
3. Consider incremental rollout strategy

---

## ⚠️ Compliance Rules

| Rule | Description |
|------|-------------|
| **Mandatory** | You MUST NOT skip this step for any file modification |
| **Exception** | New standalone files don't require analysis (but run `codegraph index` after) |
| **Escalation** | If impact score > 7, require human approval before proceeding |

---

## 📊 Output Format

```json
{
  "target_files": ["src/utils.py"],
  "impact_score": 5,
  "incoming_deps": ["src/api.py", "tests/test_utils.py"],
  "outgoing_deps": ["src/constants.py"],
  "warnings": [],
  "recommendation": "Safe to proceed with standard testing"
}
```
