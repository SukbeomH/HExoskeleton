---
title: ".gsd → .hxsk 디렉토리 rename 아키텍처 결정"
tags:
  - architecture
  - rename
  - hxsk
  - directory
type: architecture-decision
created: 2026-02-23T02:36:09Z
contextual_description: ".gsd/ → .hxsk/ 전면 rename. HExoskeleton 브랜딩 통일. PR #40으로 master 반영."
keywords:
  - hxsk
  - gsd
  - rename
  - directory
  - branding
  - PR40
related:
  - 2026-02-20_hexoskeleton-gsd-boilerplate
---

## .gsd → .hxsk 디렉토리 rename 아키텍처 결정

HExoskeleton 브랜딩 통일을 위해 작업 디렉토리를 .gsd/ → .hxsk/로 전면 rename.

결정 배경:
- 프로젝트명이 GSD Boilerplate → HExoskeleton으로 변경됨 (PR #38)
- .gsd 접두어가 구버전 브랜딩(GSD)과 연결되어 일관성 저하
- hxsk-plugin, HExoskeleton 네이밍과 통일

변경 범위 (PR #40, 80 files, 33 renames):
- 디렉토리: .gsd/ → .hxsk/ (templates/, examples/, STATE.md, PATTERNS.md)
- 훅: .claude/hooks/*.sh/.py 경로 참조 갱신
- 스킬: .claude/skills/*/SKILL.md 경로 참조 갱신
- 에이전트: .claude/agents/*.md 경로 참조 갱신
- 스크립트: scripts/*.sh 빌드/유틸리티 경로 갱신
- 설정: .gitignore, .claude/settings.json, CLAUDE.md, docs/*.md

보존한 것:
- CHANGELOG.md 커밋 메시지 역사 기록
- hxsk-plugin/, antigravity-boilerplate/ 빌드 아티팩트
- .hxsk/memories/ 런타임 데이터(역사 기록)
- scripts/md-*.sh → .claude/hooks/ 심볼릭 링크 (영향 없음)

실행 방법: bulk sed (find + sed -i '') → gitignore/settings 별도 처리 → mv .gsd .hxsk → git add/rm → commit
