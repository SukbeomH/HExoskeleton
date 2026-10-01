---
description: Use when modifying markdown files, preparing PRs, or suspecting link/structure
  inconsistencies in documentation.
name: doc-lint
trigger: 문서 정합성 검사, 깨진 링크, INDEX 동기화, 카운트 불일치, 고아 파일, pre-commit, 문서 구조 검사, 중복 파일,
  경로 참조 검증, 내용 검증, 의미론적 검사, doc-lint, doc lint, markdown check, broken link, orphan
  file, duplicate file, link check, index sync, count mismatch, ref check, structural
  check, content validation, 문서 검사, markdown 정합성
---

## Quick Reference
- **실패 시 우선순위**: REF-01 → COUNT-01 → LINK-01 순서로 수정
- **병행 검증**: Agent A(CLAUDE/AGENTS), B(README/ARCH), C(INDEX) 동시 실행
- **불일치 처리**: [MISMATCH] 발견 시 최소 수정 후 즉시 재검증
- **수정 원칙**: 본문 내용과 실제 프로젝트 상태 일치 여부만 검증
- **최종 확인**: 모든 수정 완료 후 `doc-lint.sh` 재실행으로 PASS 확인

## Workflow

### Step 1: Structural Check

```bash
bash .hxsk/scripts/doc-lint.sh
```

If all PASS, skip to Step 3. If any FAIL, proceed to Step 2.

### Step 2: Fix Structural Issues

Fix FAIL items in priority order:
1. **REF-01** (L1 path references) — highest impact, affects onboarding
2. **COUNT-01** (README counts) — user-facing, most visible
3. **LINK-01** (broken links) — navigation broken
4. **INDEX-01** (INDEX sync) — discoverability
5. **ORPHAN-01** (unreferenced files) — cleanup
6. **DUP-01** (duplicate names) — ambiguity

Re-run `doc-lint.sh` after fixes to confirm PASS.

### Step 3: Content Validation (Parallel Agents)

Dispatch 3 parallel agents for semantic checks:

**Agent A**: CLAUDE.md + AGENTS.md
```
Read CLAUDE.md and AGENTS.md. Compare every claim (hook events,
workflow descriptions, file paths, agent boundaries) against
actual project state. Report as [MISMATCH] or [OK].
```

**Agent B**: README.md + ARCHITECTURE.md
```
Read README.md and .hxsk/ARCHITECTURE.md. Verify feature lists,
component descriptions, directory structure diagrams against
actual state. Report as [MISMATCH] or [OK].
```

**Agent C**: INDEX files (skills, agents, research)
```
Read each INDEX.md. Verify listed items match actual files,
descriptions are accurate, and no items are missing.
Report as [MISMATCH] or [OK].
```

### Step 4: Apply Content Fixes

Collect agent results. For each [MISMATCH]:
1. Read the source file
2. Propose minimal fix
3. Apply with Edit tool
4. Re-run structural check to confirm no regression

---

## Rules Reference

| Rule | What it checks | Scope |
|------|---------------|-------|
| LINK-01 | Relative link targets exist | All .md |
| INDEX-01 | INDEX.md lists vs actual files | skills/, agents/, research/ |
| COUNT-01 | README count numbers vs actual | README.md |
| REF-01 | Backtick path references in L1 docs | CLAUDE.md, AGENTS.md |
| ORPHAN-01 | Files not referenced anywhere | All .md (excl. memories, templates) |
| DUP-01 | Same filename in multiple locations | All .md (excl. symlinks) |

## Iron Laws
NO CONTENT VALIDATION WITHOUT STRUCTURAL PASS FIRST
NO FIX APPLICATION WITHOUT PRIORITY ORDER ADHERENCE
NO COMPLETION WITHOUT RE-RUN LINT CHECK
NO EDIT WITHOUT MINIMAL FIX PROPOSAL
NO INDEX UPDATE WITHOUT FILE EXISTENCE VERIFICATION
