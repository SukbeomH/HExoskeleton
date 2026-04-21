---
name: empirical-validation
description: "Use when claiming work is complete, before committing, or when verifying any change actually works"
trigger: "경험적 검증, 실행 결과 확인, 증거 기반 확인, prove it works, empirical proof, validate with output"
---

## Quick Reference
- **원칙**: "The code looks correct" ≠ 검증. 경험적 증거 필수
- **UI**: Screenshot으로 시각 상태 확인 (Bash: `screenshot` 또는 브라우저 MCP)
- **API**: `curl` 명령으로 응답 확인 (Bash)
- **Build/Test**: 성공 출력 캡처 (Bash)
- **금지 문구**: "This should work", "Based on my understanding" 등

---

# Empirical Validation

## Core Principle

> **"The code looks correct" is NOT validation.**
> 
> Every change must be verified with empirical evidence before being marked complete.

## Validation Methods by Change Type

| Change Type | Required Validation | Tool |
|-------------|---------------------|------|
| **UI Changes** | Screenshot showing expected visual state | `Bash` (screenshot tool or browser MCP) |
| **API Endpoints** | Command showing correct response | `Bash` (curl/httpie) |
| **Build/Config** | Successful build or test output | `Bash` |
| **Data Changes** | Query showing expected data state | `Bash` |
| **File Operations** | File listing or content verification | `Bash` |

## Validation Protocol

### Before Marking Any Task "Done"

1. **Identify Verification Criteria**
   - What should be true after this change?
   - How can that be observed?

2. **Execute Verification**
   - Run the appropriate command or action
   - Capture the output/evidence

3. **Document Evidence**
   - Add to `.hxsk/JOURNAL.md` under the task
   - Include actual output, not just "passed"

4. **Confirm Against Criteria**
   - Does evidence match expected outcome?
   - If not, task is NOT complete

## Examples

### API Endpoint Verification
```bash
# Good: Actual test showing response
curl -X POST http://localhost:3000/api/login -d '{"email":"test@test.com"}' 
# Output: {"success":true,"token":"..."}

# Bad: Just saying "endpoint works"
```

### UI Verification
```
# Good: Take screenshot with browser tool
- Navigate to /dashboard
- Capture screenshot
- Confirm: Header visible? Data loaded? Layout correct?

# Bad: "The component should render correctly"
```

### Build Verification
```bash
# Good: Show build output
npm run build
# Output: Successfully compiled...

# Bad: "Build should work now"
```

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

## Thinking Budget

깊은 추론이 필요한 상황에서 명시적으로 깊은 thinking을 요청한다.

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

## Guard 이중 게이트 (선택)

단일 Verify 외에 Guard를 추가하면 **목표 달성 + 사이드 이펙트 없음**을 동시에 검증한다.

```
Verify: bash .hxsk/scripts/doc-lint.sh   # 목표 달성?
Guard:  bash .hxsk/hooks/check-consistency.sh  # 기존 기능 깨지지 않음?
```

Guard 실패 시 → Verify 성공이라도 BLOCK. Guard 명령은 이진 exit code(0/1)만 허용.

**pre-commit hook과의 역할 구분**:
- Guard (실행 중): 매 원자 변경 직후 즉시 사이드 이펙트 감지 — 에이전트 루프 내부
- pre-commit: 커밋 직전 최종 관문 — 인간 실수 및 누락 방지

두 레이어는 시점이 다르므로 중복이 아니다.

## 관련 스킬

- **REQUIRED**: `memory-protocol` — 검증 결과(성공/실패)를 메모리에 저장
- **RECOMMENDED**: `context-health-monitor` — 3+ 검증 실패 시 건강 이벤트 기록
- **RECOMMENDED**: `debugger` — 검증 실패 시 근본 원인 분석 전환

## Integration

This skill integrates with:
- `/verify` — Primary workflow using this skill
- `/execute` — Must validate before marking tasks complete
- `CLAUDE.md` Validation + Thinking Budget 섹션
- `AGENTS.md` Iron Laws — 이 스킬의 상세 절차를 구현

## Failure Handling

If verification fails:

1. **Do NOT mark task complete**
2. **Document** the failure in `.hxsk/STATE.md`
3. **Create** fix task if cause is known
4. **Trigger** Context Health Monitor if 3+ failures
