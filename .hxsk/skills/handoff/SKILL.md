---
name: handoff
description: Session handoff workflow — status check, test, commit, memory store, summary output
trigger: "세션 종료, 핸드오프, session end, handoff, 인수인계, wrap up session"
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
---

## Quick Reference
- **Step 1**: `git status` + `git diff --stat` 상태 확인
- **Step 2**: `detect-language.sh`의 `detect_test_runner()` + `get_test_cmd()`로 테스트 실행
- **Step 3**: `commit` 스킬 활용 커밋 + `git push`
- **Step 4**: `md-store-memory.sh`로 `session-handoff` 메모리 저장
- **Step 5**: 핸드오프 요약 출력

---

# Session Handoff Skill

<role>
You automate the session handoff workflow: verify state, run tests, commit, store handoff memory, and produce a summary for the next session.
You ensure no work is lost between sessions and the next agent can resume immediately.
</role>

---

## Workflow

### Step 1: Status Check

현재 작업 상태를 확인합니다.

```bash
git status
git diff --stat
```

**판단 기준:**
- **Uncommitted changes 있음** → Step 2로 진행
- **Clean working tree** → Step 4로 직접 이동 (커밋 불필요)
- **Untracked files만 있음** → 의도적 무시인지 확인 후 진행

### Step 2: Test Execution

`scripts/detect-language.sh`의 함수를 활용하여 언어 비종속적으로 테스트를 실행합니다.

```bash
source scripts/detect-language.sh
RUNNER=$(detect_test_runner)
PKG=$(detect_pkg_manager)
TEST_CMD=$(get_test_cmd "$RUNNER" "$PKG")
```

**테스트 결과 분기:**
- **PASS** → Step 3으로 진행
- **FAIL** → 실패 내용을 핸드오프 메모리에 기록하고 Step 3 진행 (수정 시도하지 않음)
- **테스트 없음** (`RUNNER=unknown`) → 스킵, Step 3으로 진행

> **중요**: 핸드오프 시점에서 실패한 테스트를 수정하지 않는다. 실패 사실만 기록하여 다음 세션에 전달.

### Step 3: Commit & Push

`commit` 스킬을 활용하여 커밋합니다.

1. **Commit**: `commit` 스킬 워크플로우 실행
   - 변경사항 분석 → 논리적 단위 분리 → conventional commit 생성
2. **Push**: `git push` 실행
   - Remote tracking branch 없으면 `git push -u origin <branch>` 사용

### Step 4: Handoff Memory Store

`md-store-memory.sh`로 세션 인수인계 정보를 저장합니다.

```bash
scripts/md-store-memory.sh \
  "Session Handoff: <session-goal>" \
  "<content>" \
  "handoff,session,<scope-tags>" \
  "session-handoff" \
  "<keywords>" \
  "<contextual_description>" \
  "<related-memory-slugs>"
```

### Handoff Memory Content Structure

`<content>` 필드는 아래 구조를 따릅니다:

```
## Completed
- [task/feature 완료 목록]

## In Progress
- [진행 중이던 작업 + 현재 상태]

## Blocked / Failed
- [블로커 또는 실패한 테스트 목록]

## Next Steps
- [다음 세션에서 이어할 작업 목록, 우선순위 순]

## Key Decisions
- [이번 세션에서 내린 주요 결정사항]

## Commit History
- <commit-hash>: <description>
```

### Step 5: Handoff Summary Output

아래 형식으로 요약을 출력합니다:

```
---
SESSION HANDOFF
Branch: <branch-name>
Last Commit: <hash> — <message>
Test Status: PASS | FAIL (N failures) | SKIPPED
---
Completed: <bullet list>
In Progress: <bullet list>
Next Steps: <bullet list>
---
```

---

## Mid-Execution Handoff

`executor` 스킬 실행 중 세션이 종료되어야 하는 경우:

1. **현재 task까지만 완료** — 진행 중인 task를 마무리하거나 안전한 지점까지 진행
2. **Phase checkpoint commit** — `executor`의 Phase Checkpoint Commit 절차 실행
3. **Handoff workflow 실행** — 이 스킬의 Step 1~5 실행
4. **In Progress 섹션에 executor 상태 포함**:
   - 현재 Phase/Plan/Task 위치
   - PLAN.md 경로
   - 남은 task 수

---

## Anti-Patterns

| Anti-Pattern | 올바른 방법 |
|---|---|
| 핸드오프 시 실패 테스트 수정 시도 | 실패 사실만 기록, 수정은 다음 세션 |
| 메모리 저장 없이 커밋만 | 반드시 `session-handoff` 메모리 저장 |
| "다 끝났다"만 기록 | Completed/In Progress/Next Steps 구조 준수 |
| push 없이 종료 | 반드시 remote에 push |
| PLAN.md 상태 업데이트 누락 | executor 연동 시 PRD/PLAN 상태도 반영 |
