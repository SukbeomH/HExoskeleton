# Debug Memory Protocol

## Prerequisites

- `.hxsk/memories/` directory structure must exist

## Purpose

Search past investigations before starting. Persist findings for future sessions so repeated bugs are resolved faster.

## Pre-Execution Search Pattern

### Phase 0: Recall Before Investigating

Before beginning any investigation, search past debugging context first, then narrow with tags:

```
Grep(pattern: "{symptom description}", path: ".hxsk/memories/", output_mode: "files_with_matches")
```

Semantic 결과가 부족하면 태그 기반으로 보충:

```
Glob(pattern: ".hxsk/memories/{root-cause,debug-eliminated}/*.md")
```

If matches found, review past root causes and eliminated hypotheses to avoid repeating dead ends.

---

## Memory Templates

### 1. Hypothesis Elimination

When a hypothesis is disproved, persist it to prevent future sessions from re-investigating:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Eliminated: {hypothesis}" \
  "{evidence that disproved this hypothesis}" \
  "debug,eliminated,{component}" \
  "debug-eliminated"
```

### 2. Investigation Step

Track progress during active investigation:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Investigation: {what was examined}" \
  "{what was found, what it implies}" \
  "debug,investigation,{component}" \
  "debug-investigation"
```

### 3. Root Cause Found

When the root cause is identified, persist the full finding:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Root Cause: {cause}" \
  "{evidence, fix applied, verification result}" \
  "debug,root-cause,{component}" \
  "root-cause"
```

If related to a past bug, use tag encoding to link them (`related:{slug}`).

### 4. Dead End

When an entire approach is exhausted with no result:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Dead End: {approach that failed}" \
  "{what was tried, why it failed, what was learned}" \
  "debug,dead-end,{component}" \
  "debug-eliminated"
```

### 5. 3-Strike / Blocked State

When the 3-strike rule activates, persist the blocked state for the next session:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Blocked: {issue}" \
  "{approaches tried, errors seen, remaining hypotheses}" \
  "debug,blocked,3-strike" \
  "debug-blocked"
```

---

## DEBUG.md Structure

```markdown
---
status: gathering | investigating | fixing | verifying | resolved
trigger: "{verbatim user input}"
created: [timestamp]
updated: [timestamp]
---

## Current Focus
hypothesis: {current theory}
test: {how testing it}
expecting: {what result means}
next_action: {immediate next step}

## Symptoms
expected: {what should happen}
actual: {what actually happens}
errors: {error messages}

## Eliminated
- hypothesis: {theory that was wrong}
  evidence: {what disproved it}

## Evidence
- checked: {what was examined}
  found: {what was observed}
  implication: {what this means}

## Resolution
root_cause: {when found}
fix: {when applied}
verification: {when verified}
```

---

## Output Formats

### ROOT CAUSE FOUND
```
ROOT CAUSE: {specific cause}
EVIDENCE: {proof}
FIX: {recommended fix}
```

### INVESTIGATION INCONCLUSIVE
```
ELIMINATED: {hypotheses ruled out}
REMAINING: {hypotheses to investigate}
BLOCKED BY: {what's needed}
RECOMMENDATION: {next steps}
```

### CHECKPOINT REACHED
```
STATUS: {gathering | investigating}
PROGRESS: {what's been done}
QUESTION: {what's needed from user}
```

---

## Verification Checklist

- [ ] Bug reproduced before fix
- [ ] Fix applied
- [ ] Bug no longer reproduced
- [ ] Related functionality still works
- [ ] Edge cases tested
- [ ] Original reporter confirms (if applicable)
