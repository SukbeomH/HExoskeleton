---
title: "Handoff (HXSK context)"
tags: [glossary, hxsk, handoff]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Handoff"
context: "hxsk"
aliases:
  - 핸드오프
  - 세션인계
  - 인수인계
disambiguates_from: []
definition: "세션 종료 시 /handoff 스킬로 수행하는 표준 인계 절차. 테스트→커밋→메모리저장→SESSION_HANDOFF.md 작성 순서로 진행된다."
examples:
  - "'핸드오프 해줘' → /handoff 스킬 실행"
  - "'세션 인계' → 동일"
sources:
  - ".hxsk/skills/handoff/SKILL.md"
  - ".hxsk/SESSION_HANDOFF.md"
learned: false
contextual_description: "HXSK 세션 종료 표준 절차 — /handoff 스킬, 커밋+메모리+HANDOFF.md"
keywords: [handoff, session, hxsk, transfer, summary]
---

## Handoff (HXSK)

HXSK Handoff는 세션 종료 시 다음 세션을 위해 컨텍스트를 전달하는 표준 절차다.
`/handoff` 스킬로 실행하며, `session-handoff` 메모리 타입에 저장된다.
