---
title: "Antigravity 빌드 스크립트 v2 재설계 완료"
tags:
  - build
  - antigravity
  - refactor
  - bash-only
type: execution-summary
created: 2026-02-19T08:03:33Z
contextual_description: "Antigravity 빌드 스크립트를 순수 bash로 재설계하여 비표준 프론트매터, Claude-specific 참조, Python 의존성을 모두 제거"
keywords:
  - antigravity
  - build-script
  - sanitize
  - transform
---

## Antigravity 빌드 스크립트 v2 재설계 완료

build-antigravity.sh 전체 재작성 (843→730줄). 핵심 변경: (1) sanitize_frontmatter() — version/trigger/allowed-tools/model 제거, (2) transform_tool_refs() — <role> 태그 제거 + Grep/Glob/Read → search/find_files/read_file 치환 (코드블록 보존), (3) Workflows를 Agent 파일 본문에서 직접 추출 (Python TOC 제거), (4) Rules를 CLAUDE.md에서 extract_section()으로 동적 추출 (4개), (5) GEMINI.md 신규 생성, (6) 스크립트 4개만 선별 복사, (7) split_large_skill() — 500줄 초과 분할. python3 의존성 완전 제거.
