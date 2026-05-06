# Validation Report — docs update

Mode: update  
Scope: entire repository  
Depth: standard  
Date: 2026-05-06

## Commands

| Command | Result | Evidence |
|---------|--------|----------|
| `bash .hxsk/scripts/doc-lint.sh` | PASS | PASS 7, FAIL 0; 287 markdown files checked |
| `bash .hxsk/hooks/check-consistency.sh` | PASS | PASS 34, FAIL 0, WARN 0 |
| `bash .hxsk/scripts/local-verify.sh` | CONDITIONAL | doc-lint, consistency, and skill dry-runs passed; pre-pr failed because worktree is on `master` with uncommitted changes |

## Fix Loop

One validation-tool fix was applied with approval: `.hxsk/scripts/doc-lint.sh` now excludes generated `.hxsk/runtime/**` markdown snapshots from the document corpus. This prevents DUP-01 from treating session snapshot copies of `CURRENT.md` and `SESSION_HANDOFF.md` as hand-authored documentation collisions.

The existing autoresearch duplicate-name allowlist was also extended for standard learn output files: `scout-context.md` and `validation-report.md`.

## Verdict

Documentation validation is clean. PR-readiness validation is intentionally not clean until the changes are moved to a feature branch and committed.
