# Plan 11.3A SUMMARY — PR #160 리뷰 해소

**Status**: COMPLETED
**Date**: 2026-04-28
**Commits**: PR #162 + PR #163

## Tasks

| Task | 산출물 | 결과 |
|---|---|---|
| 1. 보안·버그 수정 | claude-code.sh JSON escaping, hitl-ask.sh PROJECT_DIR export, md-store-memory EXIST_COUNT, glossary-detect UTF-8 locale | ✅ |
| 2. 문서·Nitpick 수정 | SPEC.md 메모리 타입 수 16개 반영, _detect.sh CLAUDE_CODE 비공식 env 주석 | ✅ |

## Review Items Resolved

- **High**: claude-code.sh HITL pending JSON 인젝션 위험 해소 (`json_safe()`)
- **Medium**: md-store-memory.sh contradiction check EXIST_COUNT 패턴을 compact 출력(`^- **`)에 맞춤
- **Medium**: glossary-detect.sh 한글 정규식 처리를 위해 UTF-8 locale 설정
- **Medium**: SPEC.md 메모리 타입 수 14개 → 16개 갱신
- **Nitpick**: hitl-ask.sh에서 HXSK_PROJECT_DIR export
- **Nitpick**: _detect.sh의 CLAUDE_CODE 비표준 env var 주석 추가

## Verification Results

```
# PR #162
JSON safe 검증: quote 포함 QUESTION으로 .hitl-pending.json 생성 후 json.load 통과
grep "EXIST_COUNT" .hxsk/hooks/md-store-memory.sh → "^- \*\*" 패턴 확인
grep "LC_ALL" .hxsk/hooks/glossary-detect.sh → match
grep "HXSK_PROJECT_DIR" .hxsk/scripts/hitl-ask.sh → match
doc-lint PASS 7/7

# PR #163
grep "16개" .hxsk/SPEC.md → 2 matches
grep "NOTE.*CLAUDE_CODE" .hxsk/adapters/hitl/_detect.sh → match
```

## Status

✅ Plan 3A 완료 — PR #160 리뷰 잔여 수정이 master에 반영됨.
GitHub issue #161은 모든 요구사항이 해결되어 close 가능.
