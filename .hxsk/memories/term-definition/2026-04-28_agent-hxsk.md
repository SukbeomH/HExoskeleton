---
title: "Agent (HXSK context)"
tags: [glossary, hxsk, agent]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Agent"
context: "hxsk"
aliases:
  - 에이전트
  - agent
disambiguates_from:
  - canonical: "Agent"
    context: "anthropic-sdk"
  - canonical: "agent"
    context: "general-ai"
definition: ".hxsk/agents/{name}.md에 정의된 When/With-What 레이어 래퍼. Skill(How)을 언제, 무엇으로 사용할지를 결정한다."
examples:
  - "'PR 리뷰 에이전트 실행해줘' → Agent(pr-review)"
  - "'에이전트 추가해줘' → .hxsk/agents/ 에 새 파일 작성"
sources:
  - ".hxsk/CLAUDE.md"
  - ".hxsk/skills/INDEX.md"
learned: false
contextual_description: "HXSK When/With-What 레이어 — Skill을 호출하는 오케스트레이터"
keywords: [agent, when, with-what, wrapper, hxsk, orchestrator]
---

## Agent (HXSK)

HXSK Agent는 `.hxsk/agents/{name}.md` 파일로 정의된다.
**Skill(How) + Agent(When/With What)** 분리 원칙에서 Agent는 트리거 조건과 컨텍스트를 담당한다.

`anthropic-sdk`의 `Agent`(Managed Agent API)나 일반 AI 에이전트 개념과 구별된다.
