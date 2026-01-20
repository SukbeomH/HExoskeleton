# Example: Complete Development Workflow

This example demonstrates a full GSD workflow cycle using the LLM Boilerplate Pack.

---

## Scenario

**Goal**: Add a new feature to export Dashboard logs as CSV

---

## Step 1: Update SPEC.md

Add to "Nice-to-Haves" section:
```markdown
- [x] CSV export functionality for Dashboard logs
```

---

## Step 2: Create Phase in ROADMAP.md

```markdown
### Milestone 2: Antigravity Integration

- [ ] **Phase 6**: CSV Export Feature
  - Add export button to Dashboard UI
  - Implement CSV generation from SQLite
  - Add download endpoint
```

---

## Step 3: Create PLAN.md

Create `.gsd/plans/PLAN-2-6.md`:

```markdown
# Plan for Phase 2-6: CSV Export

## Objective
Add CSV export functionality to Option C Dashboard for downloading logs.

## Tasks

### Wave 1: Backend

<task type="auto">
  <name>Create CSV export endpoint</name>
  <files>kits/option_c/runtime/app.py</files>
  <action>
    Add GET /api/logs/export endpoint
    Query SQLite database for all logs
    Convert to CSV using csv module
    Return with proper headers (Content-Type: text/csv)
  </action>
  <verify>curl http://localhost:8001/api/logs/export returns CSV</verify>
  <done>Endpoint returns properly formatted CSV file</done>
</task>

### Wave 2: Frontend

<task type="auto">
  <name>Add export button to Dashboard</name>
  <files>kits/option_c/runtime/templates/dashboard.html</files>
  <action>
    Add "Export CSV" button next to Clear button
    Wire up onclick to fetch /api/logs/export
    Trigger browser download with proper filename
  </action>
  <verify>Click button downloads logs.csv file</verify>
  <done>Button downloads CSV with current timestamp in filename</done>
</task>
```

---

## Step 4: Execute with /execute Command

In Antigravity:
```
/execute 2-6
```

This would:
1. Execute Wave 1 tasks
2. Make atomic git commits
3. Execute Wave 2 tasks
4. Make additional commits

---

## Step 5: Verify with Evidence

Create `.gsd/verifications/VERIFY-2-6.md`:

```markdown
# Verification for Phase 2-6

## Must-Haves Check

### Requirement 1: CSV Export Endpoint
- **Expected**: GET request returns CSV data
- **Actual**: Endpoint returns CSV with correct headers
- **Evidence**:
  ```bash
  $ curl -I http://localhost:8001/api/logs/export
  HTTP/1.1 200 OK
  content-type: text/csv
  content-disposition: attachment; filename=logs_20260119.csv
  ```
- **Status**: ✅ Pass

### Requirement 2: Download Button
- **Expected**: Button triggers CSV download
- **Actual**: Clicking button downloads file
- **Evidence**:
  ![Export button](./screenshots/export-button.png)

  Downloaded file contents:
  ```csv
  id,timestamp,level,component,message
  1,2026-01-19T13:00:00,INFO,dashboard,"Started server"
  ```
- **Status**: ✅ Pass
```

---

## Step 6: Update STATE.md

```markdown
## Current Position

### Active Work
- ✅ CSV export feature complete

### Completed Today
- ✅ Created CSV export endpoint
- ✅ Added export button to Dashboard
- ✅ Verified functionality with evidence

### Next Steps
1. Update ROADMAP.md to mark Phase 6 complete
2. Consider adding JSON export option
```

---

## Step 7: Git History

After execution, git log shows:
```bash
abc123f feat(phase-2-6): create CSV export endpoint
def456g feat(phase-2-6): add export button to Dashboard
```

---

## Step 8: Update ROADMAP.md

Mark phase as complete:
```markdown
- [x] **Phase 6**: CSV Export Feature ✅
  - ✅ Add export button to Dashboard UI
  - ✅ Implement CSV generation from SQLite
  - ✅ Add download endpoint
```

---

## Final State

**Files Modified**:
- `kits/option_c/runtime/app.py` - Added export endpoint
- `kits/option_c/runtime/templates/dashboard.html` - Added button

**Files Created**:
- `.gsd/plans/PLAN-2-6.md` - Execution plan
- `.gsd/verifications/VERIFY-2-6.md` - Evidence
- Screenshots for documentation

**Git Commits**: 2 atomic commits

**Time Elapsed**: ~30 minutes (planning + execution + verification)

---

## Key Takeaways

1. **Planning First**: Creating PLAN.md before coding saves time
2. **Wave-Based Execution**: Backend first, then frontend (dependencies)
3. **Empirical Validation**: Screenshots and curl outputs prove it works
4. **Atomic Commits**: Each task gets its own commit for easy rollback
5. **State Updates**: STATE.md and ROADMAP.md stay current

---

This is the GSD methodology in action! 🚀
