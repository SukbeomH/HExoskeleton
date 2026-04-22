# OWASP Top 10 (2021) Coverage

**Audit**: HXSK Hooks & Scripts — 2026-04-23

| OWASP | Name | Status | Findings |
|-------|------|--------|----------|
| A01 | Broken Access Control | **FINDINGS** | #3 bash-guard-missing-patterns (High), #8 file-protect-secrets-bypass (Medium) |
| A02 | Cryptographic Failures | Info | #6 MD5 fingerprint (dedup only, non-security) |
| A03 | Injection | **FINDINGS** | #1 grep-option-injection (Medium), #12 yaml-safe-backslash (Low) |
| A04 | Insecure Design | Info/Low | #4 bootstrap-auto-env (Info), #9 xargs-no-null-delimiter (Low) |
| A05 | Security Misconfiguration | **FINDINGS** | #2 prune-config-stat-fallback (Low) |
| A06 | Vulnerable/Outdated Components | Clean | #13 no-package-deps — zero CVE exposure |
| A07 | ID & Auth Failures | **FINDINGS** | #10 claude-project-dir-hijack (Low), #15 memory-injection-spoofing (Medium) |
| A08 | Software Integrity Failures | **FINDINGS** | #7 forge-detect-supply-chain (Low), #11 setup-no-checksum-verify (Medium) |
| A09 | Logging & Monitoring Failures | **FINDINGS** | #5 memory-git-exposure (Low) |
| A10 | SSRF | N/A | #14 — no server component; A10 not applicable |

**Summary**: 9/10 OWASP categories checked. A10 not applicable (CLI tool, no server).
