# Commit Protocol — Full Detail

## Task Commit Protocol

After each task completes:

```bash
git add -A
git commit -m "feat({phase}-{plan}): {task description}"
```

**Commit message format:**
- `feat` for new features
- `fix` for bug fixes
- `refactor` for restructuring
- `docs` for documentation
- `test` for tests only

**Track commit hash** for Summary reporting.

---

## Phase Checkpoint Commit

Phase 단위로 checkpoint commit을 생성하여 partial achievement를 방지합니다.

### When to Checkpoint

- **Phase 완료 시**: 해당 phase의 모든 task 커밋 후 phase checkpoint 생성
- **Mid-execution 중단 시**: 세션 종료가 필요한 경우 현재 task까지 완료 후 checkpoint

### Checkpoint Procedure

1. **테스트 실행**: `detect-language.sh`의 `detect_test_runner()` + `get_test_cmd()` 활용
2. **Phase commit**: `git commit -m "checkpoint({phase}): complete phase N — M/T tasks done"`
3. **Push**: `git push` — recovery point를 remote에 보존
4. **STATE.md 업데이트**: 현재 phase 진행 상태 기록

```bash
source .hxsk/scripts/detect-language.sh
RUNNER=$(detect_test_runner)
PKG=$(detect_pkg_manager)
TEST_CMD=$(get_test_cmd "$RUNNER" "$PKG")
# 테스트 실행 후 결과에 따라 commit message에 test status 포함
```

### Mid-Execution Handoff

세션 중단이 불가피한 경우:

1. 현재 task를 안전한 지점까지 완료
2. 위 Checkpoint Procedure 실행
3. `handoff` 스킬 호출 — 세션 인수인계 메모리 저장 + 요약 출력
4. 다음 세션에서 PLAN.md + handoff 메모리로 정확한 재개 지점 확인 가능

> **목적**: Phase checkpoint가 있으면 다음 세션에서 처음부터 다시 시작할 필요 없이 중단 지점부터 재개 가능.

---

## PRD Update Protocol

작업 완료 후 PRD 상태를 업데이트하여 진행 상황을 추적합니다.

### When to Update PRD

1. **Task 커밋 직후** — 각 task가 커밋되면 즉시 PRD 업데이트
2. **Plan 완료 시** — SUMMARY.md 작성 후 해당 plan의 모든 task 완료 확인

### PRD 상태 관리

PRD 파일은 직접 편집하거나 메모리 시스템을 통해 기록:

```bash
# 실행 결과 메모리에 저장
bash .hxsk/hooks/md-store-memory.sh \
  "Execution: Plan 1.2" \
  "Task 완료. Commit: abc1234" \
  "execution,summary,phase-1" \
  "execution-summary"
```

### Integration with Task Commit

Task 완료 시 통합 프로세스:

```bash
# 1. Task 커밋
git add -A
git commit -m "feat(1-2): implement user authentication"

# 2. 커밋 해시 획득
COMMIT_HASH=$(git rev-parse --short HEAD)

# 3. 메모리에 실행 결과 저장
bash .hxsk/hooks/md-store-memory.sh "Plan 1.2 Complete" "Commit: $COMMIT_HASH" "execution" "execution-summary"
```

### PRD File Structure

- `.hxsk/prd-active.json` — 진행 중인 tasks (pending, in_progress, blocked)
- `.hxsk/prd-done.json` — 완료된 tasks (done)

완료 시 task가 active에서 done으로 자동 이동됩니다.

### Output Format

모든 명령은 JSON 형식으로 결과를 출력합니다:

```json
{
  "success": true,
  "action": "completed",
  "task": {"id": "TASK-001", "title": "...", "status": "done"},
  "remaining": 5
}
```

---

## SUMMARY.md Format

After plan completion, create `.hxsk/phases/{N}/{plan}-SUMMARY.md`:

```markdown
---
phase: {N}
plan: {M}
completed_at: {timestamp}
duration_minutes: {N}
---

# Summary: {Plan Name}

## Results
- {N} tasks completed
- All verifications passed

## Tasks Completed
| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | {name} | {hash} | ✅ |
| 2 | {name} | {hash} | ✅ |

## Deviations Applied
{If none: "None — executed as planned."}

- [Rule 1 - Bug] Fixed null check in auth handler
- [Rule 2 - Missing Critical] Added input validation

## Files Changed
- {file1} - {what changed}
- {file2} - {what changed}

## Verification
- {verification 1}: ✅ Passed
- {verification 2}: ✅ Passed
```

---

## Need-to-Know Context

Load ONLY what's necessary for current task:

**Always load:**
- The PLAN.md being executed
- .hxsk/STATE.md for position context

**Load if referenced:**
- Files in `<context>` section
- Files in task `<files>`

**Never load automatically:**
- All previous SUMMARYs
- All phase plans
- Full architecture docs

**Principle:** Fresh context > accumulated context. Keep it minimal.

---

## Anti-Patterns

### Continuing past checkpoint
Checkpoints mean STOP. Never continue after checkpoint.

### Redoing committed work
If continuation agent, verify commits exist, don't redo.

### Loading everything
Don't load all SUMMARYs, all plans. Need-to-know only.

### Ignoring deviations
Always track and report deviations in Summary.

### Atomic commits
One task = one commit. Always.

### Verification before done
Run verify step. Confirm done criteria. Then commit.

---

## 관련 스킬

- **REQUIRED**: `empirical-validation` — 태스크 완료 전 Gate Function으로 검증
- **REQUIRED**: `commit` — atomic commit 프로토콜
- **RECOMMENDED**: `plan-checker` — 실행 전 계획 유효성 검증
- **RECOMMENDED**: `memory-protocol` — 실행 결과/이탈 기록

---

## 네이티브 도구 활용

PLAN.md 파싱과 상태 관리는 네이티브 도구로 수행:

```
# PLAN.md에서 태스크 추출
Grep(pattern: "<task id=", path: ".hxsk/phases/", output_mode: "content")

# 완료된 태스크 확인
Grep(pattern: "status:.*done|status:.*completed", path: ".hxsk/", output_mode: "files_with_matches")

# 실행 결과 메모리 저장
bash .hxsk/hooks/md-store-memory.sh "Execution: {plan}" "{summary}" "execution,summary" "execution-summary"
```
