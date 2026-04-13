---
title: "build-opencode.sh Phase 7: AGENTS.md 변환 로직 추가"
tags:
  - build
  - opencode
  - migration
  - sed
  - AGENTS.md
type: root-cause
created: 2026-02-24T05:01:36Z
contextual_description: "build-opencode.sh Phase 7에서 CLAUDE.md → AGENTS.md 변환 시 sed 파이프라인 미적용으로 Claude Code 잔재가 남는 버그 수정"
keywords:
  - build-opencode sed transformation AGENTS.md Claude Code migration
---

## build-opencode.sh Phase 7: AGENTS.md 변환 로직 추가

build-opencode.sh의 Phase 7이 CLAUDE.md를 단순 cp로 복사하여 Claude Code 잔재가 그대로 남는 문제를 발견. sed 파이프라인 15개 규칙으로 교체:
- CLAUDE.md → AGENTS.md (헤더 및 전체 참조)
- Claude Code (claude.ai/code) / Claude Code → OpenCode
- .claude/skills/ → .opencode/skill/ (단수형 주의)
- .claude/agents/ → .opencode/agents/
- .claude/ → .opencode/ (나머지)
- skills/ → skill/ (디렉토리 명칭 단수형)
- hooks/ → plugins/ (TypeScript 플러그인)
- settings.json → opencode.json
- (Grep, Glob, Read) → (grep, find, cat)
- Grep/Glob → grep/find
- Grep()/Glob() 함수형 호출 → bash 명령어로 변환
빌드 검증: 14 agents, 16 skills, 16 commands, JSON 유효성 통과 (BUILD SUCCESSFUL)
