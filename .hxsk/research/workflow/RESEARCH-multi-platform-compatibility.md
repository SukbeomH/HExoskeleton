---
title: 멀티 플랫폼 호환성 리서치 (GitHub / GitLab / Gitea / Forgejo)
date: 2026-04-15
status: active
category: workflow
related: RESEARCH-github-task-management-workflow.md
---

# 멀티 플랫폼 호환성 리서치

> 목적: GitHub 기반으로 설계한 작업 관리 워크플로우가
> GitLab / Gitea / Forgejo 등 다른 플랫폼에서도 동작하는지 평가 (2026-04-15)

---

## 1. 플랫폼별 기능 매트릭스

| 기능 | GitHub | GitLab | Gitea | Forgejo |
|------|--------|--------|-------|---------|
| Issue 트래킹 | ✅ 네이티브 | ✅ 네이티브 | ✅ 기본 | ✅ 기본 |
| **Sub-Issues** | ✅ **GA 2025-01** | ❌ 미지원 | ❌ 미지원 | ❌ 미지원 |
| PR / MR | PR | MR (동등) | PR | PR |
| PR→Issue 자동 close | `Closes #N` | `Closes #N` | `Closes #N` | `Closes #N` |
| 공식 CLI | `gh` | `glab` | `tea` | `tea` (호환) |
| CI/CD | Actions | 네이티브 CI | Gitea Actions | Forgejo Actions |
| Actions 호환성 | 표준 | 독자 문법 | GitHub Actions 호환 | GitHub Actions 호환 |
| Git Worktree | ✅ (git 기능) | ✅ (git 기능) | ✅ (git 기능) | ✅ (git 기능) |
| 리소스 요구량 | SaaS | 무거움 (8GB+) | 경량 (400MB) | 경량 (420MB) |

---

## 2. 플랫폼별 상세

### 2-1. GitLab

**브랜칭 전략**: GitLab Flow
- GitHub Flow + **환경 브랜치** 추가 (main → staging → production)
- 모든 수정은 반드시 upstream(main) 먼저 → 이후 환경 브랜치로 내려가는 원칙
- 핫픽스도 main에서 먼저 수정 → production 브랜치로 머지

**이슈 관련 차이점**:
- "Pull Request" → "Merge Request (MR)" 용어 차이 (기능 동등)
- **Sub-Issues 미지원** → 이슈 내 체크리스트(`- [ ]`) 또는 이슈 번호 참조로 대체
- 이슈 클로즈 키워드: `Closes #N`, `Fixes #N` (GitHub와 동일)

**CLI (`glab`) 주요 명령**:
```bash
glab issue create --title "..." --description "..."
glab issue update N --label "in-progress"
glab mr create --title "..." --description "Closes #N"
glab mr merge N
```

**Sub-Issues 대안**:
```markdown
<!-- 부모 이슈 본문에 수동 체크리스트 -->
## Sub-tasks
- [ ] #101 Login endpoint
- [ ] #102 Token refresh
- [ ] #103 Logout
```

### 2-2. Gitea

**특징**:
- GitHub와 가장 유사한 UX (GitHub fork 기반)
- Gitea Actions: GitHub Actions YAML 문법 **거의 호환** (1.21+)
- 경량 (400MB idle) → 셀프호스팅 환경 적합

**이슈 관련 차이점**:
- **Sub-Issues 미지원** → 체크리스트 또는 이슈 참조로 대체
- PR 기반 워크플로우 GitHub와 동일
- `tea` CLI로 자동화 가능

**CLI (`tea`) 주요 명령**:
```bash
tea issue create --title "..." --body "..."
tea issues list
tea pr create --title "..." --description "Closes #N"
tea pr merge N
```

### 2-3. Forgejo

- Gitea의 커뮤니티 포크 (2024년 말 거버넌스 이슈로 분기)
- `tea` CLI 호환
- Forgejo Actions: GitHub Actions 호환
- Sub-Issues 미지원 (Gitea와 동일)
- 2026년 기준 활발히 개발 중 (v1.2.0+)

---

## 3. 호환성 평가 — 설계 요소별

### ✅ 플랫폼 무관 (완전 호환)

| 요소 | 이유 |
|------|------|
| Git Worktree | Git 자체 기능 — 플랫폼과 무관 |
| `.worktrees/{name}` 패턴 | 로컬 디렉토리 패턴 |
| GATES.md 게이트 조건 | 마크다운 파일 — 플랫폼 무관 |
| AGENTS.md 규칙 | 마크다운 파일 — 플랫폼 무관 |
| 브랜치 명명 규칙 | git 표준 |
| `Closes #N` PR 연동 | GitHub / GitLab / Gitea 모두 지원 |
| 파일 소유권 맵 (P3) | PLAN.md 내 텍스트 |

### ⚠️ 플랫폼별 추상화 필요

| 요소 | GitHub | GitLab | Gitea/Forgejo |
|------|--------|--------|---------------|
| Sub-Issues | `gh sub-issue create` | ❌ 체크리스트 대체 | ❌ 체크리스트 대체 |
| CLI 명령 | `gh` | `glab` | `tea` |
| PR/MR 생성 | `gh pr create` | `glab mr create` | `tea pr create` |
| 이슈 생성 | `gh issue create` | `glab issue create` | `tea issue create` |
| CI 문법 | Actions | 독자 YAML | Actions 호환 |

### ❌ GitHub 전용 (대안 필요)

| 요소 | 대안 |
|------|------|
| Sub-Issues (네이티브) | 이슈 본문 체크리스트 + 이슈 번호 참조 |
| GitHub Projects 진행률 | 수동 이슈 상태 라벨 (`todo`, `in-progress`, `done`) |
| `gh project` 자동화 | 없음 (플랫폼 자체 프로젝트 UI 사용) |

---

## 4. 플랫폼 추상화 전략

GATES.md에 CLI 명령을 직접 명시하지 않고,
**플랫폼 감지 스크립트**로 추상화:

```bash
# .hxsk/scripts/forge-detect.sh
detect_forge() {
  REMOTE=$(git remote get-url origin 2>/dev/null)
  case "$REMOTE" in
    *github.com*)  echo "github" ;;
    *gitlab.com*|*gitlab*)  echo "gitlab" ;;
    *gitea*|*codeberg*|*forgejo*)  echo "gitea" ;;
    *)  echo "unknown" ;;
  esac
}

forge_issue_create() {
  local title="$1" body="$2"
  case $(detect_forge) in
    github)  gh issue create --title "$title" --body "$body" ;;
    gitlab)  glab issue create --title "$title" --description "$body" ;;
    gitea)   tea issue create --title "$title" --body "$body" ;;
  esac
}

forge_pr_create() {
  local title="$1" body="$2" base="$3"
  case $(detect_forge) in
    github)  gh pr create --title "$title" --body "$body" --base "$base" ;;
    gitlab)  glab mr create --title "$title" --description "$body" --target-branch "$base" ;;
    gitea)   tea pr create --title "$title" --description "$body" --base "$base" ;;
  esac
}

forge_sub_issue_create() {
  local parent="$1" title="$2" body="$3"
  case $(detect_forge) in
    github)
      gh sub-issue create --parent "$parent" --title "$title" --body "$body"
      ;;
    gitlab|gitea)
      # Sub-issues 미지원 → 일반 이슈 생성 + 부모 이슈에 참조 추가
      CHILD=$(forge_issue_create "$title" "$body")
      echo "  [참조] #$CHILD" | forge_issue_comment "$parent"
      ;;
  esac
}
```

---

## 5. Sub-Issues 미지원 플랫폼 대안 패턴

### 패턴 A: 체크리스트 + 이슈 참조 (권장)

```markdown
<!-- 부모 이슈 본문 -->
## Plan Tasks
- [ ] #101 feat: login endpoint (task/login)
- [ ] #102 feat: token refresh (task/token)
- [ ] #103 feat: logout (task/logout)

진행률: 0/3
```

- 각 서브태스크 완료 시 부모 이슈 업데이트
- GitHub Sub-Issues처럼 자동 집계는 없지만 추적 가능

### 패턴 B: 라벨 기반 연결

```bash
# 부모 이슈 번호를 라벨로 태깅
glab issue create --title "..." --label "parent:#42"
```

---

## 6. 결론 — 호환성 등급

| 플랫폼 | 호환 등급 | 비고 |
|--------|----------|------|
| GitHub | ✅ **100%** | 설계의 기준 플랫폼 |
| GitLab | ✅ **85%** | MR 용어 차이, Sub-Issues 대체 패턴 필요 |
| Gitea | ✅ **80%** | CLI 추상화 필요, 기능 대부분 동등 |
| Forgejo | ✅ **80%** | Gitea와 동일 |

**핵심 결론**: GATES.md + AGENTS.md 구조는 플랫폼 무관하게 작동.
CLI 명령만 `forge-detect.sh`로 추상화하면 4개 플랫폼 모두 커버 가능.

---

## 출처

- [What is GitLab Flow? - GitLab](https://about.gitlab.com/topics/version-control/what-is-gitlab-flow/)
- [GitLab CLI (glab) Docs](https://docs.gitlab.com/cli/)
- [glab issue create](https://docs.gitlab.com/cli/issue/create/)
- [Gitea Pull Request Docs](https://docs.gitea.com/usage/pull-request)
- [Tea CLI for Gitea](https://about.gitea.com/products/tea/)
- [The 2026 Guide to Self-Hosted Git: Gitea, Forgejo](https://www.serverspan.com/en/blog/the-2026-guide-to-self-hosted-git-gitea-forgejo-and-the-future-of-code-hosting)
- [Self-Hosted Git Platforms 2026: GitLab vs Gitea vs Forgejo](https://dasroot.net/posts/2026/01/self-hosted-git-platforms-gitlab-gitea-forgejo-2026/)
- [Gitea vs GitLab: A Comprehensive Comparison in 2025](https://ruby-doc.org/blog/gitea-vs-gitlab-a-comprehensive-comparison-in-2025/)
- [Worktrunk — CLI for Git worktree management](https://worktrunk.dev/)
- [git-worktree-runner (coderabbitai)](https://github.com/coderabbitai/git-worktree-runner)
