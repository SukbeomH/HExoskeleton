---
title: GitHub 기반 작업 관리 워크플로우 리서치
date: 2026-04-15
status: active
category: workflow
---

# GitHub 기반 작업 관리 워크플로우 리서치

> 목적: 멀티에이전트 병렬 개발 환경에서 GitHub Issue/PR/Worktree를 활용한
> 작업 관리 워크플로우 설계를 위한 레퍼런스 조사 (2026-04-15)

---

## 1. GitHub Flow — 브랜칭 전략

### 핵심 원칙

- `main` 브랜치는 **항상 배포 가능** 상태 유지
- 모든 작업은 `feat/`, `task/`, `fix/` 등 descriptive 브랜치에서 진행
- 브랜치 수명은 **짧게** 유지 (Trunk-Based Development 원칙 혼용)
- PR 머지 직후 배포 → 빠른 피드백 루프

### 병렬 작업 시 권장 사항

- 각 태스크는 **독립 브랜치** + **독립 이슈** 로 1:1 대응
- 관련 없는 변경은 반드시 **별도 브랜치**로 분리 (리뷰어 부담 감소)
- 공유 파일 수정 시 **파일 소유권 선언** 필수 (컨플릭트 예방)

### 출처

- [GitHub flow - GitHub Docs](https://docs.github.com/en/get-started/using-github/github-flow)
- [Git Branching Strategies - GitFlow, Github Flow, Trunk Based](https://www.usefulfunctions.co.uk/2025/11/05/git-branching-flow-github-flow-trunk-based/)
- [What is the best Git branch strategy? | GitKraken](https://www.gitkraken.com/learn/git/best-practices/git-branch-strategy)

---

## 2. Git Worktree + 멀티에이전트

### 동작 원리

- 하나의 `.git` 오브젝트 스토어를 공유하면서 **디렉토리별 독립 워킹 트리** 제공
- 각 에이전트가 서로 다른 워크트리에서 동시에 작업 → 파일 충돌 원천 차단
- `.worktrees/{task-name}` 디렉토리 패턴 사용 (gitignore 처리)

### 업계 채택 현황 (2026)

| 도구 | 채택 방식 |
|------|-----------|
| Cursor Parallel Agents | 내부적으로 git worktree 사용 |
| Claude Code | `--worktree` 플래그로 공식 지원 |
| VS Code | 2025년 7월 worktree 지원 추가 |
| JetBrains IDE | 2026.1 릴리즈(2026-03)에 first-class 지원 |

### 주요 충돌 패턴 6가지

1. **Lockfile 충돌**: `package-lock.json`, `uv.lock` 동시 수정 → 5000줄 diff
2. **Config 파일 충돌**: 공통 설정 파일 병렬 수정
3. **Migration 파일 충돌**: DB 마이그레이션 번호 충돌
4. **빌드 산출물 충돌**: dist/, build/ 공유
5. **Git 훅 충돌**: `.git/hooks` 공유로 인한 경쟁 조건
6. **인덱스 락 충돌**: `.git/index.lock` 경쟁

### 충돌 예방 전략

```
태스크 분할 시 → 파일 소유권 맵 명시 (P3 단계)
겹치는 파일 발견 → 태스크 재분할 또는 직렬화
Lockfile 변경 태스크 → 단독 워크트리, 병렬 금지
```

### 출처

- [Using Git Worktrees for Multi-Feature Development with AI Agents](https://www.nrmitchi.com/2025/10/using-git-worktrees-for-multi-feature-development-with-ai-agents/)
- [How to Use Git Worktrees for Parallel AI Agent Execution | Augment Code](https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution)
- [Git Worktrees: The Power Behind Cursor's Parallel Agents](https://dev.to/arifszn/git-worktrees-the-power-behind-cursors-parallel-agents-19j1)
- [Git Worktree Conflicts with Multiple AI Agents | Termdock](https://www.termdock.com/en/blog/git-worktree-conflicts-ai-agents)
- [How to Run a Multi-Agent Coding Workspace (2026) | Augment Code](https://www.augmentcode.com/guides/how-to-run-a-multi-agent-coding-workspace)
- [Parallel AI Coding with Git Worktrees and Custom Claude Code Commands](https://docs.agentinterviews.com/blog/parallel-ai-coding-with-gitworktrees/)

---

## 3. GitHub Sub-Issues (2025년 GA)

### 주요 특징

- 2025년 1월 **General Availability** 출시
- 부모 이슈 → 하위 이슈 계층 구조 **네이티브 지원**
- 부모 이슈에서 하위 이슈 진행률 **자동 집계** (퍼센트 표시)
- 하위 이슈는 일반 이슈 기능 전체 유지 (라벨, 마일스톤, PR 링크 등)
- 하위 이슈의 부모는 1개만 가능

### 자동화 방법

```bash
# GitHub CLI + gh-sub-issue 확장
gh sub-issue create \
  --parent 123 \
  --title "Add login endpoint" \
  --body "Implement POST /api/login" \
  --label "backend,api"

# GraphQL mutation (스크립트 자동화)
gh api graphql -f query='
  mutation {
    addSubIssue(input: {issueId: "...", subIssueId: "..."}) {
      issue { number }
    }
  }'
```

### PR-Issue 자동 연동

```markdown
<!-- PR 본문에 포함 시 머지 시 이슈 자동 close -->
Closes #123
Fixes #456
```

### 출처

- [Introducing sub-issues: Enhancing issue management on GitHub](https://github.blog/engineering/architecture-optimization/introducing-sub-issues-enhancing-issue-management-on-github/)
- [Adding sub-issues - GitHub Docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)
- [gh-sub-issue GitHub CLI extension](https://github.com/yahsan2/gh-sub-issue)
- [gh-sub-issues management tool](https://github.com/d-oit/gh-sub-issues)
- [Evolving GitHub Issues and Projects (GA)](https://github.com/orgs/community/discussions/154148)

---

## 4. 멀티에이전트 오케스트레이션 패턴

### Conductor 패턴 (2026 업계 표준)

```
Orchestrator 에이전트 (Conductor)
  ├── 태스크 분해 + 파일 경계 지정
  ├── 각 서브에이전트에 워크트리 할당
  ├── GitHub 이슈로 진행 상태 추적
  └── 머지 전 자동 검증 실행

서브에이전트 A (워크트리 A)
  ├── 독립 브랜치에서 작업
  ├── 완료 시 이슈 댓글 → PR 생성
  └── 리뷰 통과 → 머지

서브에이전트 B (워크트리 B)
  └── (동일 패턴)
```

### 핵심 규칙

- **파일 소유권 선언 필수**: 태스크 시작 전 수정할 파일 목록 명시
- **짧은 수명 브랜치**: EXECUTE 완료 즉시 PR → 머지 → 워크트리 삭제
- **머지 전 자동 검증**: 테스트 통과 + 원래 계획 의도 검증
- **루트에서 직접 작업 금지**: 반드시 워크트리에서 작업

### 출처

- [Agent Teams Workflow - claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/guide/workflows/agent-teams.md)
- [The Parallel Agent Multiplier with Git Worktrees and Conductor](https://elite-ai-assisted-coding.dev/p/the-parallel-agent-multiplier-conductor-with-charlie-holtz)
- [Agent Teams or: How I Learned to Stop Worrying About Merge Conflicts](https://engineering.intility.com/article/agent-teams-or-how-i-learned-to-stop-worrying-about-merge-conflicts-and-love-git-worktrees)

---

## 5. 에이전트 하네스별 호환 방식

| 하네스 | 설정 파일 | 작업 관리 방식 |
|--------|-----------|---------------|
| Claude Code | `.hxsk/hooks/` + `CLAUDE.md` | 훅으로 게이트 집행 |
| opencode | `AGENTS.md` | 마크다운 규칙 참조 |
| Antigravity | `AGENTS.md` | 마크다운 규칙 참조 |
| GitHub Copilot | `.github/copilot-instructions.md` + `AGENTS.md` | 마크다운 규칙 참조 |

**공통 전략**: `GATES.md` 단일 진실 원천 → 각 하네스별 참조

---

## 핵심 결론 (설계 반영 사항)

| 발견 | 설계 반영 |
|------|-----------|
| Sub-Issues GA (2025-01) | P4에서 `gh sub-issue create` 사용 |
| `.worktrees/` 패턴 표준화 | P5에서 `.worktrees/{task-name}` 생성 |
| 파일 소유권 선언 필수 | P3 분석에 "파일 소유권 맵" 단계 추가 |
| Lockfile 충돌 최빈도 | 의존성 변경 태스크는 병렬 금지 게이트 추가 |
| Conductor 패턴 표준화 | Orchestrator가 GATES.md 기준으로 집행 |
| 짧은 수명 브랜치 원칙 | EXECUTE 완료 즉시 PR 생성 조건 추가 |
