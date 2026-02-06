# Memory System

순수 bash + 마크다운 파일 기반 에이전트 메모리 시스템.

## 개요

외부 종속성 없이 파일 시스템만으로 에이전트 메모리를 관리합니다.

| 구성요소 | 설명 |
|----------|------|
| **저장소** | `.gsd/memories/{type}/` 디렉토리 |
| **형식** | YAML frontmatter + Markdown |
| **저장** | `md-store-memory.sh` |
| **검색** | `md-recall-memory.sh` |

---

## 메모리 저장

### 사용법

```bash
bash .claude/hooks/md-store-memory.sh \
  "<title>" \
  "<content>" \
  "[tags]" \
  "[type]" \
  "[keywords]" \
  "[contextual_description]" \
  "[related]"
```

### 매개변수

| 매개변수 | 필수 | 설명 | 예시 |
|----------|------|------|------|
| `title` | ✅ | 메모리 제목 | "버그 수정: 인증 오류" |
| `content` | ✅ | 메모리 내용 | "JWT 토큰 만료 처리 누락..." |
| `tags` | - | 쉼표 구분 태그 | "bug,auth,jwt" |
| `type` | - | 메모리 타입 (기본: general) | "root-cause" |
| `keywords` | - | A-Mem 검색 키워드 | "인증,토큰,만료" |
| `contextual_description` | - | 1줄 요약 (검색 결과 압축용) | "JWT 토큰 만료 처리 누락으로 인한 401 오류" |
| `related` | - | 관련 메모리 파일명 | "2026-02-05_auth-decision.md" |

### 출력

```
./.gsd/memories/root-cause/2026-02-06_jwt.md
```

### 중복 방지 (Nemori Predict-Calibrate)

동일 title이 같은 날짜에 이미 존재하면 스킵:

```
[SKIP:DUPLICATE] ./.gsd/memories/root-cause/2026-02-06_jwt.md
```

---

## 메모리 검색

### 사용법

```bash
bash .claude/hooks/md-recall-memory.sh \
  "<query>" \
  "[project_path]" \
  "[limit]" \
  "[mode]" \
  "[hop]"
```

### 매개변수

| 매개변수 | 기본값 | 설명 |
|----------|--------|------|
| `query` | - | 검색어 (필수) |
| `project_path` | `.` | 프로젝트 경로 |
| `limit` | `5` | 최대 결과 수 |
| `mode` | `compact` | compact (요약) 또는 full (전체) |
| `hop` | `2` | 1 (직접만) 또는 2 (related 포함) |

### compact 모드 출력

```
- **JWT 토큰 만료 처리** [root-cause] 2026-02-06
  JWT 토큰 만료 처리 누락으로 인한 401 오류
- **인증 아키텍처 결정** [architecture-decision] 2026-02-05 [→related]
  OAuth2 + JWT 조합으로 결정
```

### full 모드 출력

```markdown
### JWT 토큰 만료 처리 [root-cause]
📁 `./.gsd/memories/root-cause/2026-02-06_jwt.md`

## JWT 토큰 만료 처리

JWT 토큰 만료 시 401 오류가 발생하는 문제.
원인: 토큰 갱신 로직 누락...
```

---

## 메모리 타입 (14개)

| 타입 | 용도 | 저장 시점 |
|------|------|----------|
| `architecture-decision` | 아키텍처 결정 사항 | 설계 결정 시 |
| `root-cause` | 디버깅 근본 원인 | 버그 원인 발견 시 |
| `debug-eliminated` | 배제된 가설 | 가설 검증 실패 시 |
| `debug-blocked` | 3-strike 차단 | 3회 실패 시 |
| `pattern-discovery` | 발견된 패턴/학습 | 패턴 발견 시 |
| `deviation` | 계획 대비 이탈 | 계획 변경 시 |
| `execution-summary` | 실행 결과 요약 | 플랜 완료 시 |
| `session-summary` | 세션 종료 요약 | 세션 종료 시 (자동) |
| `session-snapshot` | Pre-compact 스냅샷 | 컴팩트 전 (자동) |
| `session-handoff` | 세션 인수인계 | 인수인계 시 |
| `health-event` | 컨텍스트 건강 이벤트 | 경고 발생 시 |
| `bootstrap` | 프로젝트 초기 설정 | 부트스트랩 시 |
| `security-finding` | 보안 발견 사항 | 보안 이슈 발견 시 |
| `general` | 기타 | 기타 상황 |

---

## 파일 형식

### 파일명

```
{YYYY-MM-DD}_{slug}.md
```

예: `2026-02-06_jwt-token-expiry.md`

### YAML Frontmatter

```yaml
---
title: "JWT 토큰 만료 처리"
tags:
  - bug
  - auth
  - jwt
type: root-cause
created: 2026-02-06T00:00:00Z
contextual_description: "JWT 토큰 만료 처리 누락으로 인한 401 오류"
keywords:
  - 인증
  - 토큰
  - 만료
related:
  - 2026-02-05_auth-decision.md
---

## JWT 토큰 만료 처리

내용...
```

---

## A-Mem 확장 필드

[A-Mem 연구](https://arxiv.org/abs/2409.02634) 기반 확장 필드:

| 필드 | 용도 |
|------|------|
| `keywords` | LLM 생성 검색 키워드 (쉼표 구분) |
| `contextual_description` | 1줄 요약 (검색 결과 압축용, ReWOO 패턴) |
| `related` | 관련 메모리 파일명 (2-hop 검색용) |

### 2-hop 검색

검색 결과의 `related` 필드를 추적하여 연결된 메모리도 함께 반환:

```bash
# hop=2 (기본값): related 필드 추적
bash .claude/hooks/md-recall-memory.sh "인증" "." 5 compact 2

# hop=1: 직접 검색만
bash .claude/hooks/md-recall-memory.sh "인증" "." 5 compact 1
```

---

## 스키마

`.gsd/memories/_schema/` 디렉토리에 JSON Schema 및 타입 관계 정의:

| 파일 | 내용 |
|------|------|
| `base.schema.json` | 기본 메모리 스키마 (A-Mem 필드 포함) |
| `type-relations.yaml` | 14개 타입 간 관계 정의 |
| `{type}.schema.json` | 타입별 스키마 (선택) |

### 타입 관계 예시

```yaml
root-cause:
  relations:
    resolves: [debug-eliminated, debug-blocked]
    prevents: [health-event]
    generates: [pattern-discovery]
```

---

## 네이티브 도구 연동

Claude Code의 네이티브 도구로 직접 검색 가능:

```
# 넓은 검색 (Grep 우선)
Grep(pattern: "인증", path: ".gsd/memories/")

# 좁은 검색 (타입 특정)
Glob(pattern: ".gsd/memories/root-cause/*.md")
```

권장 순서: **Grep → Glob** (broad → narrow)

---

## 자동 저장 트리거

| 트리거 | 타입 | 훅 |
|--------|------|-----|
| 세션 종료 | `session-summary` | `stop-context-save.sh` |
| Pre-compact | `session-snapshot` | `pre-compact-save.sh` |

---

## 연구 기반

| 연구 | 적용 |
|------|------|
| [A-Mem](https://arxiv.org/abs/2409.02634) | keywords, contextual_description, related 필드 |
| [Nemori](https://arxiv.org/abs/2310.15670) | Predict-Calibrate 중복 방지, 서사 형태 요약 |
| [ReWOO](https://arxiv.org/abs/2305.18323) | 검색 결과 압축 (compact 모드) |
