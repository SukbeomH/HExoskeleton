# Scout Context — docs update

Mode: update  
Scope: everything  
Depth: standard  
Date: 2026-04-30

## Inventory

| Area | Count |
|------|-------|
| Public docs | 8 |
| Skills | 24 |
| Agents | 18 |
| Hooks | 27 total: 22 shell + 5 Python |
| Scripts | 22 |
| Templates | 33 |
| Root internal docs | 15 |
| Research markdown | 42 |
| Tracked files | 467 |

## Existing Public Docs

- `docs/project-overview-pdr.md`
- `docs/codebase-summary.md`
- `docs/code-standards.md`
- `docs/system-architecture.md`
- `docs/deployment-guide.md`
- `docs/testing-guide.md`
- `docs/configuration-guide.md`
- `docs/project-roadmap.md`

## Staleness Findings

- Public docs still contained `v5.5.x` / `Version 5.5.x` references while `.hxsk/.bootstrap-version` and `llms.txt` are v5.6.1.
- Several diagrams and overview snippets still listed 22 skills, 21 hooks, 12 scripts, or 16 memory types.
- README exceeded the learn workflow size target of 300 lines before fix.

## Recent Change Hints

- Recent commits include release lineage refresh, verification hardening, Codex harness support, Phase 11 ADR/term/memory work, and Phase 10 CSO optimization.
- Changed areas map primarily to public docs, `.hxsk/` metadata, hooks, scripts, adapters, and memories.
