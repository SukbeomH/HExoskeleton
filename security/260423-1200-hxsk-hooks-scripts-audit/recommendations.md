# Remediation Recommendations

**Priority order**: Critical/High → Medium → Low

---

## P0 — Fix Before Next Release

### R1: Add destructive filesystem patterns to bash-guard.py
**Finding**: #3 (High)  
**Effort**: 30 min

Add to `hooks/bash-guard.py` `DESTRUCTIVE_GIT` list:
```python
DESTRUCTIVE_FS = [
    r'\brm\s+(-[^\s]*r|-r[^\s]*)',  # rm -rf, rm -r, rm -Rf
    r'\bshred\b',
    r'\bdd\b.*\bif=/dev/zero\b',
    r'\btruncate\b.*\s0\b',
    r'\bchmod\b.*-[^\s]*R.*[0-7]*7[0-7]{2}',
    r'\bgit\s+push\b.*--mirror\b',
]
```
Combine with existing list and check against full command string.

---

## P1 — Fix in Next Patch

### R2: Add `--` separator to grep in md-recall-memory.sh
**Finding**: #1 (Medium)  
**Effort**: 5 min

```bash
# hooks/md-recall-memory.sh:31
# Before:
xargs grep -li "$QUERY"
# After:
xargs grep -li -- "$QUERY"
```

### R3: Fix file-protect.py secret patterns
**Finding**: #8 (Medium)  
**Effort**: 15 min

Replace `"secrets/"` with a regex covering file-based variants:
```python
r"secrets[/.]",       # secrets/ secrets.json secrets.yaml
r"\.gitconfig$",      # .gitconfig
r"credentials\.",     # credentials.json credentials.yaml
```

### R4: Make setup.md SHA256 verification mandatory
**Finding**: #11 (Medium)  
**Effort**: 30 min  

1. Publish SHA256 checksums in GitHub release notes for each `setup-vX.Y.Z` tag
2. Remove "선택" label from checksum block in setup.md
3. Change comment to an assert:
```bash
EXPECTED="<hash from release notes>"
ACTUAL=$(shasum -a 256 "setup-v${TARGET_VERSION}.tar.gz" | awk '{print $1}')
[[ "$EXPECTED" == "$ACTUAL" ]] || { echo "SHA256 mismatch — aborting"; exit 1; }
```

---

## P2 — Planned Improvements

### R5: Add `-print0`/`-0` to find|xargs pipeline
**Finding**: #9 (Low)  
**Effort**: 5 min

```bash
# hooks/md-recall-memory.sh:28-32
find "$MEMORIES_DIR" -name "*.md" -print0 | xargs -0 grep -li -- "$QUERY"
```

### R6: Add backslash escaping to yaml_safe()
**Finding**: #12 (Low)  
**Effort**: 10 min

```bash
yaml_safe() {
    printf '%s' "${1:-}" | tr -d '\n\r' | sed 's/\\/\\\\/g; s/"/\\"/g'
}
```

### R7: Document memory trust boundary
**Finding**: #15 (Medium)  
**Effort**: 15 min

Add to `hooks/md-recall-memory.sh` header comment:
```
# TRUST BOUNDARY: recalled content is user-filesystem-level trusted.
# Do not treat recalled memories as cryptographically authenticated.
```
Long-term: consider HMAC signing with a project-local key on memory writes.

---

## P3 — Low / Accept as-is

| Finding | Recommendation | Rationale |
|---------|---------------|-----------|
| #2 prune-config-stat-fallback | Add explicit error exit on stat failure | Same-uid attack only; low exploitability |
| #5 memory-git-exposure | Add age-based prune tier to prune-memories.sh | Count-only prune leaves old context indefinitely |
| #7 forge-detect-supply-chain | No action needed | Remote URL is user-configured, not AI-generated |
| #10 claude-project-dir-hijack | No action needed | Env var is set by trusted Claude Code runtime |
| #4, #6, #13, #14 | Accept (Info) | Not actionable or N/A |
