---
title: "Session (HXSK context)"
tags: [glossary, hxsk, session]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Session"
context: "hxsk"
aliases:
  - 세션
  - 대화세션
disambiguates_from:
  - canonical: "session"
    context: "http"
definition: "Claude Code와의 단일 대화 단위. SessionStart 훅으로 시작, Stop 훅으로 종료. .hxsk/CURRENT.md에 현재 세션 컨텍스트가 기록된다."
examples:
  - "'세션 종료' → /handoff 스킬 실행"
  - "'이번 세션' → CURRENT.md의 Session Narrative 참조"
sources:
  - ".hxsk/CLAUDE.md"
  - ".hxsk/CURRENT.md"
learned: false
contextual_description: "HXSK Claude Code 대화 단위 — SessionStart/Stop 훅, CURRENT.md 추적"
keywords: [session, hxsk, claude-code, current, lifecycle]
---

## Session (HXSK)

HXSK Session은 Claude Code와의 단일 대화다.
HTTP 세션이나 사용자 로그인 세션과 구별된다.
`.hxsk/CURRENT.md`로 추적되고 `/handoff`로 인계된다.
