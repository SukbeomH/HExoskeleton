# Agents 상세 문서

Claude Code의 **Agents**는 특정 작업에 특화된 서브프로세스입니다. 메인 대화와 별도의 컨텍스트에서 실행되며, 복잡한 멀티스텝 작업을 자율적으로 수행합니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **위치** | `.claude/agents/*.md` |
| **개수** | 14개 |
| **호출 방식** | Claude가 필요 시 자동 위임 또는 Task 도구로 명시적 호출 |
| **컨텍스트** | 메인 대화와 분리된 별도 서브프로세스 |

---

## 에이전트 목록

### 핵심 워크플로우 에이전트

| Agent | 파일 | 역할 | Capabilities |
|-------|------|------|--------------|
| `planner` | `planner.md` | 실행 가능한 페이즈 계획 설계 | Read, Grep, Glob |
| `plan-checker` | `plan-checker.md` | 계획 검증 (6차원 분석) | Read, Grep, Glob |
| `executor` | `executor.md` | 계획 실행 + atomic commits | Read, Write, Edit, Bash, Grep, Glob |
| `verifier` | `verifier.md` | 구현 검증 + 증거 수집 | Read, Bash, Grep, Glob |
| `debugger` | `debugger.md` | 체계적 디버깅 (3-strike rule) | Read, Write, Edit, Bash, Grep, Glob |
| `bootstrap` | `bootstrap.md` | 프로젝트 초기 설정 | Read, Write, Edit, Bash, Grep, Glob |

### 분석 에이전트

| Agent | 파일 | 역할 | Capabilities |
|-------|------|------|--------------|
| `impact-analysis` | `impact-analysis.md` | 변경 영향 분석 | Read, Grep, Glob |
| `arch-review` | `arch-review.md` | 아키텍처 규칙 검증 | Read, Grep, Glob |
| `codebase-mapper` | `codebase-mapper.md` | 코드베이스 구조 분석 | Read, Bash, Grep, Glob |
| `context-health-monitor` | `context-health-monitor.md` | 컨텍스트 복잡도 모니터링 | Read, Grep, Glob |

### Git/PR 에이전트

| Agent | 파일 | 역할 | Capabilities |
|-------|------|------|--------------|
| `commit` | `commit.md` | conventional commit 생성 | Read, Bash, Grep, Glob |
| `create-pr` | `create-pr.md` | PR 생성 (gh CLI) | Read, Bash, Grep, Glob |
| `pr-review` | `pr-review.md` | 다중 페르소나 코드 리뷰 | Read, Bash, Grep, Glob |

### 유틸리티 에이전트

| Agent | 파일 | 역할 | Capabilities |
|-------|------|------|--------------|
| `clean` | `clean.md` | 코드 품질 도구 실행 | Read, Write, Edit, Bash, Grep, Glob |

---

## 에이전트 구조

### Frontmatter 형식

```yaml
---
description: 에이전트 역할에 대한 간단한 설명
capabilities: ["Read", "Grep", "Glob"]
---
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `description` | Yes | 에이전트 역할 설명 (트리거 조건으로 사용) |
| `capabilities` | Yes | 사용 가능한 도구 배열 |

### 본문 구조

```markdown
# {Agent Name} Agent

{역할 설명}

## 핵심 원칙
1. ...
2. ...

## 실행 흐름
1. ...
2. ...

## 제약사항
- ...
```

---

## 주요 에이전트 상세

### Executor Agent

**역할**: PLAN.md를 원자적으로 실행하고 태스크별 커밋을 생성

**핵심 원칙**:
1. **Atomic Execution**: 태스크 단위로 실행 → 검증 → 커밋
2. **Deviation Handling**: 계획 이탈 시 4가지 규칙 적용
3. **Checkpoint Protocol**: 인간 검증이 필요한 지점에서 일시 정지
4. **State Persistence**: 진행 상태를 `.gsd/STATE.md`에 기록

**이탈 규칙**:

| 규칙 | 트리거 | 조치 |
|------|--------|------|
| Rule 1 | 버그 발견 | 자동 수정 |
| Rule 2 | 누락된 필수 기능 | 자동 추가 |
| Rule 3 | 차단 이슈 | 자동 해결 시도 |
| Rule 4 | 아키텍처 변경 | 사용자 승인 요청 |

**실행 흐름**:
```
1. PLAN.md 로드 → 태스크 목록 파싱
2. 태스크별 순차 실행:
   - 파일 생성/수정
   - verify 명령 실행
   - done 기준 확인
   - 원자적 커밋
3. 전체 verification 체크리스트 실행
4. SUMMARY.md 생성
```

---

### Planner Agent

**역할**: 시스템 전체를 이해하고 실행 가능한 페이즈 플랜 설계

**핵심 원칙**:
1. **Goal-Backward**: 목표 상태에서 역추론하여 must-haves 도출
2. **Aggressive Atomicity**: 플랜당 2-3 태스크, 50% 컨텍스트 내 완료
3. **Vertical Slices**: 수평 레이어가 아닌 수직 기능 단위로 분할
4. **Discovery-First**: 레벨 0-3 탐색 프로토콜 반드시 수행

**Discovery 레벨**:

| 레벨 | 조건 | 시간 |
|------|------|------|
| Level 0 | 기존 패턴만 사용, 외부 의존성 없음 | Skip |
| Level 1 | 단일 라이브러리 확인 | 2-5분 |
| Level 2 | 2-3개 옵션 비교 | 15-30분 |
| Level 3 | 아키텍처 결정 | 1시간+ |

---

### Debugger Agent

**역할**: 체계적 디버깅 + 3-strike rule 적용

**3-Strike Rule**:
- 동일 문제에 대해 3회 연속 실패 시 접근 방식 변경
- 웹 검색, 공식 문서 확인, 또는 fresh session 권장

**디버깅 흐름**:
```
1. 증상 수집 및 재현
2. 가설 수립
3. 검증 (최대 3회)
4. 실패 시 상태 저장 → fresh session 권장
```

---

## 에이전트 호출 방식

### 자동 위임 (Task 도구)

Claude가 복잡한 작업을 감지하면 자동으로 적절한 에이전트에게 위임합니다.

```
User: "이 기능의 영향 범위 분석해줘"
     │
     ▼
Claude: Task 도구로 impact-analysis 에이전트 호출
     │
     ▼
impact-analysis 에이전트: 분석 수행 후 결과 반환
```

### 워크플로우에서 호출

워크플로우(Commands)가 내부적으로 에이전트를 호출합니다.

```markdown
<!-- /execute 워크플로우 -->
executor 에이전트를 호출하여 PLAN.md 실행
```

---

## Skills vs Agents

| 구분 | Skills | Agents |
|------|--------|--------|
| **호출 방식** | Claude가 자율적으로 결정 | 명시적 호출 또는 자동 위임 |
| **컨텍스트** | 메인 대화에서 실행 | 별도 서브프로세스 |
| **용도** | 가벼운 전문 기능 | 복잡한 멀티스텝 작업 |
| **상태 유지** | 메인 대화 컨텍스트 공유 | 독립적 컨텍스트 |

---

## 에이전트 작성 가이드

### 1. 역할 명확화

```markdown
---
description: 변경 영향 분석 — 코드 수정 전 의존성과 영향 범위 파악
capabilities: ["Read", "Grep", "Glob"]
---
```

### 2. Capabilities 최소화

필요한 도구만 명시합니다. 불필요한 도구는 보안 위험을 증가시킵니다.

```yaml
# ✅ Good: 분석만 수행하는 에이전트
capabilities: ["Read", "Grep", "Glob"]

# ❌ Bad: 불필요한 Write/Edit 포함
capabilities: ["Read", "Write", "Edit", "Grep", "Glob"]
```

### 3. 명확한 실행 흐름

단계별로 명확한 흐름을 정의합니다.

```markdown
## 실행 흐름

1. 입력 검증
2. 컨텍스트 로드
3. 분석 수행
4. 결과 구조화
5. 출력 반환
```

---

## 관련 문서

- [Skills 상세](./SKILLS.md) — 스킬과의 차이점
- [Workflows 상세](./WORKFLOWS.md) — 에이전트를 호출하는 워크플로우
- [Hooks 상세](./HOOKS.md) — 이벤트 기반 자동화
