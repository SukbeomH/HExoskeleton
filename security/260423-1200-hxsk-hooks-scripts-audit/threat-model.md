# HXSK Threat Model — STRIDE Analysis

**Target:** .hxsk/hooks/, .hxsk/scripts/, .hxsk/skills/, .hxsk/prompts/setup.md  
**Date:** 2026-04-23  
**Framework:** STRIDE

---

## Assets

| Asset | Type | Sensitivity | Location |
|-------|------|-------------|----------|
| Memory files | Context store | High (AI decisions, project state) | `.hxsk/memories/**/*.md` |
| .prune-config | Shell config | **Critical** (sourced as shell) | `.hxsk/.prune-config` |
| .bootstrap-version | Version state | Low | `.hxsk/.bootstrap-version` |
| CURRENT.md | Session context | Medium (commit messages, branch) | `.hxsk/CURRENT.md` |
| .env | Credentials | Critical | `.env` |
| Log files | Execution trace | Medium | `.hxsk/*.log` |
| settings.json | Hook config | High | `.claude/settings.json` |
| Hook scripts (.sh/.py) | Executables | High | `.hxsk/hooks/` |
| .hxsk/scripts/ | Executables | High | `.hxsk/scripts/` |
| CLAUDE_PROJECT_DIR env | Path anchor | High | OS environment |

---

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────┐
│ Claude Code AI (LLM)                                     │
│   ↓ stdin JSON / CLI args (AI-generated content)         │
├─────────────────────────────────────────────────────────┤
│ Hook Scripts / Memory Scripts (bash + Python)            │
│   ↓ file read/write, process spawning                    │
├─────────────────────────────────────────────────────────┤
│ File System (.hxsk/, project root)                       │
│   ↑ sourced config (.prune-config)                       │
├─────────────────────────────────────────────────────────┤
│ OS Shell (bash)                                          │
└─────────────────────────────────────────────────────────┘

Trust Boundary 1: AI → Hook (stdin/args) — UNVALIDATED
Trust Boundary 2: Hook → FS (paths) — PARTIALLY VALIDATED  
Trust Boundary 3: FS → Shell (source .prune-config) — PRIVILEGED
Trust Boundary 4: Hook → External (git, find, grep) — LOW TRUST INPUT
```

---

## STRIDE Threat Matrix

| Threat | Asset | Severity | Description |
|--------|-------|----------|-------------|
| **S**poofing | .prune-config | High | Attacker writes malicious .prune-config; prune-tick.sh sources it with mode check bypass |
| **T**ampering | memory files | Medium | AI-generated QUERY with grep metacharacters corrupts search results |
| **T**ampering | .bootstrap-version | Low | File corruption causes always-FRESH state, re-runs install |
| **R**epudiation | .context-save.log | Medium | Log rotation overwrites evidence; no append-only enforcement |
| **I**nformation Disclosure | memory files | High | AI memories store commit messages, file paths, potentially sensitive data with no expiry |
| **I**nformation Disclosure | .env auto-copy | Medium | bootstrap.sh silently copies .env.example → .env, may expose template secrets |
| **D**enial of Service | prune-tick lock | Low | Stale lock (already mitigated with 300s timeout, but window exists) |
| **E**oP | grep injection | Medium | md-recall-memory.sh passes unsanitized QUERY to grep; -r flag could read outside memories dir |
| **E**oP | path traversal (find) | Medium | related_ref from YAML memory file used in find -name "*${ref}*" without sanitization |
| **E**oP | bash-guard bypass | Medium | rm -rf, shred, dd, chmod -R 777 not in blocklist |
| **E**oP | file-protect bypass | Low | ".." check does not resolve symlinks; symlink chain could bypass |
