---
title: "Memory (HXSK context)"
tags: [glossary, hxsk, memory]
type: term-definition
created: 2026-04-28T00:00:00Z
canonical: "Memory"
context: "hxsk"
aliases:
  - 메모리
  - 기억
  - memories
disambiguates_from:
  - canonical: "Memory"
    context: "hardware"
  - canonical: "memory"
    context: "general"
definition: ".hxsk/memories/ 하위 16개 타입의 .md 파일 시스템. A-Mem 기반 2-hop 그래프 검색을 지원한다."
examples:
  - "'메모리 저장해줘' → md-store-memory.sh 호출"
  - "'메모리 검색' → md-recall-memory.sh <query>"
sources:
  - ".hxsk/AGENTS.md"
  - ".hxsk/hooks/md-recall-memory.sh"
learned: false
contextual_description: "HXSK 파일 기반 메모리 — .hxsk/memories/ 16타입, A-Mem 2-hop 검색"
keywords: [memory, hxsk, a-mem, recall, store, file-based]
---

## Memory (HXSK)

HXSK Memory는 `.hxsk/memories/` 디렉토리의 타입별 .md 파일이다.
RAM이나 일반적인 "기억" 개념과 달리 16개 타입으로 분류되고 2-hop 그래프 검색을 지원한다.
