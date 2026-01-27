---
description: Standard workflow for fixing a bug
---

# Bug Fix Workflow

## Prerequisites
- [ ] Bug is reproducible
- [ ] Issue is documented in `.specs/PLAN.md`

## Steps

### 1. Reproduce
Confirm the bug exists. Document reproduction steps.

### 2. Locate
Use `codegraph_search` to find relevant code.
```
codegraph_search(query="ErrorComponent")
```

### 3. Impact Analysis
Identify all affected paths before fixing.
```
agentic_impact(file_paths=["src/buggy_file.py"])
```

### 4. Fix
Implement the minimal change that resolves the issue.

### 5. Test
Run the test suite to confirm the fix doesn't break anything.
```bash
npm run test
```

### 6. Regression Check
If dependencies were affected, add tests for them.

### 7. Update State
Mark the bug as resolved in `.specs/PLAN.md`.
