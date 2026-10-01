# Goal-Backward Methodology

**Forward planning asks:** "What should we build?"
**Goal-backward planning asks:** "What must be TRUE for the goal to be achieved?"

Forward planning produces tasks. Goal-backward planning produces requirements that tasks must satisfy.

---

## Process

1. **Define done state:** What is true when the phase is complete?
2. **Identify must-haves:** Non-negotiable requirements
3. **Decompose to tasks:** What steps achieve each must-have?
4. **Order by dependency:** What must exist before something else?
5. **Group into plans:** 2-3 related tasks per plan

---

## Must-Haves Structure

```yaml
must_haves:
  truths:
    - "User can log in with valid credentials"
    - "Invalid credentials are rejected with 401"
  artifacts:
    - "src/app/api/auth/login/route.ts exists"
    - "JWT cookie is httpOnly"
  key_links:
    - "Login endpoint validates against User table"
```

---

## Anti-Patterns to Avoid

### ❌ Vague Tasks
```xml
<task type="auto">
  <name>Add authentication</name>
  <action>Implement auth</action>
  <verify>???</verify>
</task>
```

### ✅ Specific Tasks
```xml
<task type="auto">
  <name>Create login endpoint with JWT</name>
  <files>src/app/api/auth/login/route.ts</files>
  <action>
    POST endpoint accepting {email, password}.
    Query User by email, compare password with bcrypt.
    On match: create JWT with jose, set httpOnly cookie, return 200.
    On mismatch: return 401.
  </action>
  <verify>curl -X POST localhost:3000/api/auth/login returns 200 + Set-Cookie</verify>
  <done>Valid creds → 200 + cookie. Invalid → 401.</done>
</task>
```

### ❌ Reflexive Chaining
```yaml
# Bad: Every plan refs previous
context:
  - .hxsk/phases/1/01-SUMMARY.md  # Plan 2 refs 1
  - .hxsk/phases/1/02-SUMMARY.md  # Plan 3 refs 2
```

### ✅ Minimal Context
```yaml
# Good: Only ref when truly needed
context:
  - .hxsk/SPEC.md
  - src/types.ts  # Actually needed
```

### ❌ Enterprise Theater (avoid all of these)
- Team structures, RACI matrices
- Stakeholder management
- Sprint ceremonies
- Human dev time estimates (hours, days, weeks)
- Change management processes
- Documentation for documentation's sake

If it sounds like corporate PM theater, delete it.
