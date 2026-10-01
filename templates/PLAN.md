# PLAN.md Template

> Verbatim copy of the format in `skills/planner/references/plan-structure.md` (the single source — edit there first, then copy here).

```markdown
---
phase: {N}
plan: {M}
wave: {W}
depends_on: []
files_modified: []
autonomous: true
gap_closure: false
user_setup: []
cross_phase_invariants:
  inherit: []   # copy the previous plan's inherit + new verbatim
  new: []       # invariants introduced by this phase

must_haves:
  truths: []
  artifacts: []
  key_links: []
---

# Plan {N}.{M}: {Descriptive Name}

<objective>
{What this plan accomplishes}

Purpose: {Why this matters}
Output: {What artifacts will be created}
</objective>

<context>
Load for context:
- .hxsk/SPEC.md
- .hxsk/ARCHITECTURE.md (if exists)
- {relevant source files}
</context>

<tasks>

<task type="auto">
  <name>{Clear task name}</name>
  <files>{exact/file/paths.ext}</files>
  <action>
    {Specific instructions}
    AVOID: {common mistake} because {reason}
  </action>
  <verify>{command or check}</verify>
  <done>{measurable criteria}</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] {Must-have 1}
- [ ] {Must-have 2}
</verification>

<success_criteria>
- [ ] All tasks verified
- [ ] Must-haves confirmed
</success_criteria>
```
