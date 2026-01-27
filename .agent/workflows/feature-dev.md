---
description: Standard workflow for developing a new feature
---

# Feature Development Workflow

## Prerequisites
- [ ] SPEC.md is finalized
- [ ] PLAN.md has the feature task defined

## Steps

### 1. Context Check
Read the relevant sections of `.specs/SPEC.md` and `.specs/PLAN.md`.

### 2. Impact Analysis
Run `agentic_impact` on the files you intend to modify.
```
agentic_impact(file_paths=["src/target_file.py"])
```

### 3. Implementation
Write code following the plan. Commit after each sub-task.

### 4. Architecture Check
If the change involves cross-module interaction, run `codegraph_search` to verify patterns.

### 5. Verification
Run the test suite:
```bash
npm run test
```

### 6. Update State
Mark the task as complete in `.specs/PLAN.md`.

### 7. Re-index (if new files created)
```bash
codegraph index
```
