# GSD Methodology — Mission Control Rules

> **Get Shit Done**: A spec-driven, context-engineered development methodology.
>
> These rules enforce disciplined, high-quality autonomous development.

---

## Rule 0: Python Environment Management 🐍

**ALWAYS use `uv` for Python project management.**

| Task | Command | ❌ Never Use |
|------|---------|-------------|
| Install dependencies | `uv sync` | `pip install`, `poetry install` |
| Add dependency | `uv add <package>` | `pip install`, `poetry add` |
| Run Python script | `uv run python <script>` | `python <script>` directly |
| Run tests | `uv run pytest` | `pytest` directly |
| Create virtual env | `uv venv` | `python -m venv` |

**Rationale:**
- `uv` is 10-100x faster than pip/poetry
- Automatic lockfile management (`uv.lock`)
- Consistent, reproducible environments across all machines

**Exceptions:**
- System Python for non-project scripts
- Docker containers with pre-installed dependencies

---

## Core Principles

1. **Plan Before You Build** — No code without specification
2. **State Is Sacred** — Every action updates persistent memory
3. **Context Is Limited** — Prevent degradation through hygiene
4. **Verify Empirically** — No "trust me, it works"
5. **Use uv for Python** — Never pip install directly

---

## Rule 1: The Planning Lock 🔒

**BEFORE writing any implementation code, you MUST verify:**

```
✓ .gsd/SPEC.md exists AND contains "Status: FINALIZED"
✓ .gsd/ROADMAP.md exists AND has at least one defined phase
```

**If either condition fails:**
- STOP immediately
- Inform the user that planning must be completed first
- Offer to help finalize the SPEC or create the ROADMAP
- DO NOT write any implementation code

**Exceptions:**
- Documentation updates (README, comments)
- Configuration files for tooling
- Test scaffolding (but not implementation)

---

## Rule 2: State Persistence 💾

**AFTER every successful task completion, you MUST:**

1. **Update `.gsd/STATE.md`** with:
   - Current position (phase, task, status)
   - What was just accomplished
   - Next steps

2. **Update `.gsd/JOURNAL.md`** with session entry if:
   - Significant milestone reached
   - Session is ending
   - Major decision was made

**This is non-negotiable.** State persistence ensures context continuity across sessions.

---

## Rule 3: Context Hygiene 🧹

**IF debugging exceeds 3 consecutive failed attempts:**

1. **STOP** the current approach
2. **Summarize** to `.gsd/STATE.md`:
   - What was tried
   - What failed
   - Current hypothesis
3. **Document** the blocker in `.gsd/DECISIONS.md`
4. **Recommend** the user start a fresh session with this context

**Rationale:** Extended debugging in a polluted context leads to:
- Circular reasoning
- Missed obvious solutions
- Hallucinated fixes

A fresh context with documented state often immediately sees the solution.

---

## Rule 4: Empirical Validation ✅

**Every change MUST be verified before marking complete:**

| Change Type | Verification Method |
|-------------|---------------------|
| UI changes | Browser screenshot confirming visual state |
| API changes | Terminal command showing correct response |
| Build changes | Successful build/test command output |
| Config changes | Verification command proving effect |

**Never mark a phase "Done" based on:**
- "The code looks correct"
- "This should work"
- "I've made similar changes before"

**Always mark a phase "Done" based on:**
- Empirical evidence captured and documented
- Verification criteria from ROADMAP.md satisfied

---

## Workflow Integration

These rules integrate with the GSD workflows:

| Workflow | Rules Enforced |
|----------|----------------|
| `/map` | Updates ARCHITECTURE.md, STACK.md |
| `/plan` | Enforces Planning Lock, creates ROADMAP |
| `/execute` | Enforces State Persistence after each task |
| `/verify` | Enforces Empirical Validation |
| `/pause` | Triggers Context Hygiene state dump |
| `/resume` | Loads state from STATE.md |

---

## Quick Reference

```
Before coding    → Check SPEC.md is FINALIZED
After each task  → Update STATE.md
After 3 failures → State dump + fresh session
Before "Done"    → Empirical proof captured
```

---

*GSD Methodology adapted for Google Antigravity*
*Source: https://github.com/glittercowboy/get-shit-done*
