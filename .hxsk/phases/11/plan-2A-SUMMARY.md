# Plan 11.2A SUMMARY — ADR-006 조작적 정의

**Status**: COMPLETED
**Date**: 2026-04-28
**Commits**: 2 (시드+rebuild, detect+skill)

## Tasks

| Task | 산출물 | 결과 |
|---|---|---|
| 1. 시드 + GLOSSARY | term-definition/ 10개, glossary-rebuild.sh, GLOSSARY.md | ✅ |
| 2. detect 훅 + Skill | glossary-detect.sh, define-term/SKILL.md | ✅ |

## Deviations

- **Rule 1 (×3)**: glossary-detect.sh 버그 3건 자동 수정
  - SCRIPT_DIR/../ 경로 오류 → git rev-parse --show-toplevel
  - aliases 추출 혼입 (disambiguates_from, examples) → awk frontmatter 파싱
  - TSV count 누적 실패 (grep -P 한계) → awk exact match 교체

## Verification Results

```
역량 추가해줘 Skill 등록 Agent 입력 시:
  💡 'Agent' → HXSK Agent (context: hxsk)
  💡 'Skill' → HXSK Skill (context: hxsk)
  💡 '역량' → HXSK Skill (context: hxsk)

리텐션 3회 누적 시:
  📝 '리텐션' 3회 감지. `/define 리텐션` 으로 등록을 권장합니다.
```

## Invariants Established (new)

- GLOSSARY.md는 자동 생성 파일 — glossary-rebuild.sh로만 갱신
- .glossary-candidates.tsv / .glossary-pending.tsv gitignore 대상
- 자동 학습: aliases 추가만 허용

## Status

✅ Plan 2A 완료 — plan-2B 병렬 실행 가능 (공유 파일 없음)
