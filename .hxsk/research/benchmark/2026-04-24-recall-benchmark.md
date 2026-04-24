---
date: 2026-04-24
type: benchmark
subject: md-recall-memory.sh hop=1 vs hop=2 레이턴시·정확도 비교
---

# md-recall-memory.sh 2-hop 벤치마크

## Summary

- **실행 날짜**: 2026-04-24
- **대상 스크립트**: `.hxsk/hooks/md-recall-memory.sh`
- **총 쿼리 수**: 5개, 각 hop=1 / hop=2 측정 (총 10회 실행)
- **Avg latency hop=1**: 342 ms
- **Avg latency hop=2**: 459 ms
- **레이턴시 Overhead**: +34% (hop=2 기준)
- **2-hop 추가 컨텍스트 제공 여부**: 현재 메모리 기반에서 related 링크 없음 → hop=2 실질 이득 없음

## Results Table

| query | hop | latency_ms | top1_file |
|-------|-----|-----------|-----------|
| gate-check | 1 | 310 | Session [2026-04-24 12:31:13]: chore/patterns-compress |
| gate-check | 2 | 480 | Session [2026-04-24 12:31:13]: chore/patterns-compress |
| CSO | 1 | 352 | Session [2026-04-24 11:53:13]: master |
| CSO | 2 | 378 | Session [2026-04-24 11:53:13]: master |
| memory-system | 1 | 158 | ADR: 메모리 2-tier 분리 (local-only / shared) |
| memory-system | 2 | 186 | ADR: 메모리 2-tier 분리 (local-only / shared) |
| pattern-discovery | 1 | 463 | 빌드 스크립트에서 단순 cp 대신 sed 변환 파이프라인 패턴 |
| pattern-discovery | 2 | 716 | 빌드 스크립트에서 단순 cp 대신 sed 변환 파이프라인 패턴 |
| execution | 1 | 430 | Plan Phase-7 Summary |
| execution | 2 | 537 | Plan Phase-7 Summary |

**hop=1 평균**: 342 ms  
**hop=2 평균**: 459 ms  
**오버헤드**: +117 ms (+34%)

## Accuracy

각 쿼리에서 top-1 결과가 기대 토픽과 관련 있는지 판정:

| query | 기대 토픽 | top-1 결과 | 관련성 |
|-------|-----------|-----------|--------|
| gate-check | gate-check.sh / GATES.md | Session handoff (gate-check 언급 포함) | yes |
| CSO | CSO 스킬 최적화 Phase10/11 | Session summary (CSO 최적화 세션) | yes |
| memory-system | 메모리 2-tier ADR | ADR: 메모리 2-tier 분리 | yes |
| pattern-discovery | 패턴 발견 메모리 | cp/sed 파이프라인 패턴 | yes |
| execution | 실행 요약 | Plan Phase-7 Summary | yes |

hop=1 정확도: **5/5 (100%)**  
hop=2 정확도: **5/5 (100%)** — top-1 결과가 hop=1과 동일 (related 파일 없음)

## Findings

1. **hop=2는 현재 메모리 기반에서 추가 이득이 없다.**  
   모든 메모리 파일에 `related:` frontmatter 필드가 없거나 빈 상태이므로, 2차 hop에서 추가 파일이 로드되지 않는다. top-1 결과가 hop=1과 100% 동일.

2. **레이턴시 오버헤드는 +34% (평균 +117 ms).**  
   hop=2도 related 파일 추적 로직을 실행하므로 일정 비용이 발생한다. 실질 이득 없이 I/O 오버헤드만 소모.

3. **쿼리별 편차가 크다 (158 ms ~ 716 ms).**  
   메모리 파일 수 (41개)가 적으나, grep + sort + awk 파이프라인 비용이 쿼리마다 다르게 나타남. 파일 수 증가 시 선형 증가 예상.

4. **top-1 정확도는 모든 쿼리에서 100%.**  
   직접 키워드 grep 방식이 현재 메모리 규모에서는 충분히 정확.

## Recommendation

- **단기 (현재 메모리 41개)**: `hop=1`을 기본값으로 사용. hop=2 대비 34% 빠르고 정확도 동일.
- **장기 (메모리 확장 시)**: 메모리 파일에 `related:` 필드를 적극 채울 때만 hop=2 활성화. related 링크가 존재하는 환경에서는 2-hop이 맥락 보강 효과 제공 가능.
- **임계값 제안**: 메모리 파일 중 30% 이상에 `related:` 필드가 있을 때 hop=2를 기본값으로 전환.
- **스크립트 권장 호출**: `md-recall-memory.sh <query> "." 5 compact 1` (hop=1 명시)
