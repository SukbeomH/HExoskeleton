# Security Audit Overview

**Target**: HXSK Framework — `.hxsk/hooks/`, `.hxsk/scripts/`, `.hxsk/prompts/setup.md`  
**Date**: 2026-04-23  
**Method**: autoresearch:security — 15 iterations, STRIDE + OWASP Top 10 (2021)  
**Phase context**: Post-Phase-7 (harness-independent reliability + 1-liner install improvements)  
**Auditor**: Claude Code (autoresearch:security skill)

---

## Risk Summary

| Severity | Count | IDs |
|----------|-------|-----|
| Critical | 0 | — |
| High | 1 | #3 |
| Medium | 4 | #1, #8, #11, #15 |
| Low | 5 | #2, #5, #7, #9, #10, #12 |
| Info | 4 | #4, #6, #13, #14 |
| **Total** | **15** | |

---

## Key Findings Summary

**Highest risk (#3 — High/Confirmed)**  
`bash-guard.py` blocks git-level destructive commands but misses OS-level file deletion (`rm -rf`, `shred`, `dd if=/dev/zero`). An AI-generated command containing these bypasses the guard entirely.

**Structural gap (#8 + #1 — Medium/Confirmed)**  
`file-protect.py` secret patterns require trailing slash — `secrets.json` slips through. `md-recall-memory.sh` passes unsanitized QUERY to `grep` without `--` separator on GNU grep.

**Supply chain risk (#11 — Medium/Likely)**  
1-liner install via `curl | tar` has SHA256 verification commented out and labeled optional. A compromised GitHub release would install undetected.

**Memory trust boundary (#15 — Medium/Possible)**  
Memory files have no integrity protection. Write access to `.hxsk/memories/` enables indirect prompt injection via crafted recalled context.

---

## Architecture Assessment

The pure bash + Python stdlib design is a significant security advantage:
- Zero third-party package CVE exposure (A06 clean)
- No serialization/deserialization of complex objects
- No network server — A10 SSRF not applicable

The main attack surface is the **AI → Hook trust boundary**: AI-generated strings are passed as CLI arguments and through stdin. Most hooks lack input sanitization for the attacker-controlled-by-AI scenario.

The `.prune-config source` pathway is the highest-risk code execution vector, protected only by a stat-based permission check (with known fallback quirk).

---

## OWASP Coverage

9 of 10 OWASP 2021 categories checked. A10 (SSRF) not applicable — pure CLI tool.  
See `owasp-coverage.md` for per-category mapping.

---

## Files in This Audit

| File | Contents |
|------|----------|
| `security-audit-results.tsv` | Machine-readable findings log (15 rows + baseline) |
| `threat-model.md` | STRIDE threat matrix + trust boundaries |
| `attack-surface-map.md` | Entry points, data flows, abuse paths |
| `findings.md` | Detailed per-finding writeups |
| `owasp-coverage.md` | OWASP Top 10 coverage matrix |
| `dependency-audit.md` | Binary + package dependency inventory |
| `recommendations.md` | Prioritized remediation plan (R1–R7) |
| `overview.md` | This file |

---

## Next Steps

1. **P0 (immediate)**: Implement R1 — add `rm -rf`/`shred`/`dd` patterns to `bash-guard.py`
2. **P1 (next patch)**: R2 (grep `--`), R3 (secrets patterns), R4 (mandatory SHA256)
3. **P2 (planned)**: R5 (xargs `-0`), R6 (yaml_safe backslash), R7 (memory trust doc)
