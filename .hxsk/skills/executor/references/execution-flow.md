# Execution Flow — Full Detail

## Step 1: Load Project State

Before any operation, read project state:

```bash
cat .hxsk/STATE.md 2>/dev/null
```

**If file exists:** Parse and internalize:
- Current position (phase, plan, status)
- Accumulated decisions (constraints on this execution)
- Blockers/concerns (things to watch for)

**If file missing but .hxsk/ exists:** Reconstruct from existing artifacts.

**If .hxsk/ doesn't exist:** Error — project not initialized.

---

## Step 2: Load Plan

Read the plan file provided in your prompt context.

Parse:
- Frontmatter (phase, plan, type, autonomous, wave, depends_on)
- Objective
- Context files to read
- Tasks with their types
- Verification criteria
- Success criteria

---

## Step 3: Determine Execution Pattern

**Pattern A: Fully autonomous (no checkpoints)**
- Execute all tasks sequentially
- Create SUMMARY.md
- Commit and report completion

**Pattern B: Has checkpoints**
- Execute tasks until checkpoint
- At checkpoint: STOP and return structured checkpoint message
- Fresh continuation agent resumes

**Pattern C: Continuation (spawned to continue)**
- Check completed tasks in your prompt
- Verify those commits exist
- Resume from specified task

**Pattern D: Parallel wave dispatch (has wave structure)**
- Read wave assignments from PLAN.md
- For each wave (sequential):
  - Validate file ownership within wave (same-wave plans MUST NOT modify same files)
  - Dispatch wave items as parallel subagents (`Agent` tool, `isolation: "worktree"`)
  - Wait for all subagents to complete
  - Review results and merge worktrees (`bash .hxsk/scripts/merge-worktrees.sh`)
- After all waves: run overall verification
- Use `dispatcher` skill for detailed orchestration protocol

**Pattern selection:**
- Has WAVE_STRUCTURE with 2+ wave-1 plans → **Pattern D** (parallel dispatch)

---

## Step 4: Execute Tasks

For each task:

1. **Read task type**

2. **If `type="auto"`:**
   - Work toward task completion
   - If CLI/API returns authentication error → Handle as authentication gate
   - When you discover additional work not in plan → Apply deviation rules
   - Run the verification
   - Confirm done criteria met
   - **Commit the task** (see commit protocol)
   - Track completion and commit hash for Summary

3. **If `type="checkpoint:*"`:**
   - STOP immediately
   - Return structured checkpoint message
   - You will NOT continue — a fresh agent will be spawned

4. Run overall verification checks
5. Document all deviations in Summary

---

## Step 5: Handle Deviations

Apply Deviation Rules (Rule 1–4) automatically.
Track all deviations for SUMMARY.md documentation.
See `deviation-rules.md` for full rule definitions.

---

## Step 6: Commit Tasks

After each task completes:

```bash
git add -A
git commit -m "feat({phase}-{plan}): {task description}"
```

**Commit message format:**
- `feat` for new features
- `fix` for bug fixes
- `refactor` for restructuring
- `docs` for documentation
- `test` for tests only

**Track commit hash** for Summary reporting.

---

## Step 7: Create SUMMARY.md

After plan completion, create `.hxsk/phases/{N}/{plan}-SUMMARY.md`.
See `commit-protocol.md` for the full SUMMARY.md format template.

---

## Step 8: Store Memory

After writing SUMMARY.md, store an execution summary memory:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Plan {phase-plan} Summary" \
  "{tasks completed, deviations applied, verification results}" \
  "execution,{phase-plan}" \
  "execution-summary"
```
