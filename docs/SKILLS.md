# Skills 상세 문서

Claude Code의 **Skills**는 Claude가 작업 컨텍스트를 기반으로 **자율적으로 호출**하는 전문 기능입니다. 메인 대화 컨텍스트에서 실행되며, 가벼운 전문 기능을 제공합니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **위치** | `.claude/skills/*/SKILL.md` |
| **개수** | 16개 |
| **호출 방식** | Claude가 작업 컨텍스트 기반으로 자율적 결정 |
| **컨텍스트** | 메인 대화에서 실행 (컨텍스트 공유) |

---

## 스킬 목록

### 핵심 워크플로우 스킬

| Skill | 디렉토리 | 역할 | 트리거 상황 |
|-------|----------|------|-------------|
| `planner` | `planner/` | 실행 가능한 페이즈 계획 생성 | 계획 수립 요청 시 |
| `plan-checker` | `plan-checker/` | 계획 검증 (6차원 분석) | 계획 생성 후 |
| `executor` | `executor/` | 계획 실행 + atomic commits | `/execute` 실행 시 |
| `verifier` | `verifier/` | spec 대비 검증 + 증거 수집 | `/verify` 실행 시 |
| `debugger` | `debugger/` | 체계적 디버깅 | 버그 조사 시 |
| `bootstrap` | `bootstrap/` | 프로젝트 초기 설정 | 부트스트랩 요청 시 |

### 분석 스킬

| Skill | 디렉토리 | 역할 | 트리거 상황 |
|-------|----------|------|-------------|
| `impact-analysis` | `impact-analysis/` | 변경 영향 분석 | 코드 수정 전 |
| `arch-review` | `arch-review/` | 아키텍처 규칙 검증 | 구조 변경 시 |
| `codebase-mapper` | `codebase-mapper/` | 코드베이스 구조 분석 | 온보딩/리팩토링 전 |
| `context-health-monitor` | `context-health-monitor/` | 컨텍스트 복잡도 모니터링 | 긴 세션 중 |
| `empirical-validation` | `empirical-validation/` | 경험적 증거 요구 | 완료 확인 시 |

### Git/PR 스킬

| Skill | 디렉토리 | 역할 | 트리거 상황 |
|-------|----------|------|-------------|
| `commit` | `commit/` | conventional commit 생성 | 커밋 요청 시 |
| `create-pr` | `create-pr/` | PR 생성 (gh CLI) | PR 요청 시 |
| `pr-review` | `pr-review/` | 다중 페르소나 코드 리뷰 | PR 리뷰 요청 시 |

### 유틸리티 스킬

| Skill | 디렉토리 | 역할 | 트리거 상황 |
|-------|----------|------|-------------|
| `clean` | `clean/` | 코드 품질 도구 실행 (shellcheck) | 품질 체크 요청 시 |
| `memory-protocol` | `memory-protocol/` | 메모리 검색/저장 프로토콜 | 메모리 작업 시 |

---

## 스킬 구조

### 디렉토리 구조

```
.claude/skills/
├── planner/
│   ├── SKILL.md          # 스킬 정의 (필수)
│   └── scripts/          # 보조 스크립트 (선택)
│       └── assess_discovery_level.py
├── executor/
│   ├── SKILL.md
│   └── scripts/
│       └── parse_plan.py
└── ...
```

### SKILL.md Frontmatter

```yaml
---
name: executor
description: Executes GSD plans with atomic commits, deviation handling, checkpoint protocols, and state management
---
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | Yes | 스킬 식별자 |
| `description` | Yes | 스킬 역할 설명 (Claude가 트리거 결정에 사용) |

---

## 주요 스킬 상세

### Executor Skill

**역할**: PLAN.md 실행 + atomic commits + deviation handling

**주요 기능**:
- 태스크별 순차 실행
- 이탈 규칙 적용 (Rule 1-4)
- 체크포인트 처리
- SUMMARY.md 생성
- memory-graph에 deviation 기록

**Deviation Rules**:

```
Rule 1: 버그 발견 → 자동 수정
Rule 2: 누락된 필수 기능 → 자동 추가
Rule 3: 차단 이슈 → 자동 해결 시도
Rule 4: 아키텍처 변경 → 사용자 승인 요청 (STOP)
```

**Memory Integration** (파일 기반):
```bash
# 실행 전 과거 deviation 검색
bash .claude/hooks/md-recall-memory.sh "deviation" "." 5 compact

# deviation 발생 시 저장
bash .claude/hooks/md-store-memory.sh \
  "Rule {N} - {description}" \
  "{details}" \
  "deviation,rule-{N},{phase-plan}" \
  "deviation"
```

---

### Planner Skill

**역할**: 실행 가능한 페이즈 계획 생성

**핵심 철학**:

1. **Plans Are Prompts**: PLAN.md는 문서가 아니라 실행 프롬프트
2. **Quality Degradation Curve**: 50% 컨텍스트 내 완료 목표
3. **Aggressive Atomicity**: 플랜당 2-3 태스크 max

**Context Budget**:

| 컨텍스트 사용량 | 품질 | 상태 |
|-----------------|------|------|
| 0-30% | PEAK | 철저하고 종합적 |
| 30-50% | GOOD | 자신감 있는 작업 |
| 50-70% | DEGRADING | 효율 모드 시작 |
| 70%+ | POOR | 서두르고 최소화 |

**Task Anatomy**:
```xml
<task type="auto">
  <name>{Task name}</name>
  <files>{exact file paths}</files>
  <action>
    {Specific instructions}
    AVOID: {common mistake} because {reason}
  </action>
  <verify>{command to prove complete}</verify>
  <done>{measurable criteria}</done>
</task>
```

---

### Commit Skill

**역할**: conventional commit 생성

**커밋 메시지 형식**:
```
<type>(<scope>): <description>

[optional body]

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Type 목록**:
- `feat`: 새 기능
- `fix`: 버그 수정
- `docs`: 문서
- `refactor`: 리팩토링
- `test`: 테스트
- `chore`: 기타

---

### Impact-Analysis Skill

**역할**: 코드 수정 전 영향 범위 분석

**분석 항목**:
1. 직접 의존성 (imports, calls)
2. 역의존성 (이 코드를 사용하는 곳)
3. 테스트 커버리지
4. API 계약 영향

**네이티브 도구 활용**:
```bash
# Grep으로 의존성 검색
Grep(pattern: "import.*{file}", path: "src/")

# Glob으로 관련 파일 찾기
Glob(pattern: "**/*{module}*.py")
```

---

### Empirical-Validation Skill

**역할**: 경험적 증거 요구 — "잘 되는 것 같다"는 증거가 아님

**원칙**:
- 결과 우선: 기능 동작 확인 후 스타일 수정
- 실패 전수 보고: 모든 실패 수집하여 보고
- 조건부 성공: 실제 결과 확인 후에만 성공 출력
- 무조건적 "All tests passed!" 금지

---

## 스킬 작동 원리

### 자율적 호출 흐름

```
┌─────────────────────────────────────────────────┐
│  User: "이 기능 구현해줘"                        │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  Claude: 작업 컨텍스트 분석                      │
│  → impact-analysis 스킬 자동 호출               │
│  → 영향 범위 파악 후 구현 시작                   │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  구현 완료 후                                    │
│  → commit 스킬 자동 호출                         │
│  → conventional commit 생성                     │
└─────────────────────────────────────────────────┘
```

### 트리거 메커니즘

Claude는 `description` 필드를 기반으로 적절한 스킬 호출을 결정합니다.

```yaml
# 이 description이 트리거 조건으로 사용됨
description: Analyzes change impact before code modifications to prevent regression
```

**트리거 예시**:
- "코드 수정 전" → `impact-analysis`
- "커밋해줘" → `commit`
- "PR 만들어줘" → `create-pr`

---

## Scripts 디렉토리

일부 스킬은 보조 스크립트를 포함합니다.

### planner/scripts/assess_discovery_level.py

```python
"""
Discovery 레벨 (0-3) 평가

Usage:
    python assess_discovery_level.py "phase description"

Output: JSON
    {"level": 2, "reason": "New external API integration"}
"""
```

### executor/scripts/parse_plan.py

```python
"""
PLAN.md 파싱 → 태스크 JSON 추출

Usage:
    python parse_plan.py path/to/PLAN.md

Output: JSON
    {"tasks": [...], "wave": 1, "phase": 1}
"""
```

---

## Skills vs Agents 비교

| 구분 | Skills | Agents |
|------|--------|--------|
| **정의 위치** | `.claude/skills/*/SKILL.md` | `.claude/agents/*.md` |
| **호출 방식** | Claude가 자율적으로 결정 | Task 도구로 명시적 호출 |
| **컨텍스트** | 메인 대화에서 실행 | 별도 서브프로세스 |
| **용도** | 가벼운 전문 기능 | 복잡한 멀티스텝 작업 |
| **상태 유지** | 메인 대화 컨텍스트 공유 | 독립적 컨텍스트 |
| **복잡도** | 단일 작업 | 여러 단계의 워크플로우 |

---

## 스킬 작성 가이드

### 1. 명확한 트리거 조건

```yaml
# ✅ Good: 구체적인 트리거 조건
description: Creates executable phase plans with task breakdown, dependency analysis, and goal-backward verification

# ❌ Bad: 모호한 설명
description: Helps with planning
```

### 2. 역할 문서화

`<role>` 태그로 스킬의 역할을 명확히 정의합니다.

```markdown
<role>
You are a GSD executor. You execute PLAN.md files atomically, creating per-task commits, handling deviations automatically.
</role>
```

---

## 관련 문서

- [Agents 상세](./AGENTS.md) — 에이전트와의 차이점
- [Workflows 상세](./WORKFLOWS.md) — 스킬을 호출하는 워크플로우
- [Hooks 상세](./HOOKS.md) — 이벤트 기반 자동화
