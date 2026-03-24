# Codebase Patterns

> **Purpose**: Distilled learnings for fresh sessions. Max 20 items, ~2KB.
> **Rule**: Only add patterns that are general and reusable, not task-specific.

---

## Architecture
- `.hxsk/`에서 `templates/`, `examples/`, `STATE.md`, `PATTERNS.md`만 git 추적. 나머지는 런타임 데이터로 gitignore
- Agent-Skill 래핑: Skill은 How, Agent는 When/With What. `.hxsk/skills/` + `.hxsk/agents/`
- **외부 종속성 없음**: 순수 bash 스크립트 + 네이티브 Claude Code 도구만 사용
- **Self-Configure 배포**: llms.txt + AGENTS.md + setup 프롬프트. 빌드 스크립트 없음, 레포 = 배포

## Memory System
- **저장**: `bash scripts/md-store-memory.sh <title> <content> [tags] [type]` (→ `.hxsk/hooks/` canonical로 위임)
- **검색**: `bash scripts/md-recall-memory.sh <query> [path] [limit] [mode]` (→ `.hxsk/hooks/` canonical로 위임)
- **A-Mem 필드**: `keywords`, `contextual_description`, `related` (2-hop 검색용)
- **중복 방지**: 동일 title → `[SKIP:DUPLICATE]` 반환
- **스키마**: `.hxsk/memories/_schema/` (JSON Schema + type-relations.yaml)

## Conventions
- 커밋: atomic, conventional format. PR 통해 master 병합 (protected branch)
- 스킬 2단계 로딩: `## Quick Reference` 섹션(5줄)으로 빠른 컨텍스트 제공
- **Discovery Level** vs **문서 계층**: Discovery Level(L0-L3)은 planner의 연구 깊이, 문서 계층(L1-L3)은 프롬프트 문서 레이어

## Gotchas
- 메모리 검색은 Grep → Glob 순서 (broad → narrow)
- 세션 종료 시 자동 메모리 저장 (`stop-context-save.sh`)
- 메모리 타입 14개: architecture-decision, root-cause, debug-eliminated, debug-blocked, health-event, session-handoff, execution-summary, deviation, pattern-discovery, bootstrap, session-summary, session-snapshot, security-finding, general

## Memory Triggers
- Bug root cause → `root-cause`, Architecture decision → `architecture-decision`, Session end → `session-summary` (auto hook)

## Plugin (Claude Code)
- `hooks/hooks.json`은 기본 자동 탐색 경로. 포맷: `{"hooks":{...}}` wrapper 필수. `${CLAUDE_PLUGIN_ROOT}`로 스크립트 경로 참조
- heredoc 내 코드 예시가 grep 패턴 오탐 유발 가능. `$ python3` prefix로 회피

---

> **로테이션**: 20개 도달 시 가장 오래되고 참조가 적은 패턴을 교체. 삭제 대신 `.hxsk/research/`로 아카이브.

*Last updated: 2026-03-24*
*Items: 17/20*
