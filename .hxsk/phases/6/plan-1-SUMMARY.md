---
phase: 6
plan: 1
completed_at: 2026-04-21T07:41:48Z
duration_minutes: 45
commit: 982cfda030517a1125c1016c3ce8c21b183dbc56
---

# Summary: Plan 6.1 — HXSK 신뢰성 수정

## Results

- 4 tasks completed (setup.md / md-store-memory.sh / md-recall-memory.sh / prune-tick.sh)
- 11 known issues → 0 (verify: `bash .hxsk/scripts/check-reliability.sh`)
- 보너스: doc-lint.sh ORPHAN/DUP 예외 등록 (E22 시나리오 이슈 해소)
- All verifications passed

## Source Analysis

- **scenario/260421-1553-hxsk-setup-e2e**: 25 iterations, score=900, Critical×3 + High×11
- **predict/260421-1600-hxsk-reliability**: 5 personas × 2 rounds, score=219, Confirmed×11

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | setup.md CORRUPTED 분기 + U6 명시적 스테이징 | 982cfda | ✅ |
| 2 | md-store-memory.sh TYPE_DIR + set -e + PROJ 검증 | 982cfda | ✅ |
| 3 | md-recall-memory.sh [NO_MATCH] + head 변수화 + set -e + PROJ 검증 | 982cfda | ✅ |
| 4 | prune-tick.sh stale lock + PROJ 검증 | 982cfda | ✅ |

## Deviations Applied

- **[Rule 1 - Bug]** `head "$RECALL_MAX"` → `head -"$RECALL_MAX"` (macOS `head` 구문 오류 수정 — 파일명으로 인식)
- **[Rule 2 - Missing Critical]** `doc-lint.sh` ORPHAN/DUP 수정: `scenario/` `predict/` `.hxsk/docs/` 제외 + autoresearch 세션 파일 DUP 예외 등록 (commit 실패로 발견, E22 이슈)

## Files Changed

| 파일 | 변경 내용 |
|------|----------|
| `.hxsk/prompts/setup.md` | Step 0 CORRUPTED 분기 + U6 명시적 스테이징 [C1, C3] |
| `.hxsk/hooks/md-store-memory.sh` | TYPE_DIR mkdir-p, set -euo, .hxsk/ 검증 [RE-1, RE-3a, DA-3] |
| `.hxsk/hooks/md-recall-memory.sh` | [NO_MATCH], HXSK_RECALL_MAX, set -euo, .hxsk/ 검증 [DA-4, RE-6, RE-3b, DA-3] |
| `.hxsk/scripts/prune-tick.sh` | stale lock 300s 감지, .hxsk/ 검증 [SA-8, DA-3] |
| `.hxsk/scripts/doc-lint.sh` | ORPHAN/DUP 예외 확장 [E22] |
| `.hxsk/scripts/check-reliability.sh` | 11개 패턴 검증 스크립트 (신규) |
| `.hxsk/docs/PLAN-reliability-fixes.md` | Plan 6.1 계획 문서 (신규) |
| `predict/260421-1600-hxsk-reliability/` | predict 세션 출력 (신규, 9파일) |
| `scenario/260421-1553-hxsk-setup-e2e/` | scenario 세션 출력 (신규, 5파일) |

## Verification

| 항목 | 결과 |
|------|------|
| `bash .hxsk/scripts/check-reliability.sh` (ISSUE COUNT) | ✅ 0 |
| `bash .hxsk/hooks/md-store-memory.sh` (신규 타입 생성) | ✅ OK |
| `bash .hxsk/hooks/md-recall-memory.sh "memory" "." 3 compact` | ✅ 결과 반환 |
| `bash .hxsk/hooks/md-recall-memory.sh "zzz-nonexistent"` → [NO_MATCH] | ✅ OK |
| `bash .hxsk/scripts/prune-tick.sh` | ✅ exit 0 |
| `bash .hxsk/scripts/doc-lint.sh` | ✅ PASS 7, FAIL 0 |

## Cross-Phase Invariants (신규)

이 플랜에서 추가된 불변 조건:

1. `md-store-memory.sh TYPE_DIR`는 항상 요청된 타입으로 생성된다 (general 리다이렉트 없음)
2. `md-recall-memory.sh`는 쿼리 미매칭 시 `[NO_MATCH]`를 stderr에 출력한다
3. `prune-tick.sh`는 SIGKILL 이후 300s stale lock을 자동 해제한다
4. `setup.md Step 0`은 `.bootstrap-version` 손상 시 CORRUPTED 분기로 진입한다
5. `setup.md U6`는 프레임워크 파일만 명시적 스테이징한다 (git add -A 금지)

## Remaining Work (P1/P2 — 후속 플랜)

scenario P1 미수정 항목:
- H1: bootstrap.sh FAIL 메시지에 setup.md 참조 추가
- H2: setup.md 완료 체크리스트 검증 명령 추가
- H3: planner SKILL.md `{placeholder}` 경고

predict P2 미수정 항목:
- RE-5: YAML 인젝션 (TITLE 값 sanitization)
- SA-2/SE-2: prune-memories.sh config source 안전화
- SA-7: stop-context-save.sh 플래그 삭제 경쟁 조건
