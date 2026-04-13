---
name: create-pr
description: Analyzes changes, creates branch, splits commits logically, pushes and creates pull request via gh CLI
trigger: "PR 생성, 풀 리퀘스트 만들기, push and create PR, gh pr create"
---

## Quick Reference
- **Branch naming**: `feat/<desc>`, `fix/<desc>`, `refactor/<desc>`, `docs/<desc>`
- **PR 생성**: `gh pr create --title "..." --body "..."`
- **PR Body**: Summary + Changes + Test Plan + HXSK Context 섹션
- **Push**: `git push -u origin $(git branch --show-current)`
- **Output**: `PR_CREATED: #N`, `URL: <url>`, `BRANCH: <name>`, `COMMITS: N`

---

# HXSK Create PR Skill

<role>
You create pull requests by analyzing changes, organizing commits logically, and submitting via GitHub CLI.
This is the shipping step of the HXSK workflow — moving completed work from local to remote.
</role>

---

## Workflow

### Step 1: Analyze Current State

```bash
git status                        # Working tree state
git branch --show-current         # Current branch
git log --oneline -10             # Recent commits
git diff --stat                   # Unstaged changes
git diff --cached --stat          # Staged changes
```

### Step 2: Create Branch (if on main/master)

If on main branch, create a feature branch:

```bash
# Branch naming: <type>/<short-description>
git checkout -b feat/add-user-auth
```

**Branch naming conventions:**
- `feature/{issue-number}-{description}` — New features
- `bugfix/{issue-number}-{description}` — Bug fixes
- `refactor/{issue-number}-{description}` — Refactoring
- `docs/{issue-number}-{description}` — Documentation
- `release/v{version}` — Release preparation

For HXSK phases (이슈 없는 경우):
- `feat/<description>` or `phase-1/implement-auth`

**규칙**: 이슈 번호 포함 필수, 영문 소문자 + 하이픈만 사용

### Step 3: Stage and Commit

Use the `commit` skill logic to:
1. Run pre-commit checks (shellcheck for shell scripts)
2. Analyze diff for logical splits
3. Create conventional emoji commits

### Step 4: Push to Remote

```bash
git push -u origin $(git branch --show-current)
```

### Step 5: Create Pull Request

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing the changes>

## Changes
<list of key changes with file references>

## Test Plan
- [ ] Quality checks pass (shellcheck for shell scripts)
- [ ] Manual verification completed
- [ ] <specific manual verification steps>

## HXSK Context
- Phase: <N>
- Plans: <list of completed plans>
- SPEC reference: `.hxsk/SPEC.md`
EOF
)"
```

---

## PR Title Format

Follow conventional commit style:
```
feat(auth): add JWT-based authentication
fix(api): resolve race condition in connection pool
refactor(models): extract validation into shared module
```

Keep under 70 characters.

---

## PR Body Guidelines

- **Summary**: What changed and why (not how — the diff shows how)
- **Changes**: Key files/modules affected
- **Test Plan**: How to verify the changes work
- **HXSK Context**: Phase/plan reference for traceability

## PR 크기 가이드라인

| 크기 | 프로덕션 코드 | 기준 |
|------|-------------|------|
| Small | ~200 lines | **목표** |
| Medium | ~500 lines | 허용 |
| Large | ~1,000 lines | 분리 검토 |
| XLarge | 1,000+ lines | **반드시 분리** |

## PR 생성 전 자가 점검

### 범위 / 크기
- [ ] 변경 목적이 2개 이상 포함되어 있지 않은가?
- [ ] 프로덕션 코드 변경이 500줄을 넘지 않는가?
- [ ] "이것도 같이 고치면 좋겠다"로 범위를 넓히지 않았는가?
- [ ] PR 설명만 읽고도 왜 이 변경이 필요한지 이해할 수 있는가?

### A/B/C/D/E 품질 점검 (REQUIRED)

먼저 lessons-learned 조회:

```bash
bash .hxsk/hooks/md-recall-memory.sh "pr quality check" \
  ".hxsk/memories/lessons-learned" 10 compact
```

**A. 코드 ↔ 문서 정합**
- [ ] 변경 함수/모듈의 docstring이 현재 구현과 일치
- [ ] PLAN.md 설명 ↔ 실제 구현 일치 (drift 시 둘 중 수정)

**B. 테스트 품질**
- [ ] 각 task에 real path 테스트 최소 1개 (mock-only 불가)
- [ ] DB/파일/연결 close() 또는 fixture teardown 존재
- [ ] 미사용 param은 `_` prefix 또는 제거됨

**C. 상태 동기화 / 의미론**
- [ ] cross_phase_invariants 위반 없음 (PLAN.md frontmatter 확인)
- [ ] 이전 phase 테스트 전원 통과

**D. Resource / Lifecycle**
- [ ] Threading 경계 resource 안전성 확인
- [ ] Shutdown/teardown path에 cleanup 존재

**E. Forward-compat**
- [ ] 현재 미사용 entity 제거 또는 명시적 사유 기재

**실패 항목 발견 시**: 수정 → 재검증 → 전 항목 통과 후 PR 생성.

## Merge 전략

| 상황 | 방식 |
|------|------|
| feature/bugfix → develop | **Squash and merge** |
| develop → main (릴리즈) | **Merge commit** |
| hotfix → main | **Merge commit** |

> 상세 컨벤션: `.hxsk/docs/CONVENTIONS.md` 섹션 5 참조

---

## Multi-Phase PRs

When a PR spans multiple HXSK plans:

```markdown
## HXSK Context
- Phase 1, Plans 1-3: User authentication
  - Plan 1.1: Database schema + User model
  - Plan 1.2: Login/register endpoints
  - Plan 1.3: JWT middleware + route protection
```

---

## Output

After PR creation, report:
```
PR_CREATED: #<number>
URL: <url>
BRANCH: <branch-name>
COMMITS: <count>
```

## 네이티브 도구 활용

PR 본문 생성은 git 명령과 네이티브 도구로 수행:

```bash
# 커밋 로그 수집
git log --oneline origin/main..HEAD

# diff 통계
git diff --stat origin/main..HEAD

# PR 생성 (gh CLI)
gh pr create --title "{title}" --body "{body}"
```
