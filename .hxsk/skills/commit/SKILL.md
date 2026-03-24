---
name: commit
description: Analyzes diffs, splits logical changes, creates conventional emoji commits aligned with HXSK atomic commit protocol
trigger: "커밋 생성, git commit, 커밋 메시지 작성, 변경사항 커밋, conventional commit"
---

## Quick Reference
- **Pre-commit**: `shellcheck *.sh` (선택적), `git diff --stat` 확인
- **Commit format**: `<emoji> <type>(<scope>): <description>`
- **Types**: feat, fix, docs, style, refactor, perf, test, chore, ci
- **HXSK scope**: `(phase-N.M)` 형식 — 예: `feat(phase-1.2): add login endpoint`
- **Split signals**: 다른 모듈, 혼합 유형(feature+config), 독립 버그 수정

---

# HXSK Commit Skill

<role>
You create well-structured git commits following conventional commit format with emoji.
You analyze diffs to detect multiple logical changes and suggest splitting into separate commits.

This skill is the shipping mechanism for HXSK executor's atomic commit requirement.
</role>

---

## Workflow

### Step 1: Pre-Commit Checks

Run quality checks before committing:

**Qlty 경로** (`.qlty/qlty.toml` 존재 시):
```bash
qlty check                        # Lint (all detected linters)
# Test: project-config.yaml의 tools.test_runner.command
```

**Shell 스크립트 검사**:
```bash
shellcheck *.sh                  # Shell script lint (선택)
```

If checks fail, report failures and ask whether to:
1. Fix issues first (recommended)
2. Proceed anyway (`--no-verify` flag)

### Step 2: Analyze Staged Changes

```bash
git status                        # Check staged/unstaged files
git diff --cached --stat          # Staged changes overview
git diff --cached                 # Full staged diff
```

If no files are staged, stage all modified files:
```bash
git add -A
```

### Step 3: Detect Logical Splits

Analyze the diff for multiple distinct concerns:

**Split signals:**
- Changes to unrelated modules (e.g., `src/auth/` + `src/billing/`)
- Mixed change types (feature code + test code + config)
- Different file categories (source vs docs vs config)
- Independent bug fixes bundled with features

If multiple concerns detected, suggest splitting:
```
Detected 3 logical changes:
1. feat: add user validation in src/auth/
2. test: add validation tests
3. chore: update pyproject.toml dependencies

Split into separate commits? [Y/n]
```

### Step 4: Create Commit

Use conventional commit format with emoji:

```bash
git commit -m "$(cat <<'EOF'
<emoji> <type>(<scope>): <description>

<optional body>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Commit Types

| Emoji | Type | Description |
|-------|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Formatting, no logic change |
| `refactor` | Code restructuring |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `chore` | Tooling, config, dependencies |
| `ci` | CI/CD changes |

### HXSK-Specific Scopes

When executing HXSK plans, use phase-plan scope:

```
feat(phase-1.2): implement login endpoint with JWT
fix(phase-2.1): resolve bcrypt comparison error
test(phase-1.3): add integration tests for auth flow
```

---

## Commit Message Rules

- **Imperative mood**: "add feature" not "added feature"
- **First line**: max 72 characters (제목 50자 이내 권장)
- **Scope**: module or phase-plan reference
- **Body**: explain WHY, not WHAT (the diff shows WHAT). 본문은 72자 줄바꿈
- **No period** at the end of the subject line
- **Issue linking**: 이슈를 닫는 커밋에는 `Resolved #N` 포함

> 상세 컨벤션: `docs/CONVENTIONS.md` 섹션 4 참조

---

## Examples

### Single Commit
```
feat(auth): add JWT-based login endpoint

Implements POST /api/auth/login with bcrypt password verification
and httpOnly cookie response. Uses jose library for Edge runtime
compatibility.
```

### Split Commits (from single diff)
```bash
# Commit 1: Feature code
git add src/auth/
git commit -m "feat(auth): add JWT-based login endpoint"

# Commit 2: Tests
git add tests/auth/
git commit -m "test(auth): add login endpoint integration tests"

# Commit 3: Config
git add pyproject.toml uv.lock
git commit -m "chore(deps): add jose and bcrypt dependencies"
```

## 네이티브 도구 활용

Diff 분석과 커밋 분할은 git 명령과 네이티브 도구로 수행:

```bash
# 변경된 파일 목록
git diff --name-only HEAD~1

# 파일별 변경 통계
git diff --stat

# 논리적 분할 판단 (서로 다른 디렉토리/모듈)
git diff --name-only | xargs -I{} dirname {}  | sort -u
```
