# VERIFICATION.md Format

`.hxsk/VERIFICATION.md` (created by `hxsk-init`) is the **only** verification record. Do not create per-phase `*-VERIFICATION.md` files.

- Each verification run **appends one dated section** at the end of the file, in the format below.
- After appending, update the `## Latest` line near the top so it points at the newest section (session start shows only the top of the file).
- The `verifier` agent has no write tools: it returns the section text, and the caller appends it and updates `## Latest`.
- Executor, plan-checker, empirical-validation and the gate conventions all record executed evidence here, in this format.

## File Layout

````markdown
# Verification

## Latest
- {YYYY-MM-DD} — {scope} — {passed | gaps_found | human_needed} ({N}/{M})

<!-- One dated section per verification run, appended below (oldest first). -->

## {YYYY-MM-DD} — {scope}
...
````

## Section Format

````markdown
## {YYYY-MM-DD} — {scope: phase N / plan N.M / task / PR #}
- **Status:** passed | gaps_found | human_needed
- **Score:** {N}/{M} must-haves verified
- **Re-verification:** yes | no

### Commands Run
| Command | Exit | Key output |
|---------|------|------------|
| `npm test` | 0 | 42 passed, 0 failed |

### Truths
| Truth | Status | Evidence |
|-------|--------|----------|
| {truth 1} | ✓ VERIFIED | {command + output excerpt} |
| {truth 2} | ✗ FAILED | {what's missing} |

### Artifacts
| Path | Exists | Substantive | Wired |
|------|--------|-------------|-------|
| src/components/Chat.tsx | ✓ | ✓ | ✗ |

### Key Links
| From | To | Via | Status |
|------|-----|-----|--------|
| Chat.tsx | api/chat | fetch | ✗ NOT_WIRED |

### Anti-Patterns
- 🛑 {blocker}
- ⚠️ {warning}

### Human Verification Needed
1. **Test:** {what to do} — **Expected:** {what should happen} — **Why human:** {why it can't be checked programmatically}

### Gaps
```yaml
gaps:
  - truth: "User can see existing messages"
    status: failed
    reason: "Chat.tsx doesn't fetch from API"
    artifacts:
      - path: "src/components/Chat.tsx"
        issue: "No useEffect with fetch call"
    missing:
      - "API call in useEffect to /api/chat"
      - "Render messages array in JSX"
```

### Verdict
{Why this status, in one short paragraph}
````

Status, Commands Run and Verdict are always present. Omit other subsections that do not apply (e.g. no Key Links for a CLI change, no Gaps when `passed`).

## Must-Haves Structure

Read from PLAN frontmatter (`must_haves`, see `../planner/references/plan-structure.md`) or derive from the goal:

```yaml
must_haves:
  truths:
    - "User can see existing messages"
  artifacts:
    - path: "src/components/Chat.tsx"
      provides: "Message list rendering"
  key_links:
    - from: "Chat.tsx"
      to: "api/chat"
      via: "fetch in useEffect"
```

## Anti-Pattern Categories

- 🛑 Blocker: prevents goal achievement
- ⚠️ Warning: indicates incomplete work
- ℹ️ Info: notable but not problematic

## Human Verification

Always needs a human: visual appearance, user flow completion, real-time behavior (WebSocket, SSE), external service integration, performance feel, error message clarity.

## Status Rules

- **passed** — all truths VERIFIED, all artifacts pass levels 1-3, all key links WIRED, no blocker anti-patterns
- **gaps_found** — any truth FAILED, artifact MISSING/STUB, key link NOT_WIRED, or blocker anti-pattern. The `Gaps` YAML is what the `planner` skill turns into gap-closure plans (`gap_closure: true`).
- **human_needed** — all automated checks pass, but items are flagged for human verification

## Success Criteria

- [ ] Previous section for the same scope checked (re-verification mode if it had gaps)
- [ ] Must-haves established (from frontmatter or derived)
- [ ] Every truth has a status and executed evidence
- [ ] Artifacts checked at 3 levels (exists, substantive, wired); key links verified
- [ ] Anti-patterns scanned and categorized; human items identified
- [ ] Gaps structured in YAML (if gaps_found)
- [ ] Section appended to `.hxsk/VERIFICATION.md` and `## Latest` updated — or, as the `verifier` agent, the section text returned to the caller
