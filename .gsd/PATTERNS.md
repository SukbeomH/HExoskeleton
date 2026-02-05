# Codebase Patterns

> **Purpose**: Distilled learnings for fresh sessions. Max 20 items, ~2KB.
> **Rule**: Only add patterns that are general and reusable, not task-specific.

---

## Architecture
- `.gsd/`에서 `templates/`, `examples/`, `STATE.md`, `PATTERNS.md`만 git 추적. 나머지는 런타임 데이터로 gitignore
- Agent-Skill 래핑: Skill은 How, Agent는 When/With What. `.claude/skills/` + `.claude/agents/`
- **외부 종속성 없음**: 순수 bash 스크립트 + 네이티브 Claude Code 도구만 사용

## Memory System
- **저장**: `bash .claude/hooks/md-store-memory.sh <title> <content> [tags] [type] [keywords] [contextual_desc] [related]`
- **검색**: `bash .claude/hooks/md-recall-memory.sh <query> [path] [limit] [mode] [hop]`
- **A-Mem 필드**: `keywords`, `contextual_description`, `related` (2-hop 검색용)
- **중복 방지**: 동일 title 저장 시 `[SKIP:DUPLICATE]` 반환 (Nemori Predict-Calibrate)
- **스키마**: `.gsd/memories/_schema/`에 JSON Schema + type-relations.yaml

## Conventions
- 커밋: atomic, conventional format. PR 통해 master 병합 (protected branch)
- 스킬 2단계 로딩: `## Quick Reference` 섹션(5줄)으로 빠른 컨텍스트 제공

## Gotchas
- 메모리 검색은 Grep → Glob 순서 (broad → narrow)
- 세션 종료 시 자동 메모리 저장 (`stop-context-save.sh`)
- 메모리 타입 14개: architecture-decision, root-cause, debug-eliminated, debug-blocked, health-event, session-handoff, execution-summary, deviation, pattern-discovery, bootstrap, session-summary, session-snapshot, security-finding, general

## Memory Triggers
| Trigger | Type | Timing |
|---------|------|--------|
| Bug root cause | `root-cause` | Immediate |
| Architecture decision | `architecture-decision` | Immediate |
| Hypothesis eliminated | `debug-eliminated` | Immediate |
| Session end | `session-summary` | Auto (hook) |

---

*Last updated: 2026-02-05*
*Items: 14/20*
