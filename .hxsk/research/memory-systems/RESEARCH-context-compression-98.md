# Context Mode: 컨텍스트 압축 98%

> **조사일**: 2026-03-04
> **출처**: mksglu/claude-context-mode, HN 토론
> **키워드**: context-compression, context-window, token-saving, FTS5, PostToolUse, progressive-throttling

---

## 문제 정의

Claude Code의 200K 컨텍스트 윈도우에서:
- 81+ 도구 정의만으로 143K 토큰(72%) 소비
- 추가 도구 출력이 잔여 컨텍스트를 급속히 소진
- 세션 30분 만에 성능 저하 시작

## Context Mode 아키텍처

```
도구 호출 → 샌드박스에서 실행 → 결과 압축 → 요약만 컨텍스트에 진입
                                         │
                                   상세 데이터는
                                   FTS5 인덱스에 저장
                                   (필요 시 search로 접근)
```

## 압축 성능

| 원본 | 크기 | 압축 후 | 절감 |
|------|------|---------|------|
| Playwright 스냅샷 | 56.2 KB | 299 B | **99%** |
| GitHub Issues (20개) | 58.9 KB | 1.1 KB | **98%** |
| 액세스 로그 (500건) | 45.1 KB | 155 B | **99.7%** |
| Git 로그 (153 커밋) | 11.6 KB | 107 B | **99%** |
| **전체 세션** | **315 KB** | **5.4 KB** | **98%** |

세션 지속시간: ~30분 → **~3시간**으로 연장.

## 검색 시스템 (3계층 폴백)

| 레이어 | 방식 | 용도 |
|--------|------|------|
| L1 | Porter Stemming (FTS5 MATCH) | 표준 형태소 매칭 |
| L2 | Trigram 부분문자열 | "useEff" → "useEffect" |
| L3 | Levenshtein 퍼지 교정 | 오타 교정 |

## Progressive Search Throttling

| 호출 횟수 | 동작 |
|----------|------|
| 1-3 | 정상 (쿼리당 2개 결과) |
| 4-8 | 축소 (쿼리당 1개) + 경고 |
| 9+ | 차단 → `batch_execute`로 리다이렉트 |

## PostToolUse Hook 통합 아이디어

> "같은 검색기를 PostToolUse 훅으로 실행해 출력이 대화에 들어가기 전에 압축"

```
PostToolUse Hook → 도구 출력 가로채기 → FTS5 인덱싱 + 압축 → 요약만 반환
```

## 한계점 (HN 토론)

1. **MCP 도구 응답 가로채기 불가**: 서드파티 MCP 도구 출력은 컨텍스트로 직접 진입
2. **프롬프트 캐시 훼손 리스크**: 압축이 캐시 연속성을 깨뜨리면 오히려 비용 증가 가능
3. **정보 손실**: 요약 시 누락된 세부사항을 모델이 사후에 필요로 할 수 있음

---

## 출처

- [mksglu/claude-context-mode](https://github.com/mksglu/claude-context-mode)
- [HN — Context Mode MCP Server](https://news.ycombinator.com/item?id=47193064)

*Last updated: 2026-03-04*
