# Phase 1 수동 감사 결과

> 2026-04-09 | 병렬 에이전트 3개로 수행

## 카운트 불일치

| 항목 | README.md | ARCHITECTURE.md | 실제 |
|------|-----------|-----------------|------|
| Skills | 20 (배지) / 19 (상세) | 19 | **20** |
| Agents | 18 (배지) / 17 (상세) | 17 | **18** |
| Hooks | — | 17 | **25** |
| Templates | 32 | 27 | **32** |
| Docs | 23 | 11+ | **14** |
| Research | 33 | — | **34** |

## INDEX 누락

| INDEX 파일 | 누락 항목 수 |
|------------|-------------|
| skills/INDEX.md | 11개 미등록 |
| agents/INDEX.md | 9개 미등록 |
| hooks/INDEX.md | 5개 미등록 |
| research/INDEX.md | 정상 |

## L1 문서 불일치 (CLAUDE.md + AGENTS.md)

- AGENTS.md:21 — "SPEC.md → PLAN.md" 워크플로우 설명이지만 활성 PLAN.md 없음 (템플릿만 존재)
- CLAUDE.md:24 — `.hxsk/.track-modifications.log` 참조하지만 실제 파일 없음 (flag 기반 시스템 사용)
- hooks/INDEX.md — "19 hook scripts" 주장하지만 실제 24-25개

## 깨진 상대 링크 (20건)

설계 문서, 리서치 문서에 집중. doc-lint.sh LINK-01 규칙으로 정확한 목록 추출 예정.

## 고아 파일 (3건)

INDEX에서 참조되지 않는 스킬 하위 문서:
- debugger/root-cause-tracing.md
- empirical-validation/rationalization-update-guide.md
- empirical-validation/anti-patterns.md
