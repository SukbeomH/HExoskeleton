# 하이브리드 검색: Model2Vec + sqlite-vec + FTS5 + RRF

> **조사일**: 2026-03-04
> **출처**: Alex Garcia, Simon Willison, liamca/sqlite-hybrid-search
> **키워드**: hybrid-search, FTS5, BM25, sqlite-vec, RRF, Model2Vec, 증분인덱싱

---

## 아키텍처 개요

BM25(키워드 매칭)와 벡터 검색(의미 기반 매칭)을 Reciprocal Rank Fusion(RRF)으로 결합하는 하이브리드 검색 아키텍처.

```
┌─────────────┐     ┌──────────────┐
│  FTS5/BM25  │     │ sqlite-vec   │
│  키워드 검색 │     │ 벡터 검색    │
│  (정확 매칭) │     │ (의미 매칭)  │
└──────┬──────┘     └──────┬───────┘
       │                    │
       ▼                    ▼
  ┌─────────────────────────────┐
  │    Reciprocal Rank Fusion   │
  │  score = 1/(k+rank_fts)    │
  │        + 1/(k+rank_vec)    │
  └──────────┬──────────────────┘
             ▼
       통합 순위 결과
```

## 핵심 기술 스택

| 컴포넌트 | 역할 | 특성 |
|----------|------|------|
| **Model2Vec** (potion-base-8M) | 256차원 임베딩 생성 | 경량, 빠름 |
| **sqlite-vec** | 벡터 유사도 검색 | SQLite 확장, 외부 DB 불필요 |
| **FTS5** | BM25 기반 전문 검색 | Porter Stemming, SQLite 내장 |
| **RRF** | 두 결과 리스트 융합 | k=60 표준, 교차 매칭 우선 |

## RRF 공식

```
combined_score(doc) = w_fts * 1/(k + rank_fts) + w_vec * 1/(k + rank_vec)
```

- `k`: 상수 (일반적으로 60). 상위 순위 결과에 가중치 부여 정도 조절
- 양쪽에 모두 등장하는 문서가 자연스럽게 높은 점수

## 증분 인덱싱

```bash
# 전체 15,800파일 재인덱싱: ~4분
# 일일 증분 (변경분만): ~10초
indexer --incremental  # 컨텐츠 해시로 변경된 청크만 재임베딩
```

- 컨텐츠 해시 기반 변경 감지
- 변경된 청크만 재임베딩 → 일상 업데이트 10초 미만

## 구조화 데이터 처리 문제

BM25는 JSON/테이블/설정 등 구조화 데이터에서 성능이 떨어짐:
- "review configuration" 검색 → `review` 키를 가진 모든 JSON 파일 매칭
- **해결**: key-path와 value를 분리 청킹하여 오탐 방지

## 캐싱 장점

동일 쿼리에 대해 압축된 출력이 **결정적(deterministic)** → 프롬프트 캐시가 안정적으로 작동. 비결정적 출력은 캐시를 깨뜨림.

## 3가지 하이브리드 전략 (Alex Garcia)

| 전략 | 방식 | 적합 사용처 |
|------|------|------------|
| **키워드 우선** | FTS5 먼저 → 벡터로 보충 | 이메일 검색, 정확 매칭 우선 |
| **RRF** | 양쪽 결과를 순위 융합 | RAG 문서 검색 (이름+의미 모두 중요) |
| **의미론 재정렬** | FTS5 필터 → 코사인 정렬 | 중복 감지, 유사도 기반 |

---

## 출처

- [Alex Garcia — Hybrid full-text search and vector search with SQLite](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html)
- [Simon Willison — Hybrid search with SQLite](https://simonwillison.net/2024/Oct/4/hybrid-full-text-search-and-vector-search-with-sqlite/)
- [liamca/sqlite-hybrid-search](https://github.com/liamca/sqlite-hybrid-search)
- [OpenSearch — Introducing RRF for Hybrid Search](https://opensearch.org/blog/introducing-reciprocal-rank-fusion-hybrid-search/)

*Last updated: 2026-03-04*
