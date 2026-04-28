---
title: "Skill (HXSK context)"
tags: [glossary, hxsk, skill]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Skill"
context: "hxsk"
aliases:
  - 스킬
  - 역량
  - capability
disambiguates_from: []
definition: ".hxsk/skills/{name}/SKILL.md에 정의된 How 레이어 모듈. 구체적인 실행 방법(절차·규칙·검증)을 담는다."
examples:
  - "'역량 추가해줘' → .hxsk/skills/ 에 새 Skill 작성"
  - "'define-term 스킬 호출' → .hxsk/skills/define-term/SKILL.md 실행"
sources:
  - ".hxsk/CLAUDE.md"
  - ".hxsk/skills/INDEX.md"
learned: false
contextual_description: "HXSK How 레이어 — 에이전트가 사용하는 방법론 모듈"
keywords: [skill, how, procedure, hxsk, module]
---

## Skill (HXSK)

HXSK Skill은 `.hxsk/skills/{name}/SKILL.md` 파일로 정의된다.
**Skill(How) + Agent(When/With What)** 분리 원칙에서 Skill은 실행 절차와 규칙을 담당한다.

사용자가 "역량", "capability"라고 말하면 HXSK Skill을 지칭하는 것으로 해석한다.
