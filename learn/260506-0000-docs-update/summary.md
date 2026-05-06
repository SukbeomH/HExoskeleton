# Learn Summary — docs update

## Summary

Updated public and internal documentation to match the current v5.7.0 repository state and repaired validation-tool edge cases caused by generated runtime/autoresearch outputs.

## Docs Updated

- `README.md` — current badge/version language and template count.
- `docs/codebase-summary.md` — version/date, file counts, script inventory, research count, and local verification script coverage.
- `docs/configuration-guide.md` — `llms.txt` and `.bootstrap-version` examples updated to v5.7.0.
- `docs/deployment-guide.md` — target version, v5.6→v5.7 migration row, and `local-verify.sh` guidance.
- `docs/project-overview-pdr.md` — v5.7.0, 10+ harness language, scripts/templates counts.
- `docs/project-roadmap.md` — v5.7.0 current line, timeline row, support matrix row.
- `docs/testing-guide.md` — removed brittle line-count claims and added `local-verify.sh` as the standard local bundle.
- `docs/system-architecture.md` — scripts/templates counts, Hermes adapter surface, and legacy-build clarification.
- `.hxsk/docs/HOOKS.md` — hook count aligned to 27.
- `.hxsk/docs/AGENTS.md` — agent count aligned to 18 and `spec-reviewer` listed.
- `.hxsk/docs/LINTING.md` — shell lint commands pointed at `.hxsk/scripts`.
- `.hxsk/docs/BUILD.md` — fixed setup prompt table formatting.
- `.hxsk/docs/WORKFLOWS.md` — overview clarified as Self-Configure, with old build generation marked superseded.
- `.hxsk/scripts/doc-lint.sh` — excluded `.hxsk/runtime/**` and allowed standard learn output filenames in DUP-01.

## Validation

- `bash .hxsk/scripts/doc-lint.sh` → PASS 7, FAIL 0.
- `bash .hxsk/hooks/check-consistency.sh` → PASS 34, FAIL 0.
- `bash .hxsk/scripts/local-verify.sh` → doc/consistency/skill dry-runs passed; pre-pr failed only because current branch is `master` with uncommitted changes.

## Remaining Notes

No documentation validation warnings remain. PR readiness requires a feature branch and commit before `pre-pr-check.sh` can pass.
