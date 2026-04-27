---
title: "Phase (HXSK context)"
tags: [glossary, hxsk, phase]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Phase"
context: "hxsk"
aliases:
  - 페이즈
  - 단계
  - 실행단계
disambiguates_from:
  - canonical: "phase"
    context: "general"
definition: ".hxsk/phases/{N}/ 디렉토리. Plan들의 묶음 단위. Wave 구조로 병렬 실행을 지원한다."
examples:
  - "Phase 11 = .hxsk/phases/11/ (plan-1A, plan-2A, plan-2B)"
  - "'이번 페이즈 진행' → 현재 phases/N/ 내 plan들 순차/병렬 실행"
sources:
  - ".hxsk/AGENTS.md"
  - ".hxsk/skills/planner/SKILL.md"
learned: false
contextual_description: "HXSK 실행 단계 — phases/{N}/ 디렉토리, Wave 병렬 구조"
keywords: [phase, hxsk, wave, parallel, execution]
---

## Phase (HXSK)

HXSK Phase는 `.hxsk/phases/{N}/` 디렉토리로 관리된다.
일반적인 "단계(phase)" 개념과 달리 Wave 1→2 구조로 병렬 실행을 지원한다.
