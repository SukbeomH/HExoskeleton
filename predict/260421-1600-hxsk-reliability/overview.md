# HXSK Reliability Predict — Executive Overview

**Session**: 260421-1600-hxsk-reliability  
**Scope**: `.hxsk/scripts/` + `.hxsk/hooks/`  
**Goal**: 신뢰성 + 실패 모드 분석  
**Depth**: Standard (5 personas, 2 rounds)  
**Date**: 2026-04-21  
**predict_score**: 219

---

## Anti-Herd Status: PASSED

| Signal | Value | Threshold | Status |
|--------|-------|-----------|--------|
| flip_rate | 0.25 | > 0.15 | ✓ OK |
| entropy | 0.78 | > 0.60 | ✓ OK |
| convergence_speed | round 2 | ≥ round 2 | ✓ OK |

Devil's Advocate(DA) 페르소나가 4개 이상 다수결 포지션 도전 성공. `SA-1(.env auto-copy)`, `SA-2(prune-config source)`, `RE-8/PE-8(Python hook refs)` 심각도 하향 조정.

---

## Consensus Summary

| 레벨 | 건수 | 비고 |
|------|------|------|
| Confirmed (≥3/5) | 11 | 즉시 조치 대상 |
| Probable (2/5) | 2 | 조건부 위험 |
| Minority (1/5) | 1 | 관찰 유지 |

---

## Top 5 Priority Findings

| Rank | ID | Severity | Score | Issue |
|------|----|----------|-------|-------|
| 1 | DA-3 | HIGH | 0.88 | `CLAUDE_PROJECT_DIR` 미검증 — 잘못된 env var로 모든 훅 무성 실패 |
| 2 | RE-1 | HIGH | 0.85 | TYPE_DIR 없을 때 "general"로 조용한 리다이렉트 |
| 3 | DA-4 | HIGH | 0.82 | recall fallback이 무관 파일 반환, [NO_MATCH] 없음 |
| 4 | SA-8/RE-4 | MEDIUM | 0.71 | SIGKILL → stale lock → prune 영구 차단 |
| 5 | RE-6/PE-6 | MEDIUM | 0.68 | `head -100` 하드 캡 → 오래된 메모리 검색 불가 |

---

## Score Breakdown

```
11 Confirmed  × 15 = 165
 2 Probable   ×  8 =  16
 1 Minority   ×  3 =   3
Anti-herd pass      =  20  (5/5 personas independent)
2-round debate      =  10  (2/2 rounds completed)
Bonus (DA flips)    =   5
─────────────────────────
Total               = 219
```

---

## Systemic Risk Clusters

### Cluster 1: 환경 변수 의존성 (DA-3)
모든 핵심 스크립트가 `${CLAUDE_PROJECT_DIR:-.}` 폴백에 의존. `.`이 실제 프로젝트 루트가 아닐 경우 전체 메모리 시스템 무성 오작동.

### Cluster 2: 메모리 저장/검색 정확성 (RE-1, RE-2, DA-4, RE-5, RE-6)
타입 미스매치 저장 → 잘못된 recall 결과 → 에이전트 의사결정 오염. 단일 버그 아닌 파이프라인 전체 신뢰성 문제.

### Cluster 3: 장기 실행 안정성 (SA-8/RE-4, RE-3)
SIGKILL stale lock + `set -uo pipefail`(missing `-e`) 조합 → 장시간 사용 환경에서 Silent accumulation.

---

## Recommended Action Order

1. **Immediate** (데이터 정합성): RE-1 TYPE_DIR 수정, DA-4 fallback 표시 추가
2. **This week** (환경 안전성): DA-3 CLAUDE_PROJECT_DIR 검증, SA-8/RE-4 stale lock
3. **Next sprint** (누락 개선): RE-6 head 캡 확장, RE-3 missing `-e`, RE-5 YAML 인젝션
