# Workflows (Commands) 상세 문서

Claude Code의 **Workflows**는 슬래시 명령어(`/command`)로 호출되는 구조화된 작업 흐름입니다. HXSK(Get Shit Done) 방법론의 핵심 인터페이스를 제공합니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **소스** | `.hxsk/skills/*/SKILL.md`, `.hxsk/agents/*.md`, `.hxsk/workflow/GATES.md` |
| **배포 방식** | Self-Configure: `llms.txt` → `.hxsk/prompts/setup.md` → `install.sh --harness <name>` |
| **호출 방식** | 하네스별 스킬/에이전트 호출 (`/skill ...`, Task 위임, 또는 어댑터 명령) |
| **인자 전달** | `$ARGUMENTS` 변수로 전달 |

> **Note**: 과거 `scripts/build-*.sh` 기반 플러그인/보일러플레이트 생성 경로는 superseded 상태입니다. 현재 운영 경로는 레포 자체를 배포 단위로 두고 setup/install 스크립트가 각 하네스 표면을 수렴시키는 Self-Configure 모델입니다.

---

## 명령어 카테고리

### Core Workflow (5)

| 명령어 | 파일 | 역할 | 인자 |
|--------|------|------|------|
| `/map` | `map.md` | 코드베이스 분석 → ARCHITECTURE.md | - |
| `/plan` | `plan.md` | 페이즈 계획 생성 | `[N] [--research] [--skip-research] [--gaps]` |
| `/execute` | `execute.md` | 웨이브 기반 실행 | `<N> [--gaps-only]` |
| `/verify` | `verify.md` | 검증 + 증거 수집 | `[N]` |
| `/debug` | `debug.md` | 체계적 디버깅 | `[description]` |

### Project Setup (5)

| 명령어 | 파일 | 역할 | 인자 |
|--------|------|------|------|
| `/new-project` | `new-project.md` | 딥 질문 → SPEC.md | - |
| `/new-milestone` | `new-milestone.md` | 마일스톤 생성 | - |
| `/complete-milestone` | `complete-milestone.md` | 마일스톤 완료 처리 | - |
| `/audit-milestone` | `audit-milestone.md` | 마일스톤 품질 감사 | - |
| `/bootstrap` | `bootstrap.md` | 전체 프로젝트 부트스트랩 | - |

### Phase Management (7)

| 명령어 | 파일 | 역할 | 인자 |
|--------|------|------|------|
| `/add-phase` | `add-phase.md` | 로드맵 끝에 페이즈 추가 | - |
| `/insert-phase` | `insert-phase.md` | 특정 위치에 페이즈 삽입 | `<position>` |
| `/remove-phase` | `remove-phase.md` | 페이즈 제거 (안전 체크) | `<N>` |
| `/discuss-phase` | `discuss-phase.md` | 페이즈 범위 논의 | `[N]` |
| `/research-phase` | `research-phase.md` | 기술 리서치 | `[N]` |
| `/list-phase-assumptions` | `list-phase-assumptions.md` | 가정 목록화 | `[N]` |
| `/plan-milestone-gaps` | `plan-milestone-gaps.md` | 갭 분석 | - |

### Navigation & State (6)

| 명령어 | 파일 | 역할 | 인자 |
|--------|------|------|------|
| `/progress` | `progress.md` | 현재 진행 상황 | - |
| `/pause` | `pause.md` | 상태 저장 (full HXSK) | - |
| `/handoff` | `handoff.md` | 경량 핸드오프 문서 | - |
| `/resume` | `resume.md` | 마지막 세션 복원 | - |
| `/add-todo` | `add-todo.md` | TODO 추가 | `<description>` |
| `/check-todos` | `check-todos.md` | TODO 목록 확인 | - |

### Utilities (7)

| 명령어 | 파일 | 역할 | 인자 |
|--------|------|------|------|
| `/help` | `help.md` | 도움말 | - |
| `/quick-check` | `quick-check.md` | 빠른 상태 체크 | - |
| `/update` | `update.md` | HXSK 문서 업데이트 | - |
| `/web-search` | `web-search.md` | 웹 검색 | `<query>` |
| `/whats-new` | `whats-new.md` | 최근 변경사항 | - |
| `/feature-dev` | `feature-dev.md` | 기능 개발 워크플로우 | `<description>` |
| `/bug-fix` | `bug-fix.md` | 버그 수정 워크플로우 | `<description>` |

---

## Dispatcher v2: 병렬 작업 워크플로우

대규모 작업을 MASTER/WORK 마크다운 이슈로 분할하고, 워크트리에서 병렬 실행합니다.

```
PLAN.md/SPEC.md
  ↓ Phase 1: SPLIT
MASTER-{id}.md + WORK-{id}-{1..N}.md
  ↓ Phase 2: BRANCH
feat/master-{id}
  ↓ Phase 3-5: Wave Loop
  ┌─── Wave N ────────────────────┐
  │  DISPATCH → TRACK → MERGE    │
  │  (워크트리 병렬)  (상태 갱신) │
  └───────────────────────────────┘
  ↓ Phase 6: VERIFY → CLOSE
master 머지 (사용자 승인 후)
```

- **MASTER 문서**: 마스터플랜 (works, wave_plan, progress, merge log)
- **WORK 문서**: 개별 작업 (tasks, depends_on, files, side_effect_files)
- **오케스트레이터만 쓰기**: 서브에이전트는 `git worktree list`로 메인 루트 resolve 후 읽기 전용
- **이슈 문서**: `.hxsk/issues/` (git-untracked), 완료 후 `archive/`

상세: `.hxsk/skills/dispatcher/SKILL.md` (v2.0.0)

---

## 워크플로우 구조

### Frontmatter

```yaml
---
description: The Strategist — Decompose requirements into executable phases
argument-hint: "[phase] [--research] [--skip-research] [--gaps]"
---
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `description` | Yes | 워크플로우 역할 설명 |
| `argument-hint` | No | 인자 힌트 (help에 표시) |

### 본문 구조

```markdown
# /{command} Workflow

<role>
역할 정의
</role>

<objective>
목표
</objective>

<context>
필요한 컨텍스트
</context>

<process>
## 1. 단계 1
## 2. 단계 2
...
</process>

<offer_next>
완료 후 제안할 다음 단계
</offer_next>

<related>
관련 워크플로우 및 스킬
</related>
```

---

## 주요 워크플로우 상세

### /plan

**역할**: 실행 가능한 페이즈 계획 생성

**인자**:
- `[phase]`: 계획할 페이즈 번호 (생략 시 자동 감지)
- `--research`: 리서치 강제 재실행
- `--skip-research`: 리서치 건너뛰기
- `--gaps`: 갭 클로저 모드

**프로세스**:
```
1. 환경 검증 (Planning Lock: SPEC.md FINALIZED 확인)
2. 인자 파싱 및 정규화
3. 페이즈 검증
4. 페이즈 디렉토리 생성
5. 리서치 처리 (필요 시)
6. PLAN.md 파일 생성
7. 계획 검증 (Checker Logic)
8. 상태 업데이트
9. 커밋
10. 다음 단계 제안
```

**출력 예시**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HXSK ► PHASE 1 PLANNED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3 plans created across 2 waves

Plans:
• 1.1: Setup Database Schema (wave 1)
• 1.2: Create API Endpoints (wave 1)
• 1.3: Add Authentication (wave 2)

───────────────────────────────────────────────────────

▶ Next Up

/execute 1 — run all plans

───────────────────────────────────────────────────────
```

---

### /execute

**역할**: 페이즈의 모든 계획을 웨이브 기반으로 실행

**인자**:
- `<phase-number>`: 실행할 페이즈 번호 (필수)
- `--gaps-only`: 갭 클로저 계획만 실행

**프로세스**:
```
1. 환경 검증
2. 페이즈 존재 확인
3. 페이즈 디렉토리 생성
4. 계획 발견 (PLAN.md 파일 목록)
5. 웨이브별 그룹화
6. 웨이브 순차 실행
   6a. 각 계획 실행
   6b. 웨이브 완료 검증
   6c. 다음 웨이브 진행
7. 페이즈 목표 검증
8. 로드맵 및 상태 업데이트
9. 페이즈 완료 커밋
10. 다음 단계 제안
```

**웨이브 실행 흐름**:
```
Wave 1: [plan-1, plan-2]  ← 병렬 실행 가능
        │
        ▼ (완료 대기)
Wave 2: [plan-3]          ← Wave 1 완료 후 실행
        │
        ▼ (완료 대기)
Phase Verification
```

---

### /verify

**역할**: 실행된 작업을 spec 대비 검증

**프로세스**:
```
1. 페이즈 SUMMARY.md 파일 수집
2. SPEC.md의 must-haves 로드
3. 각 must-have 검증 (경험적 증거 수집)
4. VERIFICATION.md 생성
5. 갭 발견 시 갭 클로저 계획 생성
```

**검증 원칙**:
- 결과 우선: 기능 동작 확인 후 스타일 수정
- 실패 전수 보고: 모든 실패를 수집하여 보고
- 조건부 성공: 실제 결과 확인 후에만 성공 출력

---

### /debug

**역할**: 체계적 디버깅 + 3-strike rule

**프로세스**:
```
1. 증상 수집 및 재현
2. 가설 수립
3. 검증 시도 (최대 3회)
4. 3회 실패 시:
   - 상태 저장 (.hxsk/STATE.md)
   - fresh session 권장
```

**3-Strike Rule**:
```
시도 1 → 실패 → 다른 접근
시도 2 → 실패 → 웹 검색/문서 확인
시도 3 → 실패 → STOP + 상태 저장 + fresh session 권장
```

---

### /new-project

**역할**: 딥 질문을 통한 SPEC.md 생성

**딥 질문 흐름**:
```
1. "이 프로젝트로 무엇을 달성하려 하나요?"
2. "최종 사용자는 누구인가요?"
3. "성공을 어떻게 측정하나요?"
4. "반드시 해야 할 것 vs 하지 말아야 할 것?"
5. "기술적 제약이 있나요?"
```

**출력**: `.hxsk/SPEC.md` (Status: DRAFT → FINALIZED)

---

### /progress

**역할**: 현재 진행 상황 표시

**출력 예시**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HXSK ► PROGRESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: My App
Milestone: Milestone 1 (MVP)

───────────────────────────────────────────────────────

PHASES

✅ Phase 0: Project Setup — COMPLETE
🔄 Phase 1: Core Features — IN PROGRESS
⬜ Phase 2: Polish — TODO

Progress: 1/3 (33%)

───────────────────────────────────────────────────────

CURRENT TASK

Implementing user authentication

───────────────────────────────────────────────────────
```

---

## HXSK 사이클

```
┌─────────────────────────────────────────────────────────┐
│                     HXSK Cycle                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   /new-project                                          │
│        │                                                │
│        ▼                                                │
│   ┌─────────┐                                          │
│   │  SPEC   │  ← "무엇을 만들 것인가?"                  │
│   └────┬────┘                                          │
│        │                                                │
│        ▼                                                │
│   ┌─────────┐                                          │
│   │  PLAN   │  ← /plan N                               │
│   └────┬────┘                                          │
│        │                                                │
│        ▼                                                │
│   ┌─────────┐                                          │
│   │ EXECUTE │  ← /execute N                            │
│   └────┬────┘                                          │
│        │                                                │
│        ▼                                                │
│   ┌─────────┐                                          │
│   │ VERIFY  │  ← /verify N                             │
│   └────┬────┘                                          │
│        │                                                │
│        ├──── PASS ───▶ 다음 페이즈                     │
│        │                                                │
│        └──── FAIL ───▶ /execute N --gaps-only          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 워크플로우 간 관계

```
/new-project ─────▶ SPEC.md
      │
      ▼
/new-milestone ───▶ ROADMAP.md (phases 정의)
      │
      ▼
/map ─────────────▶ ARCHITECTURE.md
      │
      ▼
/plan N ──────────▶ .hxsk/phases/N/*-PLAN.md
      │
      ▼
/execute N ───────▶ .hxsk/phases/N/*-SUMMARY.md
      │
      ▼
/verify N ────────▶ .hxsk/phases/N/VERIFICATION.md
      │
      ├── PASS ──▶ /plan N+1
      │
      └── FAIL ──▶ /execute N --gaps-only
```

---

## 인자 처리

### $ARGUMENTS 변수

워크플로우에 전달된 인자는 `$ARGUMENTS` 변수로 접근합니다.

```markdown
<context>
**Phase number:** $ARGUMENTS (optional)
</context>
```

### 플래그 파싱

```markdown
## 2. Parse and Normalize Arguments

Extract from $ARGUMENTS:
- Phase number (integer)
- `--research` flag
- `--skip-research` flag
- `--gaps` flag
```

---

## 출력 형식

### 배너

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HXSK ► {COMMAND} {STATUS}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 구분선

```
───────────────────────────────────────────────────────
```

### 다음 단계 제안

```markdown
▶ Next Up

/execute 1 — run all plans
/verify 1  — validate execution
```

---

---

## Git Forge 통합 작업 관리 (Gate-based Workflow)

SPEC→PLAN→EXECUTE→VERIFY 각 단계에 게이트 조건을 부여하고,
GitHub/GitLab/Gitea/Forgejo 이슈·PR·Worktree와 연동합니다.

### 3-레이어 책임 분리

```
HOP 1: GATES      → 조건 & 플랫폼 연동  (진행해도 되는가?)
HOP 2: Dispatcher → 실행 엔진           (어떻게 병렬 실행?)
HOP 3: Sub-agent  → 작업 실행           (파일을 어떻게 변경?)
```

각 레이어는 인접 레이어 내부를 모름. STATE.md + `.hxsk/issues/`로만 통신.

### 멀티홉 흐름 (요약)

```
GATES:      GATE-0 → P1(브랜치) → P2(부모이슈) → P3(소유권맵) → P4(하위이슈)
            [HOP 1→2] PLAN.md 경로 + 소유권 맵 전달
Dispatcher: WORK 분해 → Wave 배정 → 워크트리 생성
            [HOP 2→3] WORK 문서 경로만 전달
Sub-agent:  코드 변경 → 커밋 → Self-review → 요약 반환
Dispatcher: 머지 → [HOP 2→1] PR 번호 목록 반환
GATES:      GATE-V0 → VERIFY → 부모 PR → GATE-D0 → 보고서
```

### 토큰 최적화 (핸드오프 시 경로/요약만 전달)

| 핸드오프 | 전달 | 금지 |
|----------|------|------|
| HOP 1→2 | PLAN.md 경로, 소유권 맵 | 대화 내역, 이슈 내용 |
| HOP 2→3 | WORK 문서 경로 | Dispatcher 컨텍스트, 파일 내용 |
| HOP 3→2 | 요약 테이블 | 전체 구현 설명 |

전체 세션 **~60-75% 절감** 추정

### 플랫폼 추상화

`forge-detect.sh`: `github.com → gh` / `gitlab.* → glab` / `gitea/forgejo → tea`

> 상세: [설계 문서 v2](plans/2026-04-15-github-task-management-design.md)
> 리서치: [workflow/](../research/workflow/)

---

## 관련 문서

- [Skills 상세](./SKILLS.md) — 워크플로우가 호출하는 스킬
- [Agents 상세](./AGENTS.md) — 워크플로우가 위임하는 에이전트
- [Hooks 상세](./HOOKS.md) — 이벤트 기반 자동화
- [Git Forge 작업 관리 설계](./plans/2026-04-15-github-task-management-design.md) — Gate 기반 워크플로우
- [GitHub Workflow (deprecated)](./GITHUB-WORKFLOW.md) — v1.11.1 이전 CI/CD 참고 (현재 미사용)
