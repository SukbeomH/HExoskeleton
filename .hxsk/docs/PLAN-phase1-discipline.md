# Phase 1: 규율 강화 — 설계 문서

> 작성일: 2026-04-07
> 상태: 설계 완료, 구현 대기
> 근거: superpowers-analysis.md, superpowers-references.md, claude-code-quality-mitigation.md

---

## 1. 목표

에이전트의 규칙 우회·허위 완료·읽기 건너뛰기를 **프롬프트 + 인프라 이중 방어**로 차단.
GitHub #42796에서 보고된 6가지 품질 저하 문제 중 4가지를 완화.

---

## 2. 설계 원칙

HXSK 기존 아키텍처에 자연스럽게 녹이는 것을 최우선으로 한다.

| 원칙 | 의미 | 적용 |
|------|------|------|
| **L1은 정책, L2는 절차** | AGENTS.md = 제약/트리거만, SKILL.md = 상세 절차 | Iron Laws → AGENTS.md, 합리화 테이블 → SKILL.md |
| **Skill = How, Agent = When** | 새 에이전트 불필요, 기존 스킬 확장 | `empirical-validation` 스킬에 게이트+합리화 통합 |
| **짧을수록 정확** | CLAUDE.md ≤120줄, 에이전트 ~20-30줄 | Ultrathink은 CLAUDE.md 3줄 + 스킬 위임 |
| **프롬프트 + 인프라** | 프롬프트만으로는 thinking 부족 시 무시됨 | PreToolUse/Stop 훅으로 이중 방어 |

---

## 3. 스코프 (7개 항목)

### 프롬프트 레벨 (5개)

| # | 항목 | 배치 | 신규/확장 |
|---|------|------|----------|
| 1 | Iron Laws 3개 | AGENTS.md Validation 섹션 | 확장 |
| 2 | 합리화 테이블 | empirical-validation SKILL.md | 확장 |
| 3 | Gate Function 5단계 | empirical-validation SKILL.md | 확장 |
| 4 | Ultrathink 트리거 | CLAUDE.md 참조 + empirical-validation 상세 | 확장 |
| 5 | CSO description 최적화 | 19개 SKILL.md description 필드 | 수정 |

### 인프라 레벨 (2개)

| # | 항목 | 배치 | 신규/확장 |
|---|------|------|----------|
| 6 | Read-before-Edit 훅 | PreToolUse 훅 (신규 스크립트) | 신규 |
| 7 | 완료 검증 게이트 훅 | Stop 훅 (post-turn-verify.sh 확장) | 확장 |

---

## 4. 항목별 상세 설계

### 4.1 Iron Laws → AGENTS.md

**변경 대상**: `AGENTS.md` Validation 섹션

**현재 상태**:
```markdown
## Validation
검증은 경험적 증거 기반. "잘 되는 것 같다"는 증거가 아님.
- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 수집하여 보고
- **조건부 성공**: 실제 결과 확인 후에만 성공 출력
```

**추가 내용**:
```markdown
### Iron Laws
- `NO EDIT WITHOUT READ FIRST` — 파일을 읽지 않고 수정하지 않는다
- `NO COMPLETION WITHOUT VERIFICATION` — 검증 증거 없이 완료를 선언하지 않는다
- `NO WRITE TO EXISTING FILES` — 기존 파일 수정은 Edit을 사용한다. Write는 새 파일 전용
```

**근거**:
- Meincke et al. (2025) SSRN #5357179: Authority 기법으로 LLM 준수율 33%→72% (N=28,000)
- Wallace et al. (ICLR 2025) arXiv:2404.13208: 명령 계층에서 최상위 규칙은 하위 합리화를 오버라이드
- OpenAI Model Spec (2025): "Root level rules" — 주요 AI 연구소의 산업 표준 패턴
- Superpowers §5.1: 4개 Iron Law가 모두 크로스커팅 전역 원칙으로 배치됨

**왜 AGENTS.md(L1)인가**:
- 3줄 — L1의 "포함=제약/트리거" 규칙 부합
- 모든 플랫폼(Claude, Gemini, Cursor, Windsurf)이 항상 로딩
- 특정 스킬 로딩 여부와 무관하게 적용

---

### 4.2 합리화 테이블 → `empirical-validation` SKILL.md

**변경 대상**: `.hxsk/skills/empirical-validation/SKILL.md`

**현재 상태**: "Forbidden Phrases" 섹션에 금지 표현 목록 존재 (합리화 테이블의 원형)

**확장 내용**:

기존 "Forbidden Phrases"를 `| 변명 | 현실 |` 포맷의 합리화 테이블로 재구성:

```markdown
## 합리화 테이블

### 허위 완료
| 변명 | 현실 |
|------|------|
| "잘 돌아갈 것 같다" | 검증 명령을 실행하라 |
| "확신한다" | 확신 ≠ 증거 |
| "린터 통과했다" | 린터 ≠ 컴파일러 ≠ 테스트 |
| "에이전트가 성공 보고했다" | 독립적으로 검증하라 |
| "코드 변경이 명확하다" | 명확한 변경도 깨진다 |

### Read 건너뛰기
| 변명 | 현실 |
|------|------|
| "이미 파일 내용을 안다" | 다른 에이전트/사용자가 수정했을 수 있다 |
| "단순한 변경이다" | 단순한 변경이 가장 많이 깨진다 |
| "방금 읽었다" | "방금"이 몇 턴 전일 수 있다. 다시 읽어라 |
| "전체 파일 덮어쓰기가 빠르다" | 덮어쓰기는 다른 변경을 날린다. Edit을 써라 |

### 작업 중단
| 변명 | 현실 |
|------|------|
| "이건 불가능하다" | 3가지 다른 접근을 시도했는가? |
| "시간이 너무 오래 걸린다" | 사용자에게 보고하고 판단을 맡겨라 |
| "다음 세션에서 하자" | 현재 컨텍스트가 가장 풍부하다. 지금 시도하라 |
```

**근거**:
- Sharma et al. (ICLR 2024) arXiv:2310.13548: RLHF 훈련이 아첨의 근본 원인 — 명시적 차단 필요
- Vennemeyer et al. (2025) arXiv:2509.21305: 아첨적 동의는 잠재 공간에서 분리 가능 — 특정 패턴 명시가 해당 방향 억제
- Superpowers §5.2: 49개 합리화 항목이 5개 규율 스킬에 분산 배치 (전역 아닌 맥락 특화)
- 현재 프로젝트: "Forbidden Phrases" 섹션이 합리화 테이블의 원형 → 확장이 자연스러움

**왜 기존 스킬 확장인가**:
- Superpowers에서도 합리화 테이블은 독립 스킬이 아닌 규율 스킬 내부 섹션
- verifier 에이전트의 탑재 스킬 수 증가 회피 (짧을수록 정확)
- SkillReducer (2026): 60%+ 스킬 본문이 비실행 내용 → 기존 스킬 강화가 신규보다 효율적

---

### 4.3 Gate Function 5단계 → `empirical-validation` SKILL.md

**변경 대상**: `.hxsk/skills/empirical-validation/SKILL.md`

**현재 상태**: 4단계 Validation Protocol 존재 (identify criteria → execute → document → confirm)

**확장 내용**:

기존 4단계를 5단계 게이트로 강화:

```markdown
## Gate Function — 완료 선언 전 필수

⚠️ 완료, 성공, 통과를 주장하기 전에 반드시 5단계를 거친다.

1. **IDENTIFY** — 이 주장을 증명하는 명령은 무엇인가?
2. **RUN** — 해당 명령을 전체 실행 (부분 실행, 이전 결과 재사용 금지)
3. **READ** — 출력 전체 확인. exit code 확인. 실패 수 카운트
4. **VERIFY** — 출력이 주장을 확인하는가? (부분 통과 ≠ 전체 통과)
5. **CLAIM** — 4단계 모두 통과 시에만 주장 가능

### 검증 유형별 필수 증거

| 주장 | 필요 증거 | 불충분 |
|------|----------|--------|
| "테스트 통과" | 테스트 출력: 0 failures | 이전 실행, "통과할 것 같다" |
| "버그 수정" | 원래 증상 재테스트 | 코드 변경됨, 수정 추정 |
| "빌드 성공" | 빌드 명령 출력: exit 0 | "에러 없어 보인다" |
| "파일 생성" | ls/cat으로 존재+내용 확인 | Write 도구 사용했으므로 |
```

**근거**:
- Anthropic harness blog (2025): 명시적 검증 도구 없이 에이전트가 허위 완료 선언
- Yess AI (2025): Validation gates = 기준 충족까지 자율 행동 중단하는 산업 표준 패턴
- Superpowers §4.13: verification-before-completion 기원 — 24건의 "I don't believe you" 실패 메모리
- GitHub #42796: Edit-without-Read 6.2%→33.7%, 허위 완료 급증
- 현재 프로젝트: 4단계 Protocol이 게이트의 4/5 이미 존재 → 5단계로 확장

**왜 `empirical-validation`이고 `verifier`가 아닌가**:
- `verifier` = WHAT (3-level artifact 체크리스트)
- `empirical-validation` = HOW (증거 수집 절차)
- Gate Function = "어떻게 검증하는가" → HOW 스킬에 배치

---

### 4.4 Ultrathink 트리거 → CLAUDE.md + `empirical-validation`

**변경 대상**: `CLAUDE.md` (3줄 참조) + `.hxsk/skills/empirical-validation/SKILL.md` (상세)

**CLAUDE.md 추가 (3줄)**:
```markdown
## Thinking Budget
깊은 추론이 필요한 작업(아키텍처 결정, 디버깅 근본 원인, 리팩토링 임팩트) 시
empirical-validation 스킬의 Thinking Budget 섹션 참조.
```

**empirical-validation SKILL.md 추가**:
```markdown
## Thinking Budget

다음 상황에서 깊은 추론을 명시적으로 요청한다:

### 필수 (항상 깊은 thinking)
- 아키텍처 결정 — 3+ 모듈에 영향을 미치는 변경
- 디버깅 근본 원인 분석 — 에러 재현 후 원인 추적
- 리팩토링 임팩트 분석 — 삭제/이동 전 의존성 파악
- 머지 충돌 해결 — 양쪽 변경의 의도 파악
- 보안 관련 코드 — 인증, 권한, 입력 검증

### 조건부 (복잡도에 따라)
- 5+ 파일 동시 변경 — 상호 의존성 추론
- 테스트 실패 원인 불명 — 에러 메시지가 모호
- 사용자가 "왜?"라고 물을 때 — 설명에 깊은 이해 필요
```

**근거**:
- Anthropic 공식 응답 (HN #47660925): adaptive thinking이 medium-effort로 under-allocate — 명시적 요청이 할당 증가 트리거
- GitHub #42796: thinking depth 73% 감소 → 파일 읽기 70% 감소, Edit-without-Read 444% 증가
- Anthropic Context Engineering (2025): 컨텍스트 윈도우 = "공공재" — CLAUDE.md에 상세 기술 시 ≤120줄 위반
- CLAUDE.md Prompt Maintenance Rules: L1=트리거/제약만, 예시/스키마 제외 → 3줄 참조 + L2 위임

---

### 4.5 CSO description 최적화 → 19개 SKILL.md

**변경 대상**: 19개 `.hxsk/skills/*/SKILL.md`의 YAML frontmatter `description` 필드

**변경 원칙**:
- description에 **트리거 조건만** 기재
- 워크플로우 요약, 절차 설명 제거
- "Use when..." 또는 "~할 때, ~시" 패턴
- 에러 메시지, 증상, 동의어, 도구명 포함

**변경 예시**:
```yaml
# Before
description: "메모리를 저장하고 검색하는 프로토콜. 2-hop 검색과 14타입 분류를 지원"

# After
description: "Use when storing or retrieving project knowledge, after architecture decisions, bug fixes, or session ends"
```

```yaml
# Before
description: "경험적 증거 기반 검증. 코드 변경 후 실제 실행 결과로 성공/실패 판단"

# After
description: "Use when claiming work is complete, before committing, or when verifying any change actually works"
```

**근거**:
- SkillReducer (2026) arXiv:2603.29919: 55K 스킬 분석, 48% description 압축 + 2.8% 품질 향상 (less-is-more)
- Anthropic 공식 문서: 시작 시 메타데이터(name, description)만 프리로드, 본문은 관련성 판단 후 로딩
- Superpowers CSO: 테스트에서 워크플로우 요약 포함 시 에이전트가 본문을 건너뜀 발견
- SkillReducer: 26.4% 스킬이 라우팅 description 부재 → 존재하되 트리거에 집중

---

### 4.6 Read-before-Edit 훅 → PreToolUse (신규)

**변경 대상**: `.hxsk/hooks/read-before-edit.py` (신규) + `.claude/settings.json` PreToolUse 등록

**동작**:
```
PreToolUse(Edit) 트리거 시:
1. Edit 대상 file_path 추출
2. 현재 세션에서 해당 파일에 대한 Read 이력 확인
3. Read 이력 없으면 → "⚠️ 이 파일을 먼저 Read하세요" 경고 반환
4. Read 이력 있으면 → 통과
```

**구현 고려사항**:
- `.hxsk/.track-modifications.log`와 유사한 `.hxsk/.read-history.log` 사용
- SessionStart 훅에서 read history 초기화
- Read PostToolUse 훅에서 읽은 파일 경로 기록
- Edit PreToolUse 훅에서 해당 파일의 Read 기록 확인

**근거**:
- Wallace et al. (ICLR 2025): 아키텍처 강제가 프롬프트 강제보다 일관되게 우수
- GitHub #42796: Edit-without-Read 6.2%→33.7% — 프롬프트만으로는 thinking 부족 시 무시됨
- HXSK 기존 인프라: file-protect.py, bash-guard.py가 이미 PreToolUse 훅으로 동작 중 — 동일 패턴

**프롬프트(Iron Law) + 인프라(훅) 이중 방어**: thinking이 부족해 Iron Law를 무시해도 훅이 차단.

---

### 4.7 완료 검증 게이트 훅 → Stop (확장)

**변경 대상**: `.hxsk/hooks/post-turn-verify.sh` (확장)

**동작**:
```
Stop 이벤트 트리거 시:
1. 에이전트 출력에서 완료 키워드 탐지 ("완료", "성공", "pass", "done", "fixed")
2. 완료 키워드 발견 시 → 해당 턴에서 Bash(test/build/lint) 실행 이력 확인
3. 검증 명령 이력 없으면 → "⚠️ 검증 명령을 실행한 증거가 없습니다" 경고
4. 이력 있으면 → 통과
```

**구현 고려사항**:
- 기존 post-turn-verify.sh 로직에 추가 (대체 아님)
- 경고 수준 — block이 아닌 warn (완료 키워드가 항상 최종 완료를 의미하진 않음)
- `.hxsk/.track-modifications.log`에서 Bash 실행 이력 참조

**근거**:
- Anthropic harness blog (2025): 별도 evaluator 없이는 허위 완료 선언
- Yess AI (2025): Validation gates = 기준 충족까지 자율 행동 중단
- Superpowers §4.13: 24건 "I don't believe you" → verification-before-completion 스킬 탄생
- HXSK 기존 인프라: post-turn-verify.sh가 이미 Stop 훅으로 동작 중

**프롬프트(Gate Function) + 인프라(Stop 훅) 이중 방어.**

---

## 5. 변경 영향 범위

| 파일 | 변경 유형 | 영향 |
|------|----------|------|
| `AGENTS.md` | 섹션 추가 (3줄) | 모든 플랫폼 |
| `CLAUDE.md` | 섹션 추가 (3줄) | Claude Code |
| `.hxsk/skills/empirical-validation/SKILL.md` | 섹션 확장 | verifier 에이전트 |
| `.hxsk/skills/*/SKILL.md` (19개) | description 수정 | 스킬 라우팅 |
| `.hxsk/hooks/read-before-edit.py` | 신규 | Claude Code PreToolUse |
| `.hxsk/hooks/post-turn-verify.sh` | 확장 | Claude Code Stop |
| `.claude/settings.json` | 훅 등록 | Claude Code |
| `.hxsk/.bootstrap-version` | 카운트 갱신 | 자동 (카운트 자동 동기화) |

### 변경하지 않는 것
- 에이전트 정의 파일 — 탑재 스킬 변경 불필요
- 프로젝트 구조 — 신규 스킬/에이전트 디렉토리 불필요
- 워크플로우 — SPEC→PLAN→EXECUTE→VERIFY 체인 불변

---

## 6. 구현 순서

의존성과 검증 용이성 기준:

```
1. Iron Laws (AGENTS.md)          ← 가장 단순, 즉시 효과
2. 합리화 테이블 (empirical-validation) ← Iron Laws 보완
3. Gate Function (empirical-validation)  ← 합리화 테이블과 함께 작동
4. Ultrathink 트리거 (CLAUDE.md + empirical-validation) ← Gate Function과 연계
5. Read-before-Edit 훅 (PreToolUse)    ← Iron Law #1의 인프라 강제
6. 완료 검증 게이트 훅 (Stop)          ← Iron Law #2의 인프라 강제
7. CSO description 최적화 (19개 SKILL.md) ← 독립 작업, 마지막에 일괄
```

---

## 7. 검증 계획

| 항목 | 검증 방법 |
|------|----------|
| Iron Laws | AGENTS.md에 포함 확인, consistency check 통과 |
| 합리화 테이블 | empirical-validation 스킬 로딩 후 테이블 존재 확인 |
| Gate Function | 테스트 실행 없이 "완료" 주장 시 에이전트 자기 차단 여부 |
| Ultrathink | 아키텍처 결정 시 깊은 추론 요청 여부 관찰 |
| CSO | 스킬 트리거 정확도 (올바른 스킬 호출 비율) 관찰 |
| Read-before-Edit 훅 | Read 없이 Edit 시 경고 메시지 반환 확인 |
| 완료 검증 게이트 훅 | Bash 실행 없이 "완료" 시 경고 반환 확인 |

---

## 8. 참고 자료

| 문서 | 위치 |
|------|------|
| Superpowers 패턴 분석 | `.hxsk/research/superpowers-analysis.md` |
| 근거 논문 20개 상세 | `.hxsk/research/superpowers-references.md` |
| 품질 저하 완화 분석 | `.hxsk/research/claude-code-quality-mitigation.md` |
| README 로드맵 | `README.md` 로드맵 섹션 |
