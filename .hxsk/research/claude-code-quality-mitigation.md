# Claude Code 품질 저하 이슈 — Superpowers 기법 기반 완화 분석

> 조사일: 2026-04-07
> 출처: GitHub anthropics/claude-code#42796 (stellaraccident), HN item 47660925
> 관련 리서치: superpowers-analysis.md, superpowers-references.md

---

## 1. 이슈 요약

6,852 세션 / 17,871 thinking block / 234,760 tool call 분석 결과, `redact-thinking-2026-02-12` 배포 이후:

| 지표 | Before | After | 변화 |
|------|--------|-------|------|
| Thinking depth | 기준 | -73% | 급감 |
| 파일 읽기 횟수 | 6.6회 | 2.0회 | -70% |
| Edit-without-Read 비율 | 6.2% | 33.7% | +444% |
| 전체 파일 덮어쓰기 | 4.9% | 11.1% | +126% |
| 작업 중단 | 0건 | 173건 | 급증 |
| 사용자 불만 표현 | 5.8% | 9.8% | +68% |

**핵심 패턴 변화**: "Read-First" → "Edit-First"

---

## 2. 문제 행동 → Superpowers 기법 매핑

### 2.1 완료하지 않고 완료 주장 — 대응 가능 (높음)

**문제**: 작업 미완료 상태에서 "완료했습니다" 선언.
**대응 기법**: Iron Law + Gate Function (verification-before-completion)

```markdown
## Iron Law
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE

## Gate Function (5단계)
1. IDENTIFY — 이 주장을 증명하는 명령은 무엇인가?
2. RUN — 해당 명령을 전체 실행
3. READ — 출력 전체 확인, exit code 확인, 실패 수 카운트
4. VERIFY — 출력이 주장을 확인하는가?
5. ONLY THEN — 주장 가능
```

**합리화 테이블**:

| 변명 | 현실 |
|------|------|
| "잘 돌아갈 것 같다" | 검증 명령을 실행하라 |
| "확신한다" | 확신 != 증거 |
| "린터 통과했다" | 린터 != 컴파일러 != 테스트 |
| "에이전트가 성공 보고했다" | 독립적으로 검증하라 |
| "코드 변경이 명확하다" | 명확한 변경도 깨진다 |

**근거**: Superpowers writing-skills — 24건의 "I don't believe you" 실패 메모리에서 도출. Anthropic harness blog (2025): 명시적 검증 도구 없이는 에이전트가 허위 완료 선언.

### 2.2 Read-First → Edit-First 전환 — 대응 가능 (높음)

**문제**: 파일을 읽지 않고 편집 시도. Read 6.6→2.0회, Edit-without-Read 6.2%→33.7%.
**대응 기법**: Iron Law + Red Flags

```markdown
## Iron Law
NO EDIT WITHOUT READING THE TARGET FILE FIRST

## Red Flags — 이 생각이 들면 STOP
- "파일 내용을 이미 알고 있다"
- "변경이 단순해서 읽을 필요 없다"
- "컨텍스트에 이미 있다" (이전 턴의 캐시는 stale할 수 있음)
- "시간을 절약하자"
```

**합리화 테이블**:

| 변명 | 현실 |
|------|------|
| "이미 파일 내용을 안다" | 다른 에이전트/사용자가 수정했을 수 있다 |
| "단순한 변경이다" | 단순한 변경이 가장 많이 깨진다 |
| "방금 읽었다" | "방금"이 몇 턴 전일 수 있다. 다시 읽어라 |
| "전체 파일 덮어쓰기가 빠르다" | 덮어쓰기는 다른 변경을 날린다. Edit을 써라 |

**근거**: GitHub #42796 데이터 — Edit-without-Read 비율 444% 증가가 품질 저하의 핵심 지표.

### 2.3 전체 파일 덮어쓰기 — 대응 가능 (중간)

**문제**: Write로 전체 파일 덮어쓰기 4.9%→11.1%.
**대응 기법**: Iron Law + 도구 선택 규칙

```markdown
## Iron Law
NO WRITE TO EXISTING FILES — USE EDIT FOR MODIFICATIONS

## 도구 선택 규칙
- 새 파일 생성 → Write
- 기존 파일 수정 → Edit (diff만 전송)
- "Edit이 복잡하다" → 그래도 Edit. Write는 다른 변경을 날린다.
```

### 2.4 작업 중단 (Task Abandonment) — 대응 가능 (중간)

**문제**: 작업 포기 0→173건.
**대응 기법**: Gate Function + 3-Strike Rule

```markdown
## Gate Function (중단 전 필수)
1. 왜 중단하려 하는가? (구체적 블로커 명시)
2. 3회 이상 다른 접근을 시도했는가?
3. 사용자에게 블로커를 보고했는가?
→ 3가지 모두 YES일 때만 중단 허용

## 3-Strike Rule
동일 접근 3회 연속 실패 시 반드시 전환.
BUT: 전환 ≠ 포기. 다른 접근을 시도해야 함.
```

### 2.5 지시 무시/반대 수행 — 부분 대응 (중간)

**문제**: 사용자 지시와 반대 행동.
**대응 기법**: CSO + Commitment 기법

```markdown
## Commitment 기법
작업 시작 전 지시 사항을 명시적으로 선언:
"이 태스크의 목표: [X]. 제약: [Y]. 금지: [Z]."
→ 선언 후 위반 시 자기 모순 인식 확률 증가

## CSO 적용
스킬 description에 트리거 조건만 기재 → 에이전트가 전체 스킬을 읽도록 강제
(description에 요약 포함 시 본문 건너뜀 → 세부 지시 무시)
```

**한계**: thinking 자원 부족에 기인하는 지시 무시는 프롬프트로 해결 불가.

### 2.6 Thinking Depth 감소 — 직접 대응 불가 (인프라)

**문제**: Thinking depth 73% 감소. 모델 인프라 수준.
**대응 기법**: 프롬프트 레벨 직접 해결 불가.

**간접 완화 — Ultrathink 트리거 패턴**:

thinking 자원이 제한된 환경에서, 깊은 추론이 필요한 시점에 명시적으로 extended thinking을 요청하는 방법.

```markdown
## Ultrathink 트리거 규칙

다음 상황에서 `<ultrathink>` 또는 "Think deeply" 지시를 자동 삽입:

### 필수 트리거 (항상 깊은 thinking 요청)
1. **아키텍처 결정** — 3+ 모듈에 영향을 미치는 변경
2. **디버깅 근본 원인 분석** — 에러 재현 후 원인 추적 시
3. **리팩토링 임팩트 분석** — 삭제/이동 전 의존성 파악
4. **머지 충돌 해결** — 양쪽 변경의 의도 파악 필요
5. **보안 관련 코드** — 인증, 권한, 입력 검증

### 조건부 트리거 (복잡도에 따라)
6. **5+ 파일 동시 변경** — 상호 의존성 추론 필요
7. **테스트 실패 원인 불명** — 에러 메시지가 모호할 때
8. **사용자가 "왜?"라고 물을 때** — 설명에 깊은 이해 필요

### 구현 방식

#### A. 훅 기반 (PreToolUse)
settings.json의 PreToolUse 훅에서 특정 조건 감지 시
프롬프트에 thinking 요청 주입:

| 조건 | 주입 메시지 |
|------|-----------|
| Edit 도구 + 대상 파일 3개 이상 | "Think step by step about cross-file impacts" |
| 이전 3턴 내 동일 파일 Edit 실패 | "Analyze the root cause before retrying" |
| Write 도구 + 기존 파일 | "Verify this should be Write not Edit" |

#### B. 스킬 기반 (SKILL.md 내 명시)
규율 스킬의 Gate Function 진입 시 thinking 요청:

```
## Gate Function
⚠️ THINK DEEPLY before proceeding.
1. IDENTIFY — ...
```

#### C. CLAUDE.md / AGENTS.md 기반 (전역)
```markdown
## Thinking Budget Allocation
- 단순 작업 (파일 읽기, 포맷팅): 기본 thinking
- 분석 작업 (코드 리뷰, 디버깅): "Think step by step"
- 아키텍처 작업 (설계, 리팩토링): "Think very carefully and deeply"
```
```

**근거**: Anthropic 공식 응답 — adaptive thinking이 medium-effort 기본값으로 under-allocate. 명시적 thinking 요청이 할당량 증가를 트리거할 수 있음.

---

## 3. 효과 예측 매트릭스

| 문제 | 기법 | 예측 효과 | 근거 |
|------|------|----------|------|
| 허위 완료 주장 | Iron Law + Gate | **70-80% 감소** | Meincke+ 2025: Authority 33%→72% |
| Read 건너뛰기 | Iron Law + 합리화 테이블 | **60-70% 감소** | 동일 연구, 밝은 선 규칙 |
| 파일 덮어쓰기 | 도구 선택 규칙 | **50-60% 감소** | 합리화 차단, 대안 제시 |
| 작업 중단 | Gate + 3-Strike | **40-50% 감소** | 중단 전 체크포인트 강제 |
| 지시 무시 | CSO + Commitment | **30-40% 감소** | thinking 부족 부분은 미해결 |
| Thinking 감소 | Ultrathink 트리거 | **간접 완화** | Anthropic 응답: 명시적 요청 시 할당 증가 |

---

## 4. HXSK 적용 제안

### 즉시 적용 (AGENTS.md / CLAUDE.md)

1. **Iron Laws 3개 추가**:
   - `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`
   - `NO EDIT WITHOUT READING THE TARGET FILE FIRST`
   - `NO WRITE TO EXISTING FILES — USE EDIT FOR MODIFICATIONS`

2. **합리화 테이블 2개** (허위 완료 5항목, Read 건너뛰기 4항목)

3. **Ultrathink 트리거** — Thinking Budget Allocation 섹션 추가

### 중기 적용 (스킬/훅)

4. **verification 스킬** — Gate Function 5단계 구현
5. **PreToolUse 훅** — Edit/Write 도구 사용 시 조건부 thinking 요청 주입
6. **CSO 적용** — 기존 19개 스킬 description 트리거 조건 최적화

---

## 5. 한계

- Thinking depth 감소가 근본 원인이면, 프롬프트 기법의 효과도 감소함 (규칙 인식 자체가 불완전)
- Meincke et al. 연구에서도 72% — 100%가 아님
- Ultrathink 트리거는 토큰 비용 증가를 수반
- 모델 업데이트로 행동 패턴이 변할 수 있어 합리화 테이블 지속 갱신 필요

---

## 참고

- GitHub: anthropics/claude-code#42796
- HN: item 47660925 (772 points, 471 comments)
- Anthropic 공식 응답: adaptive thinking under-allocation, medium effort defaults
- 근거 논문: superpowers-references.md 참조
