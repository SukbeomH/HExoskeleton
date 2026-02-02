---
name: memory-protocol
description: Memory operation rules — recall/store/search protocol, field requirements, importance scoring, relationship types
version: 2.0.0
allowed-tools:
  - memory_store
  - memory_search
  - memory_graph
  - memory_update
  - memory_delete
  - memory_stats
  - memory_list
---

# Memory Protocol

> **Goal**: mcp-memory-service 사용 규칙을 중앙 정의하여 모든 스킬과 훅이 일관된 메모리 패턴을 따르도록 한다.
> **Scope**: search/store 순서, 필수 필드, importance 점수(AI 자동), relationship 워크어라운드, type 레지스트리.

---

## Recall Protocol

메모리 조회는 반드시 **semantic search → tag search** 순서를 따른다.

### 1. memory_search (semantic, 우선)
세션/태스크 시작 시 broad context를 먼저 가져온다:

```
memory_search(
  query: "{task or feature description}",
  mode: "semantic"
)
```

### 2. memory_search (tag 필터, 보충)
semantic 결과가 부족하거나 특정 태그/타입으로 좁혀야 할 때:

```
memory_search(
  query: "{specific symptom}",
  tags: ["debug", "root-cause"]
)
```

### When to Recall
| Timing | Required | Example |
|--------|----------|---------|
| Session start | YES | 세션 시작 시 프로젝트 컨텍스트 search |
| Task start | YES | 관련 과거 작업/결정 search |
| Debug start | YES | 유사 버그/eliminated hypotheses search |
| Plan creation | YES | 과거 deviation/execution-summary search |
| Arch review | YES | 과거 architecture-decision search |
| Before store | NO | 중복 방지 목적으로 선택적 |

---

## Storage Protocol

### Required Fields

모든 `memory_store` 호출에 아래 필드는 **필수**:

| Field | Description |
|-------|-------------|
| `content` | `## {title}\n\n{상세 내용}` (title을 markdown 헤더로 포함) |
| `metadata.tags` | 콤마 구분 태그 문자열 (최소 2개) |
| `metadata.type` | Type Registry에서 선택 |

### Storage Triggers

| Trigger | Type | Timing |
|---------|------|--------|
| Bug root cause found | `root-cause` | Immediate |
| Architecture decision | `architecture-decision` | Immediate |
| Pattern discovered | `pattern-discovery` | Immediate |
| Security finding | `security-finding` | Immediate |
| Hypothesis eliminated | `debug-eliminated` | Immediate |
| Plan deviation | `deviation` | On commit |
| Execution summary | `execution-summary` | On commit |
| Health event | `health-event` | On event |
| Session end | `session-summary` | Auto (hook) |
| Pre-compact snapshot | `session-snapshot` | Auto (hook) |
| Debug blocked (3-strike) | `debug-blocked` | Immediate |
| Bootstrap record | `bootstrap` | On complete |

---

## Importance Scoring

mcp-memory-service는 AI 기반 자동 품질 점수를 사용한다. 수동 importance 지정 불가.
중요도를 높이려면 content에 맥락과 증거를 풍부하게 기술한다.

| 중요도 수준 | Content 전략 |
|-------------|-------------|
| Critical | 아키텍처 결정 근거, 영향 범위, 대안 비교 등 상세 기술 |
| High | 근본 원인, 발견 패턴의 증거와 재현 경로 포함 |
| Medium | 배제 가설의 증거, 이탈 사유 간결히 기술 |
| Low | 요약 수준 (세션 요약, 자동 스냅샷) |

---

## Relationship Handling

mcp-memory-service는 `memory_graph`를 통해 자동 연관을 생성한다.
명시적 relationship 타입(`caused-by`, `solved-by` 등)은 지원되지 않으므로 태그 인코딩으로 대응:

### 태그 인코딩 워크어라운드

관련 메모리를 연결할 때 태그에 `related:{content_hash_prefix}` 패턴을 사용:

```
memory_store(
  content: "## Root Cause: {cause}\n\n{evidence}",
  metadata: {
    tags: "debug,root-cause,related:abc123",
    type: "root-cause"
  }
)
```

### 연관 조회

`memory_graph`의 자동 연관 기능 또는 태그 검색으로 조회:

```
memory_search(query: "related issue", tags: ["related:abc123"])
```

---

## Type Registry

| Type | Description | Primary Tags |
|------|------------|-------------|
| `architecture-decision` | 아키텍처 결정 사항 | `arch,decision` |
| `root-cause` | 디버깅 근본 원인 | `debug,root-cause` |
| `debug-eliminated` | 배제된 가설 | `debug,eliminated` |
| `debug-blocked` | 3-strike로 차단된 조사 | `debug,blocked,3-strike` |
| `health-event` | 컨텍스트 건강 이벤트 | `health,context` |
| `session-handoff` | 세션 인수인계 정보 | `handoff,session` |
| `execution-summary` | 실행 결과 요약 | `execution,summary` |
| `deviation` | 계획 대비 이탈 | `deviation,plan` |
| `pattern-discovery` | 발견된 패턴/학습 | `pattern,learning` |
| `bootstrap` | 프로젝트 초기 설정 기록 | `bootstrap,setup` |
| `session-summary` | 세션 종료 요약 | `session,auto` |
| `session-snapshot` | Pre-compact 스냅샷 | `session-snapshot,pre-compact` |
| `security-finding` | 보안 발견 사항 | `security,finding` |
| `general` | 기타 | context-dependent |

---

## Anti-Patterns

| Anti-Pattern | Why | Instead |
|-------------|-----|---------|
| search without semantic first | Semantic이 broader context 제공 | semantic search → tag search 순서 |
| content에 title 미포함 | 검색 시 맥락 부족 | `## {title}\n\n{content}` 형식 사용 |
| 단일 태그 사용 | 검색 정밀도 저하 | 최소 2개 태그 (type + domain) |
| 매 커밋마다 자동 저장 | noise > signal | Trigger 테이블의 시점만 저장 |
| 중복 저장 | DB 비대화 | 저장 전 search로 중복 확인 (선택적) |
