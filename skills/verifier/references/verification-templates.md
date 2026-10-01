# VERIFICATION.md Templates

## Full VERIFICATION.md Format

```markdown
---
phase: {N}
verified: {timestamp}
status: {passed | gaps_found | human_needed}
score: {N}/{M} must-haves verified
is_re_verification: {true | false}
gaps: [...]  # If gaps_found
---

# Phase {N} Verification

## Must-Haves

### Truths
| Truth | Status | Evidence |
|-------|--------|----------|
| {truth 1} | ✓ VERIFIED | {how verified} |
| {truth 2} | ✗ FAILED | {what's missing} |

### Artifacts
| Path | Exists | Substantive | Wired |
|------|--------|-------------|-------|
| src/components/Chat.tsx | ✓ | ✓ | ✗ |

### Key Links
| From | To | Via | Status |
|------|-----|-----|--------|
| Chat.tsx | api/chat | fetch | ✗ NOT_WIRED |

## Anti-Patterns Found
- 🛑 {blocker}
- ⚠️ {warning}

## Human Verification Needed
### 1. Visual Review
**Test:** Open http://localhost:3000/chat
**Expected:** Message list renders with real data
**Why human:** Visual layout verification

## Gaps (if any)
{Structured gap analysis for planner}

## Verdict
{Status explanation}
```

## Must-Haves Structure

### Truths (from PLAN frontmatter or derived)
```yaml
truths:
  - "User can see existing messages"
  - "User can send a message"
```

### Artifacts
```yaml
artifacts:
  - path: "src/components/Chat.tsx"
    provides: "Message list rendering"
```

### Key Links
```yaml
key_links:
  - from: "Chat.tsx"
    to: "api/chat"
    via: "fetch in useEffect"
```

## Anti-Patterns Found

**Categories:**
- 🛑 Blocker: Prevents goal achievement
- ⚠️ Warning: Indicates incomplete work
- ℹ️ Info: Notable but not problematic

## Human Verification Needed

**Always needs human:**
- Visual appearance (does it look right?)
- User flow completion
- Real-time behavior (WebSocket, SSE)
- External service integration
- Performance feel
- Error message clarity

**Format:**
```markdown
### 1. {Test Name}
**Test:** {What to do}
**Expected:** {What should happen}
**Why human:** {Why can't verify programmatically}
```

## Gaps (Structured for `/plan --gaps`)

```yaml
---
phase: {N}
verified: {timestamp}
status: gaps_found
score: {N}/{M} must-haves verified
gaps:
  - truth: "User can see existing messages"
    status: failed
    reason: "Chat.tsx doesn't fetch from API"
    artifacts:
      - path: "src/components/Chat.tsx"
        issue: "No useEffect with fetch call"
    missing:
      - "API call in useEffect to /api/chat"
      - "State for storing fetched messages"
      - "Render messages array in JSX"
---
```

## Verdict

**Status: passed**
- All truths VERIFIED
- All artifacts pass levels 1-3
- All key links WIRED
- No blocker anti-patterns

**Status: gaps_found**
- One or more truths FAILED
- OR artifacts MISSING/STUB
- OR key links NOT_WIRED
- OR blocker anti-patterns found

**Status: human_needed**
- All automated checks pass
- BUT items flagged for human verification

## Success Criteria

- [ ] Previous VERIFICATION.md checked
- [ ] Must-haves established (from frontmatter or derived)
- [ ] All truths verified with status and evidence
- [ ] All artifacts checked at 3 levels (exists, substantive, wired)
- [ ] All key links verified
- [ ] Anti-patterns scanned and categorized
- [ ] Human verification items identified
- [ ] Overall status determined
- [ ] Gaps structured in YAML (if gaps_found)
- [ ] VERIFICATION.md created
- [ ] Results returned to orchestrator
