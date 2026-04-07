# Superpowers Plugin 분석 및 HXSK 적용 리서치

> 조사일: 2026-04-07
> 대상: superpowers v5.0.7 (Jesse Vincent / obra)
> 목적: 구성과 구현 방식 분석, HXSK 프로젝트 적용 가능 항목 도출

---

## 1. Superpowers 개요

| 항목 | 내용 |
|------|------|
| 저자 | Jesse Vincent (obra) |
| 라이선스 | MIT |
| GitHub | github.com/obra/superpowers |
| 버전 | 5.0.7 |
| Stars | ~138k |
| 지원 플랫폼 | Claude Code, Cursor, Copilot, Gemini, Codex |

**핵심 철학**: AI 에이전트가 "대충 넘어가는" 경향을 방지하기 위해, 심리학 기반 설득 기법(Cialdini 2021, Meincke et al. 2025)과 엄격한 게이트 함수를 결합한 규율 강제(discipline-enforcing) 스킬 프레임워크.

---

## 2. 플러그인 구조

```
superpowers/
├── .claude-plugin/
│   └── plugin.json          # Claude Code 등록
├── .cursor-plugin/
│   └── plugin.json          # Cursor 등록 (skills/, agents/, commands/, hooks 경로 명시)
├── skills/
│   ├── using-superpowers/SKILL.md
│   ├── brainstorming/SKILL.md
│   │   ├── visual-companion.md
│   │   └── spec-document-reviewer-prompt.md
│   ├── writing-plans/SKILL.md
│   │   └── plan-document-reviewer-prompt.md
│   ├── executing-plans/SKILL.md
│   ├── subagent-driven-development/SKILL.md
│   │   ├── implementer-prompt.md
│   │   ├── spec-reviewer-prompt.md
│   │   └── code-quality-reviewer-prompt.md
│   ├── test-driven-development/SKILL.md
│   │   └── testing-anti-patterns.md
│   ├── systematic-debugging/SKILL.md
│   │   ├── root-cause-tracing.md
│   │   ├── defense-in-depth.md
│   │   └── condition-based-waiting.md
│   ├── requesting-code-review/SKILL.md
│   │   └── code-reviewer.md
│   ├── receiving-code-review/SKILL.md
│   ├── verification-before-completion/SKILL.md
│   ├── using-git-worktrees/SKILL.md
│   ├── finishing-a-development-branch/SKILL.md
│   ├── dispatching-parallel-agents/SKILL.md
│   └── writing-skills/SKILL.md
│       ├── anthropic-best-practices.md
│       ├── persuasion-principles.md
│       └── testing-skills-with-subagents.md
├── agents/
│   └── code-reviewer.md
└── commands/                 # deprecated → skill로 전환
    ├── brainstorm.md
    ├── write-plan.md
    └── execute-plan.md
```

---

## 3. 핵심 워크플로우 체인

```
brainstorming → using-git-worktrees → writing-plans
    → [subagent-driven-development | executing-plans]
        → test-driven-development (매 태스크)
        → requesting-code-review (태스크 간)
    → finishing-a-development-branch
```

**크로스커팅 스킬** (워크플로우 전반에 걸쳐 적용):
- `systematic-debugging` — 버그 발생 시
- `verification-before-completion` — 완료 선언 전
- `dispatching-parallel-agents` — 독립 작업 병렬화
- `receiving-code-review` — 리뷰 피드백 수신 시

---

## 4. 14개 스킬 상세

### 4.1 using-superpowers (메타 스킬)

- **역할**: 대화 시작 시 로드, 스킬 탐색·적용 규칙 확립
- **핵심 규칙**: "1%라도 적용 가능성이 있으면 반드시 스킬 호출"
- **합리화 테이블**: 12개 항목 ("단순한 질문이라", "먼저 코드 탐색해야" 등)
- **우선순위**: 프로세스 스킬(brainstorming, debugging) → 구현 스킬(TDD, frontend)
- **스킬 유형**: Rigid(TDD, debugging — 정확히 따름) vs Flexible(패턴 — 원칙 적용)

### 4.2 brainstorming

- **트리거**: 기능 생성, 컴포넌트 빌드, 행동 수정 등 모든 창작 작업 전
- **게이트**: 설계 승인 전 구현 스킬 호출/코드 작성 금지
- **9단계**: 컨텍스트 탐색 → 시각적 동반자 제안 → 질문(한 번에 하나, 객관식) → 2-3 접근법 + 트레이드오프 → 섹션별 설계 승인 → 스펙 문서 작성(`docs/superpowers/specs/`) → 자기 검토 → 사용자 검토 → writing-plans 호출
- **원칙**: YAGNI, 한 번에 한 질문, 대안 탐색(2-3개), 점진적 검증

### 4.3 writing-plans

- **트리거**: 스펙/요구사항이 있고 멀티스텝 구현 전
- **핵심**: "코드베이스 컨텍스트 제로 + 취향 의심스러운 엔지니어"를 위해 작성
- **태스크 단위**: 2-5분, 하나의 액션 (테스트 작성 → 실행 → 구현 → 검증 → 커밋)
- **플레이스홀더 금지**: "TBD", "TODO", "적절한 에러 핸들링 추가", "Task N과 유사" 모두 실패
- **출력**: `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`

### 4.4 executing-plans

- **트리거**: 작성된 계획을 별도 세션에서 실행
- **3단계**: 계획 로드·비판적 검토 → 태스크 순차 실행(진행 추적) → finishing 호출
- **중단 조건**: 블로커, 크리티컬 갭, 지시 불명확, 검증 반복 실패

### 4.5 test-driven-development

- **Iron Law**: `테스트 실패 없이 프로덕션 코드 없음`
- **Red-Green-Refactor**: 실패 테스트 작성 → 실패 확인(필수) → 최소 구현 → 통과 확인(필수) → 리팩터
- **테스트 전 코드 작성 시**: 삭제. "참고용 보관" 금지, "적응" 금지, "보지도 마라"
- **합리화 테이블**: 11개 ("테스트하기엔 너무 단순", "나중에 테스트", "TDD가 느리다" 등)
- **보조 문서**: testing-anti-patterns.md (5개 안티패턴 + Gate Function 패턴)

### 4.6 systematic-debugging

- **Iron Law**: `근본 원인 조사 없이 수정 없음`
- **4단계**: 근본 원인 조사(필수 완료) → 패턴 분석 → 가설·테스트 → 구현
- **3회 실패 규칙**: 3회 이상 수정 실패 시 아키텍처 문제 의심, 인간과 논의
- **보조 문서**: root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md
- **통계**: 체계적 접근 15-30분 vs 무작위 수정 2-3시간, 첫 시도 성공률 95% vs 40%

### 4.7 subagent-driven-development

- **트리거**: 독립 태스크가 있는 구현 계획 실행
- **프로세스**: 태스크별 새 서브에이전트 → 구현 → 2단계 리뷰(스펙 준수 → 코드 품질)
- **모델 선택**: 기계적 작업(저비용) / 통합 작업(표준) / 아키텍처·리뷰(최고 모델)
- **컨텍스트 격리**: 서브에이전트에 계획 파일 읽기 시키지 않고, 컨트롤러가 필요 정보만 구성

### 4.8 dispatching-parallel-agents

- **트리거**: 공유 상태 없는 2+ 독립 작업
- **4단계**: 독립 도메인 식별 → 포커스된 에이전트 태스크 생성 → 병렬 디스패치 → 통합 검증
- **금지 상황**: 관련 실패, 탐색적 디버깅, 공유 상태

### 4.9 requesting-code-review

- **트리거**: 태스크 완료 후, 주요 기능 구현 후, 머지 전
- **프로세스**: BASE_SHA/HEAD_SHA 확보 → code-reviewer 서브에이전트 디스패치 → 피드백 처리
- **심각도**: Critical(즉시 수정) / Important(진행 전 수정) / Minor(나중 기록)

### 4.10 receiving-code-review

- **트리거**: 코드 리뷰 피드백 수신 시
- **핵심**: 기술적 정확성 > 사회적 편안함. **검증 후 구현**
- **금지 응답**: "You're absolutely right!", "Great point!", 감사 표현
- **올바른 응답**: "Fixed. [간략 설명]" 또는 코드로 직접 수정
- **출처별 처리**: 인간 파트너(신뢰, 즉시 구현) / 외부 리뷰어(5단계 검증 후 구현)

### 4.11 using-git-worktrees

- **트리거**: 격리 필요한 기능 작업 시작 또는 구현 계획 실행 전
- **디렉토리 선택**: `.worktrees/` > CLAUDE.md 설정 > 사용자 질문
- **안전 검증**: .gitignore 포함 확인 필수 → 미포함 시 추가·커밋 후 진행
- **설정 자동 감지**: npm/cargo/pip/poetry/go 등

### 4.12 finishing-a-development-branch

- **트리거**: 구현 완료, 테스트 통과, 통합 방법 결정 필요
- **5단계**: 테스트 통과 확인 → 베이스 브랜치 결정 → 4개 옵션 제시(로컬 머지/PR/유지/폐기) → 실행 → 워크트리 정리
- **폐기 시**: "discard" 타이핑 확인 필수

### 4.13 verification-before-completion

- **Iron Law**: `검증 증거 없이 완료 선언 없음`
- **게이트 함수 5단계**: IDENTIFY(증명 명령) → RUN(전체 실행) → READ(전체 출력) → VERIFY(주장 확인) → CLAIM
- **기원**: 24건의 실패 메모리 — 인간이 "믿을 수 없다" 발언 후 신뢰 손상

### 4.14 writing-skills

- **Iron Law**: `실패 테스트 없이 스킬 없음`
- **TDD 매핑**: 테스트 케이스=압박 시나리오, 프로덕션 코드=SKILL.md, RED=스킬 없이 에이전트 규칙 위반, GREEN=스킬 있으면 준수
- **CSO (Claude Search Optimization)**: description에 트리거 조건만 기재, 워크플로우 요약 금지. 이유: 요약 포함 시 에이전트가 전체 스킬을 읽지 않고 description만 따름
- **설득 기법**: Authority + Commitment + Scarcity + Social Proof 사용, Liking(아첨 유발)·Reciprocity(조작적) 회피

---

## 5. 핵심 설계 패턴 10가지

### 5.1 Iron Laws (밝은 선 규칙)

`NO X WITHOUT Y FIRST` 형식의 비타협 규칙. 4개:
- TDD: 실패 테스트 없이 코드 없음
- Debugging: 근본 원인 없이 수정 없음
- Verification: 증거 없이 완료 없음
- Writing-skills: 실패 테스트 없이 스킬 없음

### 5.2 합리화 테이블 (Rationalization Tables)

`| 변명 | 현실 |` 포맷으로 에이전트의 실제 합리화 패턴을 포착·차단. 5개 스킬에서 총 49개 항목 사용.

### 5.3 CSO (Claude Search Optimization)

description = 트리거 조건만. 워크플로우 요약 포함 시 에이전트가 스킬 본문을 건너뜀. 테스트에서 발견된 패턴.

### 5.4 게이트 함수 (Gate Functions)

다음 단계 진행 전 필수 검증 체크포인트. TDD의 RED/GREEN 검증, verification의 5단계 게이트 등.

### 5.5 Graphviz 플로우차트

비자명한 결정 포인트와 프로세스 루프에만 사용. 레퍼런스, 코드 예시, 선형 지시에는 금지.

### 5.6 2단계 리뷰

스펙 준수 리뷰(요청한 걸 만들었나?) → 코드 품질 리뷰(잘 만들었나?). 순서 강제.

### 5.7 서브에이전트 컨텍스트 격리

서브에이전트는 세션 컨텍스트를 상속하지 않음. 컨트롤러가 필요 정보만 프롬프트 템플릿으로 구성. 컨트롤러 컨텍스트 보호 + 서브에이전트 집중.

### 5.8 크로스 스킬 의존성

- `REQUIRED SUB-SKILL: Use superpowers:X` — 실행 중 호출 필수
- `REQUIRED BACKGROUND: You MUST understand superpowers:X` — 전제 지식
- `@` 링크 사용 금지 (강제 로드 → 200k+ 컨텍스트 소비)

### 5.9 설득 기법 (Persuasion Principles)

Cialdini 6원칙 중 4개 선별 적용:
- **Authority**: MUST, NEVER, NO EXCEPTIONS
- **Commitment**: 선언, TodoWrite 추적, 명시적 선택
- **Scarcity**: "BEFORE proceeding", "IMMEDIATELY after"
- **Social Proof**: "Every time", "Always"
- **회피**: Liking(아첨 생성), Reciprocity(조작적)

### 5.10 Red Flags 목록

각 규율 스킬에 "STOP" 시그널 목록. 에이전트가 해당 사고 패턴을 감지하면 즉시 중단·프로세스 복귀.

---

## 6. HXSK 현황 대비 분석

### 6.1 HXSK 현재 구조

| 항목 | HXSK | Superpowers |
|------|------|-------------|
| 스킬 수 | 19 | 14 |
| 에이전트 수 | 17 | 1 (code-reviewer) |
| 스킬 구조 | YAML frontmatter + Quick Reference + 섹션 | YAML frontmatter + Overview + 섹션 + 보조 문서 |
| 트리거 방식 | 에이전트가 스킬 참조 (Agent-Skill 래핑) | description 기반 자동 매칭 |
| 문서 계층 | L1(CLAUDE.md) → L2(SKILL.md) → L3(research/) | SKILL.md + 보조 .md |
| 워크플로우 체인 | SPEC → PLAN → EXECUTE → VERIFY | brainstorm → plan → execute → finish |
| 메모리 시스템 | 14타입 파일 기반 (A-Mem 확장) | 없음 (세션 단위) |
| 검증 철학 | "경험적 증거 기반" | "Iron Laws + Gate Functions" |
| 3-Strike Rule | 있음 | systematic-debugging에 유사 규칙 |

### 6.2 HXSK의 강점 (Superpowers에 없는 것)

1. **파일 기반 메모리 시스템**: 14타입 온톨로지, 2-hop 검색, 세션 간 지속
2. **풍부한 에이전트 생태계**: 17개 전문 에이전트 (planner, executor, reviewer, clean, dispatcher 등)
3. **부트스트랩 수렴 엔진**: fresh/verify/update 모드 자동 감지
4. **CI 정합성 검증**: consistency check + pre-PR check 자동화
5. **멀티 에이전트 플랫폼 지원 문서**: CLAUDE.md, GEMINI.md, AGENTS.md 분리

### 6.3 Superpowers의 강점 (HXSK에 없는 것)

1. **합리화 방지 체계**: 49개 합리화 테이블 항목, Red Flags 목록
2. **Iron Laws**: 명시적 비타협 규칙 4개
3. **CSO 패턴**: description 최적화로 스킬 로딩 실패 방지
4. **2단계 리뷰**: 스펙 준수 → 코드 품질 분리
5. **스킬 TDD**: 스킬 자체를 테스트 주도로 개발
6. **게이트 함수**: 각 단계 전 필수 검증 체크포인트
7. **설득 기법 연구 기반**: 학술 연구(N=28,000) 기반 기법 선별
8. **보조 문서 시스템**: 스킬당 2-3개 심화 문서 (프롬프트 템플릿, 기법 가이드)
9. **서브에이전트 프롬프트 템플릿**: 구조화된 서브에이전트 지시 양식

---

## 7. HXSK 적용 권장 사항

### 7.1 즉시 적용 (높은 ROI, 낮은 공수)

#### A. CSO 패턴 적용 — 스킬/에이전트 description 최적화

**현황**: HXSK 스킬 description이 워크플로우 요약을 포함하는 경우 있음
**적용**: description에 트리거 조건만 기재, 워크플로우 설명 제거
**이유**: 에이전트가 description만 보고 스킬 본문을 건너뛰는 패턴 방지
**공수**: 기존 19개 스킬 description 검토·수정 (1-2시간)

```markdown
# Before
description: "메모리를 저장하고 검색하는 프로토콜. 2-hop 검색과 14타입 분류를 지원"

# After  
description: "Use when storing or retrieving project knowledge, after architecture decisions, bug fixes, or session ends"
```

#### B. 합리화 테이블 추가 — 핵심 규율 스킬에

**대상 스킬**: validation, session-management, memory-protocol
**적용**: `| 변명 | 현실 |` 포맷으로 에이전트의 실제 우회 패턴 기록
**효과**: 에이전트의 규칙 우회 감소 (연구 기반 33% → 72% 준수율)

#### C. Iron Laws 명시 — AGENTS.md Validation 섹션

**현황**: "경험적 증거 기반", "잘 되는 것 같다는 증거가 아님" (원칙은 있으나 Iron Law 수준 아님)
**적용**:
```markdown
## Iron Laws
- NO COMPLETION CLAIMS WITHOUT RUNNING VERIFICATION COMMANDS
- NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
- NO TASK SKIP WITHOUT 3-STRIKE EVIDENCE
```

### 7.2 중기 적용 (중간 ROI, 중간 공수)

#### D. 게이트 함수 패턴 — 기존 검증 프로세스 강화

**현황**: HXSK에 "결과 우선", "조건부 성공" 원칙이 있으나 구조화된 게이트 없음
**적용**: 5단계 게이트 (IDENTIFY → RUN → READ → VERIFY → CLAIM)를 validation 스킬에 추가
**효과**: "잘 돌아가는 것 같다" 식의 완료 선언 원천 차단

#### E. 보조 문서 시스템 — 스킬 심화 내용 분리

**현황**: HXSK 스킬은 SKILL.md 단일 파일. 복잡한 스킬은 비대해지거나 내용이 부족
**적용**: 스킬 디렉토리 내 보조 .md 파일 추가 (프롬프트 템플릿, 기법 가이드, 안티패턴)
**구조**:
```
.hxsk/skills/memory-protocol/
├── SKILL.md              # 핵심 규칙 + Quick Reference
├── search-techniques.md  # 2-hop 검색 상세
└── storage-triggers.md   # 저장 트리거 목록 + 예시
```

#### F. 2단계 리뷰 패턴 — reviewer 에이전트 분리

**현황**: 단일 reviewer 에이전트
**적용**: spec-reviewer(스펙 준수) + code-reviewer(코드 품질) 분리, 순서 강제
**효과**: "코드는 깔끔한데 요구사항을 안 지킨" 케이스 조기 발견

### 7.3 장기 적용 (높은 ROI, 높은 공수)

#### G. 스킬 TDD — 스킬 자체를 테스트 주도로 개발

**현황**: 스킬은 수동 작성·검증
**적용**: 서브에이전트에 "스킬 없이" 압박 시나리오 실행 → 실패 패턴 기록 → 스킬 작성 → 재실행 → 통과 확인
**효과**: 스킬이 실제로 에이전트 행동을 바꾸는지 검증 가능
**참고**: writing-skills의 testing-skills-with-subagents.md

#### H. 서브에이전트 프롬프트 템플릿 표준화

**현황**: 에이전트 정의는 있으나 서브에이전트 호출 시 프롬프트 구조가 비표준
**적용**: implementer-prompt.md, reviewer-prompt.md 등 표준 템플릿 도입
**효과**: 서브에이전트 품질 안정화, 컨텍스트 격리 보장

---

## 8. 적용 우선순위 매트릭스

| 순위 | 항목 | ROI | 공수 | 선행 조건 |
|------|------|-----|------|-----------|
| 1 | A. CSO 패턴 | 높음 | 낮음 | 없음 |
| 2 | C. Iron Laws | 높음 | 낮음 | 없음 |
| 3 | B. 합리화 테이블 | 높음 | 낮음 | 실제 우회 패턴 수집 필요 |
| 4 | D. 게이트 함수 | 중간 | 중간 | validation 스킬 존재 |
| 5 | E. 보조 문서 | 중간 | 중간 | 스킬 비대화 시점 |
| 6 | F. 2단계 리뷰 | 중간 | 중간 | reviewer 에이전트 존재 |
| 7 | G. 스킬 TDD | 높음 | 높음 | writing-skills 참조 |
| 8 | H. 프롬프트 템플릿 | 중간 | 높음 | 에이전트 생태계 성숙 |

---

## 9. 적용하지 않을 항목 (HXSK에 불필요)

| Superpowers 항목 | 미적용 이유 |
|-----------------|-------------|
| Git worktree 관리 | HXSK에 이미 워크트리 스크립트 존재 |
| brainstorming 9단계 | HXSK의 SPEC → PLAN 워크플로우가 동일 역할 |
| writing-plans 문서 구조 | HXSK의 PLAN.md 체계와 중복 |
| 설득 기법 직접 구현 | 합리화 테이블과 Iron Laws로 핵심 효과 확보 가능 |
| Slash commands | HXSK는 에이전트 기반 트리거 (Agent-Skill 래핑) |

---

## 10. 참고 자료

- GitHub: github.com/obra/superpowers
- 설득 기법 연구: Meincke et al. (2025), N=28,000
- Cialdini 6원칙: Authority, Commitment, Social Proof, Scarcity, (회피: Liking, Reciprocity)
- 로컬 경로: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
