---
name: arch-review
description: 아키텍처 규칙 위반을 검사하고 설계 품질을 보장합니다.
version: 1.2.0
allowed-tools:
  - agentic_architecture
  - neo4j_cypher_query
  - read_file
trigger: "Before merging PRs or completing major features"
---

# Skill: Architecture Review

> **Goal**: Validate code changes against architectural rules and patterns.
> **Scope**: Cross-references Local (CodeGraph) and Global (Neo4j) knowledge.

---

## 📋 Prerequisites

- Neo4j Global Hub must be accessible
- Architecture rules must be defined in `platform-core/graph-db/constraints.cypher`

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

### Step 2: Query Global Patterns
Search Neo4j for established patterns and anti-patterns.

```cypher
// Find similar implementations across projects
MATCH (f:Function)-[:IMPLEMENTS]->(p:Pattern)
WHERE p.name = $pattern_name
RETURN f.urn, f.project, p.best_practice
```

### Step 3: Check for Known Anti-Patterns

```cypher
// Detect potential issues
MATCH (f:Function {urn: $urn})-[:CALLS*1..3]->(cf:Function)
WHERE cf.tags CONTAINS 'deprecated'
RETURN f.name as caller, cf.name as deprecated_callee
```

### Step 4: Verify Boundary Compliance
Cross-check against defined boundaries:

| Boundary | Check |
|----------|-------|
| Layer isolation | UI → Service → Repository only |
| Circular deps | No cycles in call graph |
| External calls | Only via approved adapters |

### Step 5: Generate Report
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
  "patterns_matched": ["repository-pattern", "facade-pattern"],
  "global_context": {
    "similar_implementations": 3,
    "avg_quality_score": 8.2
  }
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
