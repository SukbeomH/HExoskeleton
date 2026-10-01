# Checkpoint Protocol — Full Detail

## Checkpoint Protocol

When encountering `type="checkpoint:*"`:

**STOP immediately.** Do not continue to next task.

---

## Checkpoint Types

**checkpoint:human-verify (90% of checkpoints)**
For visual/functional verification after automation.

```markdown
### Checkpoint Details

**What was built:**
{Description of completed work}

**How to verify:**
1. {Step 1 - exact command/URL}
2. {Step 2 - what to check}
3. {Step 3 - expected behavior}

### Awaiting
Type "approved" or describe issues to fix.
```

---

**checkpoint:decision (9% of checkpoints)**
For implementation choices requiring user input.

```markdown
### Checkpoint Details

**Decision needed:** {What's being decided}

**Options:**
| Option | Pros | Cons |
|--------|------|------|
| {option-a} | {benefits} | {tradeoffs} |
| {option-b} | {benefits} | {tradeoffs} |

### Awaiting
Select: [option-a | option-b]
```

---

**checkpoint:human-action (1% - rare)**
For truly unavoidable manual steps.

```markdown
### Checkpoint Details

**Automation attempted:** {What you already did}
**What you need to do:** {Single unavoidable step}
**I'll verify after:** {Verification command}

### Awaiting
Type "done" when complete.
```

---

## Checkpoint Return Format

When you hit a checkpoint or auth gate, return this EXACT structure:

```markdown
## CHECKPOINT REACHED

**Type:** [human-verify | decision | human-action]
**Plan:** {phase}-{plan}
**Progress:** {completed}/{total} tasks complete

### Completed Tasks
| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | {task name} | {hash} | {files} |

### Current Task
**Task {N}:** {task name}
**Status:** {blocked | awaiting verification | awaiting decision}
**Blocked by:** {specific blocker}

### Checkpoint Details
{Checkpoint-specific content}

### Awaiting
{What user needs to do/provide}
```

---

## Continuation Handling

If spawned as a continuation agent (prompt has completed tasks):

1. **Verify previous commits exist:**
   ```bash
   git log --oneline -5
   ```
   Check that commit hashes from completed tasks appear

2. **DO NOT redo completed tasks** — They're already committed

3. **Start from resume point** specified in prompt

4. **Handle based on checkpoint type:**
   - After human-action: Verify action worked, then continue
   - After human-verify: User approved, continue to next task
   - After decision: Implement selected option
