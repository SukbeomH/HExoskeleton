# .hxsk/ 경로 통합: scripts/, docs/, prompts/ 이동

> Date: 2026-03-26
> Status: DRAFT
> Scope: 디렉토리 이동 + 참조 업데이트 + GitHub 릴리즈 setup 프롬프트 표시

## Core Concept

적용 프로젝트에 복사되는 모든 HXSK 관리 파일을 `.hxsk/` 하위로 통합.
루트에 남는 것은 레포 메타파일(Makefile, README, CHANGELOG) + 에이전트 지침(CLAUDE.md 등) + 에셋만.

## Directory Move Map

```
scripts/bootstrap.sh         →  .hxsk/scripts/bootstrap.sh
scripts/issue-create.sh      →  .hxsk/scripts/issue-create.sh
scripts/issue-list.sh        →  .hxsk/scripts/issue-list.sh
scripts/merge-worktrees.sh   →  .hxsk/scripts/merge-worktrees.sh
scripts/memory-cleanup.sh    →  .hxsk/scripts/memory-cleanup.sh
scripts/generate-llms-txt.sh →  .hxsk/scripts/generate-llms-txt.sh
scripts/detect-language.sh   →  .hxsk/scripts/detect-language.sh
docs/*.md                    →  .hxsk/docs/*.md
prompts/setup.md             →  .hxsk/prompts/setup.md
prompts/setup-claude.md      →  .hxsk/prompts/setup-claude.md
```

삭제: `scripts/` wrapper 스크립트 (md-store-memory.sh 등 — .hxsk/hooks/로 위임하던 것)

유지 (루트): Makefile, README.md, CHANGELOG.md, CLAUDE.md, AGENTS.md, GEMINI.md, llms.txt, logo.*, .cursorrules, .windsurfrules

## Reference Updates

| 파일 | 변경 |
|------|------|
| README.md | docs/ → .hxsk/docs/, prompts/ → .hxsk/prompts/, scripts/ → .hxsk/scripts/ |
| AGENTS.md | prompts/setup.md → .hxsk/prompts/setup.md, Repository Layout 업데이트 |
| Makefile | scripts/bootstrap.sh → .hxsk/scripts/bootstrap.sh |
| .gitignore | !.hxsk/scripts/, !.hxsk/docs/, !.hxsk/prompts/ 추가 |
| .github/agents/agent.md | scripts/ → .hxsk/scripts/ |
| .github/copilot-instructions.md | prompts/ → .hxsk/prompts/ |
| .hxsk/PATTERNS.md | scripts/ → .hxsk/hooks/ (canonical) |
| .hxsk/ARCHITECTURE.md | scripts/ 디렉토리 설명 업데이트 |

## GitHub Release Setup Prompts

릴리즈 시 setup.md, setup-claude.md를 릴리즈 asset으로 첨부 + body에 안내.

## Design Decisions

| 결정 | 선택 | 이유 |
|------|------|------|
| Makefile | 루트 유지 | HXSK 레포 개발 전용, 적용 프로젝트 미복사 |
| README 링크 | .hxsk/ 경로로 변경 | 실제 구조 반영, 심볼릭 링크 불필요 |
| wrapper 스크립트 | 삭제 | .hxsk/hooks/가 canonical, 중복 제거 |
