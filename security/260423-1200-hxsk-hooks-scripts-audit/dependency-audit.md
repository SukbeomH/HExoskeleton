# Dependency Audit

**Audit**: HXSK Hooks & Scripts — 2026-04-23

## Package Manager Dependencies

| Ecosystem | Lock File | Dependencies | CVE Risk |
|-----------|-----------|--------------|----------|
| npm | None | 0 | None |
| pip | None | 0 | None |
| cargo | None | 0 | None |
| go.mod | None | 0 | None |

**Verdict**: Zero third-party package dependencies. No CVE exposure from package lockfiles.

## External Binary Dependencies

| Binary | Purpose | Trust Level | Notes |
|--------|---------|-------------|-------|
| `bash` | Script execution | System | Trusted OS component |
| `python3` | Hook execution | System | stdlib only (sys, json, re, os, subprocess) |
| `git` | VCS operations | System | Trusted, but remote URLs affect forge-detect |
| `gh` | GitHub CLI | User-installed | Trusted if from official channels |
| `glab` | GitLab CLI | User-installed | Trusted if from official channels |
| `tea` | Gitea CLI | User-installed | Less common, verify source |
| `qlty` | Code quality (optional) | User-installed | Optional, not in critical path |
| `stat` | File metadata | System | macOS BSD vs. GNU stat divergence (finding #2) |
| `find` | File search | System | GNU vs. BSD behavior difference |
| `xargs` | Arg passing | System | No -0 flag issue (finding #9) |
| `grep` | Pattern search | System | GNU vs. BSD option injection difference (finding #1) |
| `md5` / `md5sum` | Dedup fingerprint | System | MD5 collision risk (finding #6, non-security use) |

## Python Standard Library Usage

```
hooks/bash-guard.py:     sys, json, re, subprocess
hooks/file-protect.py:   sys, json, re, os
hooks/read-before-edit.py: sys, json, os
hooks/write-guard.py:    sys, json, os
```

All hooks use only Python stdlib — no third-party imports.

## Supply Chain Risk Surface

- **setup.md install pipeline**: `curl -sL https://github.com/SukbeomH/HExoskeleton/archive/...` — GitHub release tarball, no checksum (finding #11)
- **forge CLI binaries**: `gh`, `glab`, `tea` assumed to be in `PATH` and trusted (finding #7)
