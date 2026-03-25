# HXSK 적용 가능성 종합 분석: 하이브리드 검색, 컨텍스트 압축, 코드 엔트로피

> **조사일**: 2026-03-04
> **키워드**: HXSK, FTS5, hybrid-search, context-compression, dependency-minimization, PostToolUse, 적용분석
> **관련 리서치**: RESEARCH-hybrid-search-fts5-rrf.md, RESEARCH-context-compression-98.md, RESEARCH-mcp-vs-cli.md, RESEARCH-code-entropy-dependency-minimization.md, RESEARCH-code-as-specification.md

---

## 즉시 적용 가능

| 기술 | HXSK 적용 방안 | 난이도 | 효과 |
|------|---------------|--------|------|
| **FTS5 기반 메모리 검색** | `md-recall-memory.sh`를 SQLite FTS5로 교체 | 중 | 검색 품질 대폭 향상 |
| **증분 인덱싱** | 메모리 파일 변경 시 해시 기반 증분 업데이트 | 낮음 | 재인덱싱 속도 |
| **Progressive Throttling** | 검색 호출 횟수 제한 → 컨텍스트 보호 | 낮음 | 토큰 절약 |
| **의존성 길이 최소화** | 스킬/에이전트 구조 점검 기준으로 채택 | 낮음 | 코드 품질 |

## 중기 검토 (외부 종속성 도입 필요)

| 기술 | HXSK 적용 방안 | 난이도 | 고려사항 |
|------|---------------|--------|----------|
| **하이브리드 검색 (RRF)** | FTS5 + sqlite-vec 결합 | 높음 | Python/Node 의존성 추가 필요 |
| **Model2Vec 임베딩** | 의미 기반 메모리 검색 | 높음 | 외부 종속성 원칙 위반 |
| **컨텍스트 압축** | PostToolUse hook에서 출력 압축 | 중 | 정보 손실 리스크 |

## "외부 종속성 없음" 원칙과의 조화

HXSK의 핵심 원칙은 "순수 bash + 마크다운" — 하이브리드 검색 도입 시 두 가지 경로:

**경로 A: 순수 FTS5만 도입 (bash + sqlite3)**
```bash
# sqlite3는 macOS/Linux 기본 설치
sqlite3 .hxsk/memories/index.db "
  CREATE VIRTUAL TABLE IF NOT EXISTS mem_fts USING fts5(
    title, content, tags, type,
    content=memories, tokenize='porter'
  );
  INSERT INTO mem_fts SELECT * FROM memories;
  SELECT * FROM mem_fts WHERE mem_fts MATCH 'architecture' ORDER BY rank LIMIT 5;
"
```
- 외부 종속성 없음 (sqlite3는 시스템 내장)
- BM25 + Porter Stemming으로 현재 grep 대비 대폭 개선
- 3계층 폴백 (Stemming → Trigram → Fuzzy) 구현 가능

**경로 B: 플러그인으로 분리 (선택적 의존성)**
- `hxsk-plugin`의 선택적 확장으로 하이브리드 검색 제공
- 핵심 보일러플레이트는 순수 bash 유지
- 벡터 검색이 필요한 사용자만 설치

## PostToolUse Hook 기반 컨텍스트 압축

Context Mode의 아이디어를 HXSK hook 시스템에 적용:

```
PostToolUse (Read/Grep/Glob)
    │
    ├─ 출력 크기 > 임계값?
    │   ├─ Yes → FTS5 인덱싱 + 요약 반환
    │   └─ No → 원본 반환
    │
    └─ 인덱싱된 데이터는 search 도구로 재접근 가능
```

## 코드 엔트로피 원칙의 HXSK 적용

| 원칙 | HXSK 현재 상태 | 개선 기회 |
|------|---------------|----------|
| 의존성 길이 최소화 | Agent-Skill 래핑으로 관련 코드 근접 | 스킬 내부에서 참조하는 외부 파일 경로 최소화 |
| 과적합 방지 | Quick Reference(5줄) 패턴으로 토큰 절감 | CLAUDE.md에서 에이전트가 발견 가능한 정보 제거 |
| 코드 = 명세 | 타입/스키마 정의 있음 (`_schema/`) | 자연언어 지침을 검증 가능한 스크립트로 전환 |
| 점진적 구조 진화 | 메모리 타입 14개로 안정화 | 사용 빈도 기반 타입 정리/통합 검토 |

---

## 관련 HXSK 리서치

- `RESEARCH-agents-md-agentic-engineering-2026.md` — AGENTS.md, ACE 프레임워크, 에이전틱 엔지니어링 9대 스킬
- `RESEARCH-a-mem-agentic-memory.md` — A-Mem 에이전트 메모리 연구

*Last updated: 2026-03-04*
