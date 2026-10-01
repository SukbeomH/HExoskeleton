---
name: doc-lint
description: "Finds broken relative links in the project's markdown files with a bundled script, then checks document claims (paths, commands, counts) against the actual project. Use after modifying markdown, before a PR, or when links or structure look inconsistent (문서 정합성, 깨진 링크)."
---

## Quick Reference
- **구조 검사**: `python3 scripts/check-links.py` (이 스킬 디렉토리 기준 경로) — git 추적 `*.md` 의 상대 링크 대상 존재 여부
- **내용 검사**: 구조 PASS 후, 문서의 경로·명령·숫자 주장을 실제 프로젝트 상태와 대조
- **불일치 처리**: [MISMATCH] 발견 시 최소 수정 후 즉시 재검증
- **최종 확인**: 모든 수정 후 `check-links.py` 재실행으로 PASS 확인

## Workflow

### Step 1: Structural Check

프로젝트 루트를 작업 디렉토리로 실행한다 (인자로 파일을 주면 그 파일만 검사):

```bash
python3 scripts/check-links.py
```

출력은 `file:line: target` 한 줄씩, 마지막 줄이 `PASS`/`FAIL` 요약이다. URL(`http:`, `mailto:` …), 앵커 전용 링크(`#section`), `${VAR}` 템플릿, 코드 블록 안 링크는 검사하지 않는다. `file.md#section` 은 파일 존재만 본다.

PASS 면 Step 3 으로. FAIL 이면 Step 2.

### Step 2: Fix Broken Links

각 깨진 링크마다: 대상이 이동했으면 새 경로로 고치고, 삭제됐으면 링크(또는 그 문장)를 지운다. 추측으로 경로를 만들지 말고 실제 파일을 찾아 확인한다. 수정 후 Step 1 재실행.

### Step 3: Content Validation (Parallel Agents)

문서 규모가 크면 병렬 에이전트로 나눠 검사한다:

**Agent A**: 에이전트 지침 파일 (AGENTS.md, CLAUDE.md 등)
```
Read the agent instruction files. Compare every claim (commands, file paths,
workflow steps, boundaries) against the actual project. Report [MISMATCH] or [OK].
```

**Agent B**: README 및 아키텍처 문서
```
Read README.md and architecture docs (e.g. .hxsk/ARCHITECTURE.md). Verify feature
lists, component descriptions, directory diagrams and counts against the actual
project. Report [MISMATCH] or [OK].
```

### Step 4: Apply Content Fixes

Collect agent results. For each [MISMATCH]:
1. Read the source file
2. Propose minimal fix
3. Apply with Edit tool
4. Re-run Step 1 to confirm no regression

## Iron Laws
NO CONTENT VALIDATION WITHOUT STRUCTURAL PASS FIRST
NO COMPLETION WITHOUT RE-RUN LINK CHECK
NO EDIT WITHOUT MINIMAL FIX PROPOSAL
NO LINK FIX WITHOUT TARGET FILE EXISTENCE VERIFICATION
