# Security Findings — HXSK Hooks & Scripts Audit

**Date**: 2026-04-23  
**Scope**: `.hxsk/hooks/`, `.hxsk/scripts/`, `.hxsk/prompts/setup.md`  
**Total Findings**: 15 (1 High, 4 Medium, 5 Low, 4 Info, 1 N/A)

---

## Critical / High

### [HIGH] bash-guard-missing-patterns
**ID**: #3 | **OWASP**: A01 | **STRIDE**: EoP | **Confidence**: Confirmed  
**Location**: `hooks/bash-guard.py:17-39`

`DESTRUCTIVE_GIT` blocklist does not include `rm -rf`, `shred`, `dd if=/dev/zero`, `truncate`, `chmod -R 777`, `git push --mirror`. An AI-generated command containing these patterns passes the guard unchallenged.

**Evidence**: Static analysis of `DESTRUCTIVE_GIT` list — none of the above patterns present. Current blocklist covers only git-specific operations.

**Remediation**:
```python
DESTRUCTIVE_FS = [
    r'\brm\s+-[^\s]*r',      # rm -rf, rm -r
    r'\bshred\b',
    r'\bdd\b.*if=/dev/zero',
    r'\btruncate\b.*--size\s+0',
    r'\bchmod\s+-[^\s]*R\s+[0-7]*7[0-7][0-7]',
    r'\bgit\s+push.*--mirror',
]
```

---

## Medium

### [MEDIUM] grep-option-injection
**ID**: #1 | **OWASP**: A03 | **STRIDE**: EoP | **Confidence**: Likely  
**Location**: `hooks/md-recall-memory.sh:31`

`QUERY` from AI is passed directly to `xargs grep -li "$QUERY"` without `--` separator. On GNU grep (Linux), a crafted query like `-r --include=*.sh /etc` searches outside the memories directory.

**Remediation**: Add `--` before the grep pattern:
```bash
xargs grep -li -- "$QUERY"
```

---

### [MEDIUM] file-protect-secrets-bypass
**ID**: #8 | **OWASP**: A01 | **STRIDE**: EoP | **Confidence**: Confirmed  
**Location**: `hooks/file-protect.py:13`

`BLOCKED_PATTERNS` contains `"secrets/"` (trailing slash) — `secrets.json`, `app-secrets.yaml`, `private.secrets` all bypass protection. `.git/` pattern also misses `.gitconfig`.

**Remediation**:
```python
BLOCKED_PATTERNS = [
    r"secrets[./]",      # covers secrets.json, secrets/, secrets.yaml
    r"\.gitconfig",      # explicit .gitconfig block
    r"credentials",
    ...
]
```

---

### [MEDIUM] setup-no-checksum-verify
**ID**: #11 | **OWASP**: A08 | **STRIDE**: Tampering | **Confidence**: Likely  
**Location**: `prompts/setup.md:300-310`

`curl -sL ... | tar xz` pipeline installs HXSK without mandatory SHA256 verification. The checksum block is commented out and labeled optional. A MITM or compromised GitHub release would go undetected.

**Remediation**: Make SHA256 verification mandatory in setup steps. Publish checksums in release notes and assert them pre-extraction.

---

### [MEDIUM] memory-injection-spoofing
**ID**: #15 | **OWASP**: A07 | **STRIDE**: Spoofing | **Confidence**: Possible  
**Location**: `.hxsk/memories/**/*.md`

Memory files are plain markdown with no HMAC or integrity signature. An attacker with write access to `.hxsk/memories/` can inject false context that `md-recall-memory.sh` returns to the AI as trusted memory — an indirect prompt injection vector.

**Remediation**: Short-term: document the trust boundary. Medium-term: consider HMAC signing on memory writes via `md-store-memory.sh` using a session key derived from a project secret.

---

## Low

### [LOW] prune-config-stat-fallback
**ID**: #2 | **OWASP**: A05 | **STRIDE**: EoP | **Confidence**: Possible  
**Location**: `scripts/prune-tick.sh:40-43`

`stat` failure falls back to `"600"` which satisfies the permission check, potentially sourcing `.prune-config` even when its real mode is unknown. Also TOCTOU window between stat and source (same-uid attacker required).

---

### [LOW] memory-git-exposure
**ID**: #5 | **OWASP**: A09 | **STRIDE**: Info-Disclosure | **Confidence**: Possible  
**Location**: `.hxsk/memories/` (shared tier)

Session summaries, architecture decisions, and pattern discoveries are committed to git. No age-based expiry — memories persist indefinitely once count < cap.

---

### [LOW] forge-detect-supply-chain
**ID**: #7 | **OWASP**: A08 | **STRIDE**: Tampering | **Confidence**: Possible  
**Location**: `scripts/forge-detect.sh:15-24`

`detect_forge()` trusts the `git remote get-url origin` string — a poisoned remote URL (e.g., `https://malicious-github.com/...`) could manipulate platform detection.

---

### [LOW] xargs-no-null-delimiter
**ID**: #9 | **OWASP**: A04 | **STRIDE**: DoS | **Confidence**: Confirmed  
**Location**: `hooks/md-recall-memory.sh:28-32`

`find | xargs` without `-0`/`-print0` silently drops memory files whose names contain spaces. Slug sanitization in `md-store-memory.sh` is the only mitigation — fragile by design.

---

### [LOW] claude-project-dir-hijack
**ID**: #10 | **OWASP**: A07 | **STRIDE**: Spoofing | **Confidence**: Possible  
**Location**: All hooks using `CLAUDE_PROJECT_DIR`

An attacker-controlled directory containing a malicious `.prune-config` could execute arbitrary code via `source`. In normal flow, `CLAUDE_PROJECT_DIR` is set by Claude Code (trusted), but the attack path exists.

---

### [LOW] yaml-safe-backslash
**ID**: #12 | **OWASP**: A03 | **STRIDE**: Tampering | **Confidence**: Possible  
**Location**: `hooks/md-store-memory.sh:9`

`yaml_safe()` escapes `"` and strips newlines but does NOT escape backslashes. Memory titles with `\n`, `\t`, `\\` produce YAML escape sequences that a future YAML parser would misinterpret.

---

## Info

### [INFO] bootstrap-auto-env
**ID**: #4 | **OWASP**: A04 | **Confidence**: Confirmed  
Low actual risk — `.env.example` contains no real secrets; `.env` is gitignored. Documented for completeness.

### [INFO] crypto-md5-fingerprint
**ID**: #6 | **OWASP**: A02 | **Confidence**: Confirmed  
MD5 used for session deduplication fingerprint only (non-security). SHA256 used correctly elsewhere.

### [INFO] a06-no-package-deps
**ID**: #13 | **OWASP**: A06 | **Confidence**: Confirmed  
Pure bash + Python stdlib. No CVE exposure from npm/pip/cargo package lockfiles.

### [INFO] a10-ssrf-not-applicable
**ID**: #14 | **OWASP**: A10 | **Confidence**: Confirmed  
No server component. `curl` in setup.md targets a hardcoded GitHub URL. A10 SSRF attack surface absent.
