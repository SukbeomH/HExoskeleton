# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See @AGENTS.md for shared project instructions (workflow, memory protocol, validation, agent boundaries).

## Claude Code Specific

### Hook System
- **Location**: `.hxsk/hooks/` (settings.json에서 참조)
- **Events**: SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SubagentStop, SessionEnd

### Skill & Agent Loading
- **Agent-Skill 래핑**: Skill(How) + Agent(When/With What)
- **Skills**: `.hxsk/skills/{name}/SKILL.md`
- **Agents**: `.hxsk/agents/{name}.md`

### Document Hierarchy
- **문서 계층**: L1=CLAUDE.md (요약) → L2=skills/SKILL.md (상세) → L3=.hxsk/research/ (출처)

## Compaction Rules
압축 시 반드시 보존:
- `.hxsk/.track-modifications.log` 변경 파일 목록
- 현재 SPEC.md 목표 및 활성 PLAN.md 태스크
- 이 세션의 메모리 검색 결과와 아키텍처 결정사항

## Prompt Maintenance Rules
CLAUDE.md, SKILL.md, Agent 정의 파일을 수정할 때:
- L1(CLAUDE.md): 포함=검색 순서/트리거/제약, 제외=예시/포맷/스키마. ≤120줄
- Skill/Agent: Quick Reference ≤5줄, 기존 패턴 참조

## Agent Boundaries (Claude Code Specific)
### Never
- `--dangerously-skip-permissions` 사용 금지
