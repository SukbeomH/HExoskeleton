---
name: memory-protocol
description: Memory operation rules — file-based recall/store protocol, field requirements, type registry
version: 4.0.0
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
---

## Quick Reference
- **Recall**: `Grep → Glob` 순서, 또는 `md-recall-memory.sh <query> [path] [limit] [mode] [hop]`
- **Store**: `md-store-memory.sh <title> <content> [tags] [type] [keywords] [contextual_desc] [related]`
- **A-Mem 필드**: `contextual_description`, `keywords`, `related` (2-hop 검색용)
- **중복 방지**: 동일 title/slug → 자동 스킵 (Nemori Predict-Calibrate)
- **스키마**: `.gsd/memories/_schema/*.schema.json`, `type-relations.yaml`

---

# Memory Protocol

> **Goal**: `.gsd/memories/` 파일 기반 메모리 시스템의 사용 규칙을 중앙 정의하여 모든 스킬과 훅이 일관된 메모리 패턴을 따르도록 한다.
> **Scope**: search/store 순서, 필수 필드, type 레지스트리, A-Mem 확장 필드, 2-hop 검색. 모든 메모리는 마크다운 파일로 저장/검색.

---

## Recall Protocol

메모리 조회는 반드시 **Grep 텍스트 검색 → 태그 필터링** 순서를 따른다.

### 1. Grep 검색 (우선)
세션/태스크 시작 시 broad context를 먼저 가져온다:

```bash
# .gsd/memories/ 전체에서 키워드 검색
grep -rli "{keyword}" .gsd/memories/ | sort -r | head -5
```

또는 Grep 도구 사용:
```
Grep(pattern: "{keyword}", path: ".gsd/memories/", output_mode: "files_with_matches")
```

### 2. 태그 기반 필터 (보충)
특정 타입이나 태그로 좁혀야 할 때:

```
Glob(pattern: ".gsd/memories/{type}/*.md")
```

```
Grep(pattern: "tags:.*{tag}", path: ".gsd/memories/", output_mode: "files_with_matches")
```

### 3. 훅 기반 검색 (자동화)
훅에서 사용할 때:

```bash
# 기본 검색 (compact 모드, 2-hop)
bash scripts/md-recall-memory.sh "{query}" "$PROJECT_DIR" 5

# 상세 검색 (full 모드)
bash scripts/md-recall-memory.sh "{query}" "$PROJECT_DIR" 5 full

# 1-hop만 (related 추적 안함)
bash scripts/md-recall-memory.sh "{query}" "$PROJECT_DIR" 5 compact 1
```

### 4. 2-hop 이웃 검색 (A-Mem)
검색된 메모리의 `related` 필드를 자동 추적하여 연결된 메모리도 함께 반환:

```bash
# hop=2 (기본값): related 필드의 메모리도 포함
bash scripts/md-recall-memory.sh "auth" "." 5 compact 2
```

Output에서 `[→related]` 표시로 2-hop 결과 구분 가능.

### When to Recall
| Timing | Required | Example |
|--------|----------|---------|
| Session start | YES (자동: session-start.sh) | 프로젝트 컨텍스트 검색 |
| Task start | YES | 관련 과거 작업/결정 검색 |
| Debug start | YES | 유사 버그/eliminated hypotheses 검색 |
| Plan creation | YES | 과거 deviation/execution-summary 검색 |
| Arch review | YES | 과거 architecture-decision 검색 |
| Before store | NO | 중복 방지 목적으로 선택적 |

---

## Storage Protocol

### Required Fields

모든 메모리 파일은 아래 YAML frontmatter를 **필수** 포함:

| Field | Description | Required |
|-------|-------------|----------|
| `title` | 메모리 제목 (markdown 헤더로도 반복) | ✓ |
| `tags` | YAML 배열 (최소 2개) | ✓ |
| `type` | Type Registry에서 선택 | ✓ |
| `created` | ISO-8601 타임스탬프 | ✓ |
| `contextual_description` | A-Mem: 1줄 요약 (200자 제한) | 자동생성 |
| `keywords` | A-Mem: LLM 생성 검색 키워드 | 권장 |
| `related` | A-Mem Link: 관련 메모리 파일명 배열 | 선택 |

### 파일 저장 방법

**방법 1: 훅 사용 (권장, A-Mem 확장)**
```bash
# 기본
bash scripts/md-store-memory.sh "{title}" "{content}" "{tag1,tag2}" "{type}"

# A-Mem 확장 필드 포함
bash scripts/md-store-memory.sh "{title}" "{content}" "{tags}" "{type}" "{keywords}" "{contextual_desc}" "{related}"
```

**중복 방지 (Nemori Predict-Calibrate):**
- 동일 날짜+title이면 `[SKIP:DUPLICATE]` 반환하고 저장 안 함
- 중복 시 기존 파일 경로 출력

**방법 2: 직접 파일 생성**
```markdown
---
title: "{title}"
tags:
  - tag1
  - tag2
type: {type}
created: {ISO-8601}
---

## {title}

{content}
```

파일 경로: `.gsd/memories/{type}/{YYYY-MM-DD}_{slug}.md`

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

파일 기반 시스템에서 중요도는 content의 상세도와 태그 풍부도로 결정된다.
중요도를 높이려면 content에 맥락과 증거를 풍부하게 기술한다.

| 중요도 수준 | Content 전략 |
|-------------|-------------|
| Critical | 아키텍처 결정 근거, 영향 범위, 대안 비교 등 상세 기술 |
| High | 근본 원인, 발견 패턴의 증거와 재현 경로 포함 |
| Medium | 배제 가설의 증거, 이탈 사유 간결히 기술 |
| Low | 요약 수준 (세션 요약, 자동 스냅샷) |

---

## Relationship Handling

### A-Mem Link (권장)
`related` 필드를 사용하여 메모리 간 연결:

```yaml
related:
  - 2024-01-15_auth-token-expired
  - 2024-01-16_jwt-validation-fix
```

### 연관 조회 (2-hop)

`md-recall-memory.sh`가 자동으로 `related` 필드를 추적:
```bash
# hop=2 (기본): 검색 결과 + related 메모리
bash scripts/md-recall-memory.sh "auth" "." 5 compact 2
```

### 태그 기반 연결 (레거시)
태그에 `related:{slug}` 패턴도 여전히 지원:

```yaml
tags:
  - debug
  - root-cause
  - related:2024-01-15_auth-token-expired
```

---

## Type Relations (Ontology)

`.gsd/memories/_schema/type-relations.yaml`에서 14개 타입 간 관계 정의:

| Relation | 의미 | 예시 |
|----------|-----|------|
| `resolves` | A가 B 문제를 해결 | root-cause → debug-eliminated |
| `informs` | A가 B 결정에 영향 | architecture-decision → pattern-discovery |
| `triggers` | A 발생 시 B 생성 | debug-blocked → health-event |
| `generates` | A에서 B 도출 | root-cause → pattern-discovery |

### Search Chains (최적화된 검색 순서)
```yaml
debugging_chain: [debug-blocked, debug-eliminated, root-cause, pattern-discovery]
architecture_chain: [bootstrap, architecture-decision, pattern-discovery]
session_chain: [session-snapshot, session-summary, session-handoff]
```

---

## Schema Validation

`.gsd/memories/_schema/` 디렉토리에 JSON Schema 정의:

- `base.schema.json`: 공통 필드 (A-Mem 확장 포함)
- `root-cause.schema.json`: 근본 원인 전용 필드
- `architecture-decision.schema.json`: ADR 스타일 필드
- `session-summary.schema.json`: Nemori 서사 형태 필드

---

## Type Registry

| Type | Description | Primary Tags | Directory |
|------|------------|-------------|-----------|
| `architecture-decision` | 아키텍처 결정 사항 | `arch,decision` | `memories/architecture-decision/` |
| `root-cause` | 디버깅 근본 원인 | `debug,root-cause` | `memories/root-cause/` |
| `debug-eliminated` | 배제된 가설 | `debug,eliminated` | `memories/debug-eliminated/` |
| `debug-blocked` | 3-strike로 차단된 조사 | `debug,blocked,3-strike` | `memories/debug-blocked/` |
| `health-event` | 컨텍스트 건강 이벤트 | `health,context` | `memories/health-event/` |
| `session-handoff` | 세션 인수인계 정보 | `handoff,session` | `memories/session-handoff/` |
| `execution-summary` | 실행 결과 요약 | `execution,summary` | `memories/execution-summary/` |
| `deviation` | 계획 대비 이탈 | `deviation,plan` | `memories/deviation/` |
| `pattern-discovery` | 발견된 패턴/학습 | `pattern,learning` | `memories/pattern-discovery/` |
| `bootstrap` | 프로젝트 초기 설정 기록 | `bootstrap,setup` | `memories/bootstrap/` |
| `session-summary` | 세션 종료 요약 | `session,auto` | `memories/session-summary/` |
| `session-snapshot` | Pre-compact 스냅샷 | `session-snapshot,pre-compact` | `memories/session-snapshot/` |
| `security-finding` | 보안 발견 사항 | `security,finding` | `memories/security-finding/` |
| `general` | 기타 | context-dependent | `memories/general/` |

---

## Anti-Patterns

| Anti-Pattern | Why | Instead |
|-------------|-----|---------|
| Grep 없이 바로 파일 열기 | 관련 없는 파일 읽는 시간 낭비 | Grep 검색 → 관련 파일만 Read |
| content에 title 미포함 | 검색 시 맥락 부족 | `## {title}\n\n{content}` 형식 사용 |
| 단일 태그 사용 | 검색 정밀도 저하 | 최소 2개 태그 (type + domain) |
| 매 커밋마다 자동 저장 | noise > signal | Trigger 테이블의 시점만 저장 |
| 중복 저장 | 디렉토리 비대화 | 저장 전 Grep으로 중복 확인 (선택적) |
