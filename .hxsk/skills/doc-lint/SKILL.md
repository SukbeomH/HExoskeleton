---
name: doc-lint
description: "Use when committing docs, before PRs, or when document counts/links may be stale"
trigger: "문서 정합성 검사, 깨진 링크, INDEX 동기화, 카운트 불일치, 고아 파일, pre-commit"
---

## Quick Reference
- **Script**: `bash .hxsk/scripts/doc-lint.sh` (구조적 검사)
- **Single rule**: `bash .hxsk/scripts/doc-lint.sh --rule LINK-01`
- **Rules**: LINK-01, INDEX-01, COUNT-01, REF-01, ORPHAN-01, DUP-01
- **Output**: `[PASS|FAIL] RULE-ID: message`

---

# Document Consistency Check

<role>
You verify that all markdown documents in the project are structurally and semantically consistent.
Run structural checks via script, then perform content-level validation with parallel agents.
</role>

---

## Workflow

### Step 1: Structural Check

```bash
bash .hxsk/scripts/doc-lint.sh
```

If all PASS, skip to Step 3. If any FAIL, proceed to Step 2.

### Step 2: Fix Structural Issues

Fix FAIL items in priority order:
1. **REF-01** (L1 path references) — highest impact, affects onboarding
2. **COUNT-01** (README counts) — user-facing, most visible
3. **LINK-01** (broken links) — navigation broken
4. **INDEX-01** (INDEX sync) — discoverability
5. **ORPHAN-01** (unreferenced files) — cleanup
6. **DUP-01** (duplicate names) — ambiguity

Re-run `doc-lint.sh` after fixes to confirm PASS.

### Step 3: Content Validation (Parallel Agents)

Dispatch 3 parallel agents for semantic checks:

**Agent A**: CLAUDE.md + AGENTS.md
```
Read CLAUDE.md and AGENTS.md. Compare every claim (hook events,
workflow descriptions, file paths, agent boundaries) against
actual project state. Report as [MISMATCH] or [OK].
```

**Agent B**: README.md + ARCHITECTURE.md
```
Read README.md and .hxsk/ARCHITECTURE.md. Verify feature lists,
component descriptions, directory structure diagrams against
actual state. Report as [MISMATCH] or [OK].
```

**Agent C**: INDEX files (skills, agents, research)
```
Read each INDEX.md. Verify listed items match actual files,
descriptions are accurate, and no items are missing.
Report as [MISMATCH] or [OK].
```

### Step 4: Apply Content Fixes

Collect agent results. For each [MISMATCH]:
1. Read the source file
2. Propose minimal fix
3. Apply with Edit tool
4. Re-run structural check to confirm no regression

---

## Rules Reference

| Rule | What it checks | Scope |
|------|---------------|-------|
| LINK-01 | Relative link targets exist | All .md |
| INDEX-01 | INDEX.md lists vs actual files | skills/, agents/, research/ |
| COUNT-01 | README count numbers vs actual | README.md |
| REF-01 | Backtick path references in L1 docs | CLAUDE.md, AGENTS.md |
| ORPHAN-01 | Files not referenced anywhere | All .md (excl. memories, templates) |
| DUP-01 | Same filename in multiple locations | All .md (excl. symlinks) |
