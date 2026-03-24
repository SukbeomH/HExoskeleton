# GEMINI.md

This file provides guidance to Gemini CLI agents working with this repository.

See AGENTS.md for shared project instructions.

## Gemini CLI Specific

- **Skills**: `.hxsk/skills/{name}/SKILL.md` → `.agent/skills/{name}/SKILL.md`로 배치
- **Rules**: AGENTS.md의 Agent Boundaries 섹션 참조
- **Hooks**: Gemini CLI는 event hooks를 지원하지 않음. AGENTS.md 규칙으로 대체
- **Memory**: `bash .hxsk/hooks/md-store-memory.sh`, `bash .hxsk/hooks/md-recall-memory.sh` 사용
