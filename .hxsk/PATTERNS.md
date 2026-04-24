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
- **저장**: `bash .hxsk/hooks/md-store-memory.sh <title> <content> [tags] [type]`
- **검색**: `bash .hxsk/hooks/md-recall-memory.sh <query> [path] [limit] [mode]`
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
- **bash 전체 출력 로그 저장**: `exec > >(tee -a "$LOG_FILE") 2>&1` — subshell 없이 exit 코드 보존하며 stdout+stderr 파일 저장
- **검증 스크립트 set -e 금지**: 다중 조건 검증 시 `set -e` 대신 독립 if 블록으로 처리 — 하나 실패해도 나머지 조건 계속 검사

## Plugin (Claude Code)
- `hooks/hooks.json`은 기본 자동 탐색 경로. 포맷: `{"hooks":{...}}` wrapper 필수. `${CLAUDE_PLUGIN_ROOT}`로 스크립트 경로 참조

## LLM Hallucination Risk (Watson et al. 2026 — arXiv 2602.20300)
- **위험/보호 인자**: 특정성 부재(OR 2.382), 절 복잡도(1.764), 부정 사용(1.364) vs 답변 가능성(OR 0.331), intention grounding
- **적용**: SKILL.md `description`/`Iron Laws` 필드는 answerability·intention grounding 극대화 방향으로 작성. 불특정 주어·중첩 부정·깊은 절 구조 회피

---

> **로테이션**: 20개 도달 시 가장 오래되고 참조가 적은 패턴을 교체. 삭제 대신 `.hxsk/research/`로 아카이브.

*Last updated: 2026-04-24*
*Items: 20/20*
