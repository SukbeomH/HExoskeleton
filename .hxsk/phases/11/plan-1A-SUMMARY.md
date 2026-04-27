# Plan 11.1A SUMMARY — 공유 인프라 (스키마 + HITL 어댑터)

**Status**: COMPLETED
**Date**: 2026-04-28
**Commits**: 2 (`67bdbaa`, `569461b`)

## Tasks

| Task | 산출물 | 결과 |
|---|---|---|
| 1. 스키마 3종 | term-definition.schema.json, base.schema.json(provenance+enum 16개), type-relations.yaml v1.1 | ✅ |
| 2. HITL 어댑터 | _detect.sh, claude-code.sh, opencode.sh, antigravity.sh, hitl-ask.sh | ✅ |

## Deviations

- **Rule 2 (자동 추가)**: base.schema.json enum에 `lessons-learned` + `term-definition` 추가. 기존 enum이 14개로 lessons-learned를 누락하고 있어 16개로 정합화. 하위 호환 유지 (additionalProperties: true).

## Invariants Established

- HITL 어댑터 규약: exit 0=응답, 1=skip, 2=timeout
- term-definition: canonical+context 고유 키
- claude-code 어댑터: .hxsk/.hitl-pending.json (gitignore)

## Wave 2 진입 조건

✅ 스키마 인프라 준비 완료 → plan-2A, plan-2B 병렬 실행 가능
