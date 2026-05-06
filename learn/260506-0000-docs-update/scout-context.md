# Scout Context — docs update

## Parsed Request

`/autoresearch_learn --mode update` was invoked with no scope or depth. Interactive setup selected:

- Mode: Update
- Scope: Everything
- Depth: Standard
- Launch: Yes

## Repository Scan

- Project type: bash + markdown methodology repository, no package manager manifest detected.
- Existing public docs: 9 root files under `docs/` plus `docs/plans/` research/plan documents.
- Canonical version metadata: `.hxsk/.bootstrap-version` and `llms.txt` both report HXSK v5.7.0, last updated 2026-05-04.
- Component counts from local scan: 24 skills, 18 agents, 27 hooks, 23 scripts, 34 templates, 43 research markdown files.
- Primary verification entrypoint: `.hxsk/scripts/local-verify.sh`, with direct validators `doc-lint.sh` and `check-consistency.sh`.

## Main Staleness Findings

- Public docs mostly described v5.6.1 / 2026-04-30 while canonical metadata is v5.7.0 / 2026-05-04.
- Script/template/research counts had drifted: scripts 22 → 23, templates 33 → 34, research markdown 42 → 43.
- Several docs still emphasized legacy build outputs; Self-Configure is the current deployment path.
- `local-verify.sh`, `active-state.sh`, Hermes, and HITL surfaces were underrepresented in public docs.
- Internal docs had small drift: `.hxsk/docs/HOOKS.md` hook count, `.hxsk/docs/AGENTS.md` agent count/spec-reviewer omission, `.hxsk/docs/LINTING.md` top-level `scripts/` commands, `.hxsk/docs/BUILD.md` table formatting, and `.hxsk/docs/WORKFLOWS.md` legacy build overview.

## External Pattern Notes

External documentation patterns reinforced keeping README as the front door, separating configuration/testing/architecture references, documenting verification as a contract, and avoiding raw generated changelog noise in user-facing docs.
