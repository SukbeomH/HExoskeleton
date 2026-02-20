---
name: bootstrap
description: Complete initial project setup -- system verification, memory initialization, codebase analysis
version: 4.0.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
trigger: "First time running the boilerplate on a new project, or after cloning"
---

## Quick Reference
- **시작**: `bash scripts/bootstrap.sh` (필수 도구 검증: git, bash)
- **메모리**: `.gsd/memories/` 14개 타입 디렉토리 + `_schema/` 확인
- **Output**: BOOTSTRAP STATUS REPORT (READY / NEEDS ATTENTION)
- **메모리 저장**: `md-store-memory.sh` 로 `.gsd/memories/bootstrap/`에 기록

---

# Skill: Bootstrap

> **Goal**: Perform complete initial project setup — system verification, memory directory initialization, and codebase analysis.
> **Scope**: 순수 bash 스크립트 기반. 외부 종속성 없음.

<role>
You are a bootstrap orchestrator. Your job is to take a freshly cloned boilerplate and make it fully operational.

**Core responsibilities:**
- Verify system prerequisites (git, bash)
- Initialize memory directory structure
- Generate architecture documentation
- Store bootstrap state in `.gsd/memories/`
- Report final status with actionable next steps
</role>

---

## Procedure

### Step 1: System Prerequisites Check

Run the system dependency verification script:

```bash
bash scripts/bootstrap.sh
```

**If exit code 1:** STOP. Display the failing checks and provide installation instructions.

**If exit code 0:** Record tool versions and continue.

---

### Step 2: Environment Setup

Copy `.env.example` to `.env` if `.env` does not already exist:

```bash
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
else
    echo ".env already exists"
fi
```

---

### Step 3: Memory Directory Verification

Verify `.gsd/memories/` 디렉토리 구조:

```bash
ls .gsd/memories/ | wc -l  # 14 directories + _schema expected
```

**If missing:** Create directories:
```bash
mkdir -p .gsd/memories/{architecture-decision,root-cause,debug-eliminated,debug-blocked,health-event,session-handoff,execution-summary,deviation,pattern-discovery,bootstrap,session-summary,session-snapshot,security-finding,general,_schema}
```

Verify schema files:
```bash
ls .gsd/memories/_schema/
# Expected: base.schema.json, type-relations.yaml, session-summary.schema.json, etc.
```

---

### Step 4: Context Structure Initialization

Verify context management structure:

```
.gsd/
├── reports/           # Analysis reports (REPORT-*.md)
├── research/          # Research documents (RESEARCH-*.md)
├── archive/           # Monthly archives
├── PATTERNS.md        # Core patterns (2KB limit)
└── context-config.yaml # Cleanup rules
```

**Verification:**
```bash
test -d .gsd/reports && test -d .gsd/research && test -d .gsd/archive && echo "PASS" || echo "FAIL"
test -f .gsd/PATTERNS.md && echo "PASS" || echo "FAIL"
```

---

### Step 5: Codebase Analysis

Delegate to the `codebase-mapper` skill to analyze the project:

- `.gsd/ARCHITECTURE.md`
- `.gsd/STACK.md`

**If codebase-mapper fails:** Mark FAIL. Continue to Step 6.

---

### Step 6: Initial Memory

Store the bootstrap record:

```bash
bash scripts/md-store-memory.sh \
  "Project Bootstrap" \
  "Bootstrap completed. System prerequisites verified. Memory initialized." \
  "bootstrap,init,setup" \
  "bootstrap" \
  "bootstrap,init,setup,project" \
  "Initial project bootstrap completed successfully"
```

**If memory store fails:** Mark WARN. Continue to Step 7.

---

### Step 7: Status Report

Output the structured bootstrap status report:

```
================================================================
 BOOTSTRAP STATUS REPORT
================================================================
System Prerequisites:  {PASS|FAIL} (git, bash)
Environment:           {PASS|FAIL} (.env configured)
Memory Directory:      {PASS|FAIL} (.gsd/memories/ — 14 types + _schema)
Memory Schema:         {PASS|FAIL} (base.schema.json, type-relations.yaml)
Context Structure:     {PASS|FAIL} (reports/, research/, archive/)
Documentation:         {PASS|FAIL} (ARCHITECTURE.md, STACK.md)
Memory Record:         {PASS|WARN} (bootstrap record stored)
================================================================
 RESULT: READY / NEEDS ATTENTION
================================================================
Next: /plan | Start working on your project
================================================================
```

**READY** = All steps PASS (WARN is acceptable).
**NEEDS ATTENTION** = Any step FAIL.

---

## Error Handling

| Error | Action |
|-------|--------|
| System prerequisite missing | STOP at Step 1. Print install commands |
| Memory directory missing | Create directories automatically |
| Schema files missing | Copy from templates or create minimal versions |
| codebase-mapper fails | FAIL the step, continue |
| Memory store fails | WARN the step, continue |

---

## Scripts

- `scripts/bootstrap.sh`: System dependency verification script (git, bash, memory structure)
- `scripts/detect-language.sh`: Language, package manager detection functions (optional)
