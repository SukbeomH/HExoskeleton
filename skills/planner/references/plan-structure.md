# Plan Structure Reference

## PLAN.md Structure

This is the single PLAN format.

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

---

## Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `phase` | Yes | Phase number |
| `plan` | Yes | Plan number within phase |
| `wave` | Yes | Execution wave (1, 2, 3...) |
| `depends_on` | Yes | Plan IDs this plan requires |
| `files_modified` | Yes | Files this plan touches |
| `autonomous` | Yes | `true` if no checkpoints |
| `gap_closure` | No | `true` for plans that close verification gaps |
| `user_setup` | No | Human-required setup items |
| `cross_phase_invariants` | Yes | `inherit` (previous plan's inherit + new) and `new` invariants; violating one is a Rule 4 architecture checkpoint |
| `must_haves` | Yes | Goal-backward verification (`truths`, `artifacts`, `key_links`) — read by the `verifier` skill |

---

## User Setup Section

When external services involved:

```yaml
user_setup:
  - service: stripe
    why: "Payment processing"
    env_vars:
      - name: STRIPE_SECRET_KEY
        source: "Stripe Dashboard -> Developers -> API keys"
    dashboard_config:
      - task: "Create webhook endpoint"
        location: "Stripe Dashboard -> Developers -> Webhooks"
```

Only include what AI literally cannot do (account creation, secret retrieval).

---

## Dependency Graph

### Building Dependencies
1. Identify shared resources (files, types, APIs)
2. Determine creation order (types before implementations)
3. Group independent work into same wave
4. Sequential dependencies go to later waves

### Wave Assignment
- **Wave 1:** Foundation (types, schemas, utilities)
- **Wave 2:** Core implementations
- **Wave 3:** Integration and validation

### Vertical Slices vs Horizontal Layers
**Prefer vertical slices:** Each plan delivers a complete feature path.

```
✅ Vertical (preferred):
Plan 1: User registration (API + DB + validation)
Plan 2: User login (API + session + cookie)

❌ Horizontal (avoid):
Plan 1: All database models
Plan 2: All API endpoints
```

### File Ownership for Parallel Execution
Plans in the same wave MUST NOT modify the same files.

If two plans need the same file:
1. Move one to a later wave, OR
2. Split the file into separate modules

---

## TDD Detection

### When to Use TDD Plans

Detect TDD fit when:
- Complex business logic with edge cases
- Financial calculations
- State machines
- Data transformation pipelines
- Input validation rules

### TDD Plan Structure

```markdown
---
phase: {N}
plan: {M}
type: tdd
wave: {W}
---

# TDD Plan: {Feature}

## Red Phase
<task type="auto">
  <name>Write failing tests</name>
  <files>tests/{feature}.test.ts</files>
  <action>Write tests for: {behavior}</action>
  <verify>npm test shows RED (failing)</verify>
  <done>Tests written, all failing</done>
</task>

## Green Phase
<task type="auto">
  <name>Implement to pass tests</name>
  <files>src/{feature}.ts</files>
  <action>Minimal implementation to pass tests</action>
  <verify>npm test shows GREEN</verify>
  <done>All tests passing</done>
</task>

## Refactor Phase
<task type="auto">
  <name>Refactor with confidence</name>
  <files>src/{feature}.ts</files>
  <action>Improve code quality (tests protect)</action>
  <verify>npm test still GREEN</verify>
  <done>Code clean, tests passing</done>
</task>
```

---

## Planning from Verification Gaps

When the `verifier` skill records `gaps_found` in `.hxsk/VERIFICATION.md`, create targeted fix plans:

1. **Load the `Gaps` YAML** from the latest section of `.hxsk/VERIFICATION.md`
2. **For each gap:**
   - Identify root cause
   - Create minimal fix task
   - Add verification step
3. **Mark as gap closure:**
   ```yaml
   gap_closure: true
   ```

Gap closure plans:
- Execute with the `executor` skill like any other plan
- Smaller scope than normal plans
- Focus on single issue per plan
