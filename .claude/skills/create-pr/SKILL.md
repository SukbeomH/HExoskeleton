---
name: create-pr
description: Analyzes changes, creates branch, splits commits logically, pushes and creates pull request via gh CLI
---

## Quick Reference
- **Branch naming**: `feat/<desc>`, `fix/<desc>`, `refactor/<desc>`, `docs/<desc>`
- **PR 생성**: `gh pr create --title "..." --body "..."`
- **PR Body**: Summary + Changes + Test Plan + GSD Context 섹션
- **Push**: `git push -u origin $(git branch --show-current)`
- **Output**: `PR_CREATED: #N`, `URL: <url>`, `BRANCH: <name>`, `COMMITS: N`

---

# GSD Create PR Skill

<role>
You create pull requests by analyzing changes, organizing commits logically, and submitting via GitHub CLI.
This is the shipping step of the GSD workflow — moving completed work from local to remote.
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
- `feat/<description>` — New features
- `fix/<description>` — Bug fixes
- `refactor/<description>` — Refactoring
- `docs/<description>` — Documentation
- `chore/<description>` — Maintenance

For GSD phases:
- `phase-1/implement-auth` — Phase-scoped work

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

## GSD Context
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
- **GSD Context**: Phase/plan reference for traceability

---

## Multi-Phase PRs

When a PR spans multiple GSD plans:

```markdown
## GSD Context
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
