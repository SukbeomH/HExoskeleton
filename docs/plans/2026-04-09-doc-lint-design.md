# 문서 정합성 검사 도구 설계 (doc-lint)

> 2026-04-09 | Bottom-up 접근 — 수동 감사 → 자동화 정착

## 목표

360개 .md 파일의 구조적·내용적 정합성을 검증하는 도구 구축.
일회성 감사로 현 상태를 파악한 뒤, 반복 가능한 자동화 도구로 정착시킨다.

## 산출물

| 구성 요소 | 파일 | 역할 |
|-----------|------|------|
| 구조적 검사 스크립트 | `.hxsk/scripts/doc-lint.sh` | 7개 규칙, 전체 .md 대상, exit code 반환 |
| 내용적 검사 스킬 | `.hxsk/skills/doc-lint/SKILL.md` | 병렬 에이전트로 L1/INDEX 문서 검증 |
| pre-commit 연동 | settings.json 또는 hooks/ | 구조적 검사만 커밋 시 자동 실행 |

## Phase 1: 수동 감사

L1 문서(CLAUDE.md, AGENTS.md, README.md) + 전체 .md 파일을 실제 프로젝트 상태와 대조.
발견된 불일치를 카테고리별로 기록:

- **깨진 참조**: 존재하지 않는 파일/경로를 가리키는 링크
- **목록 불일치**: 문서에 나열된 항목 수 vs 실제 파일 수
- **설명 불일치**: 문서의 기능 설명이 실제 코드/스킬과 다른 경우
- **누락**: 실제 존재하지만 문서에 언급되지 않은 항목

## Phase 2: `doc-lint.sh` 구조적 검사 규칙

```
규칙 ID    | 검사 내용                                | 대상              | 상태
-----------|------------------------------------------|-------------------|--------
LINK-01    | .md 파일 내 상대 링크 유효성               | 전체 .md          | 구현됨
LINK-02    | 앵커 링크(#section) 유효성                 | 전체 .md          | 미구현(후속)
INDEX-01   | INDEX.md 목록 vs 실제 파일 차집합           | skills/, agents/, research/ | 구현됨
COUNT-01   | README 카운트 숫자 vs 실제 파일/항목 수      | README.md         | 구현됨
REF-01     | CLAUDE.md/AGENTS.md 경로 참조 유효성        | L1 문서           | 구현됨
ORPHAN-01  | 어떤 INDEX/문서에서도 참조되지 않는 고아 파일  | 전체 .md          | 구현됨
DUP-01     | 동일 파일명이 여러 위치에 존재               | 전체 .md          | 구현됨
```

> **LINK-02**는 초기 릴리스 스코프에서 제외. 본격 앵커 검사는 후속 PR에서 추가 예정 — 각 `.md`의 `## 헤딩`을 수집한 후 `#anchor` 링크와 교차 검증 필요.

### 설계 원칙

- 각 규칙은 독립 함수로 구현 → 개별 실행/비활성화 가능
- 출력 형식: `[PASS|FAIL] RULE-ID: 메시지` (한 줄 요약)
- FAIL 시 상세는 들여쓰기로 아래에 나열
- exit code: FAIL이 1개라도 있으면 `exit 1` → pre-commit에서 차단
- 외부 종속성 없음: `bash`, `grep`, `sed`, `wc`, `diff`만 사용
- `--rule RULE-ID` 옵션으로 특정 규칙만 실행 가능

### 실행 예시

```bash
$ bash .hxsk/scripts/doc-lint.sh
[PASS] LINK-01: 상대 링크 유효성 (142/142)
[FAIL] INDEX-01: skills/INDEX.md에 누락된 항목 2건
         - debugger/root-cause-tracing.md
         - empirical-validation/anti-patterns.md
[FAIL] COUNT-01: README "스킬 14개" → 실제 16개
[PASS] REF-01: CLAUDE.md 경로 참조 (8/8)
```

## Phase 3: `doc-lint` 스킬 (내용적 검사)

### 병렬 에이전트 디스패치

```
doc-lint 스킬 실행
├─ Step 1: doc-lint.sh 실행 (구조적 검사)
├─ Step 2: FAIL 항목 수정
└─ Step 3: 내용적 검사 — 병렬 에이전트 디스패치
     ├─ Agent A: CLAUDE.md + AGENTS.md 검증
     ├─ Agent B: README.md + ARCHITECTURE.md 검증
     └─ Agent C: skills/INDEX.md + agents/INDEX.md + research/INDEX.md 검증
```

### 에이전트 프롬프트 패턴

```
"[문서명]을 읽고, 언급된 파일 경로·기능 설명·워크플로우가
실제 프로젝트 상태와 일치하는지 검증하라.
불일치 항목을 [MISMATCH] 형식으로 보고하라."
```

### 결과 통합

```
=== 내용적 검사 결과 ===
[MISMATCH] CLAUDE.md:15 — ".hxsk/hooks/" 설명에 SessionEnd 누락
[MISMATCH] README.md:42 — "스킬 14개" → 실제 16개
[OK] AGENTS.md — 불일치 없음
[OK] ARCHITECTURE.md — 불일치 없음
```

## Phase 4: pre-commit 연동

### 훅 구성

```
커밋 시점
├─ pre-commit: doc-lint.sh 실행 (구조적 검사만)
│   ├─ PASS → 커밋 진행
│   └─ FAIL → 커밋 차단, 불일치 목록 출력
│
└─ 내용적 검사는 pre-commit에 포함하지 않음
    → 에이전트 호출이 필요하므로 PR/수동 시점에서 실행
```

### 분리 이유

- pre-commit은 빠르게 끝나야 함 (1-2초) → bash 스크립트만 적합
- 내용적 검사는 LLM 에이전트가 판단해야 하므로 자동 차단에 부적합
- PR 리뷰 시 `doc-lint` 스킬을 수동 호출하는 것이 현실적
