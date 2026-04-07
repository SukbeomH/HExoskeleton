# 근본 원인 추적 기법

> debugger SKILL.md의 "가설 → 검증" 과정을 보완하는 역추적 기법.

---

## 역추적 (Backward Tracing)

에러 발생 지점에서 시작하여 호출 체인을 역순으로 따라갑니다.

### 5단계 프로세스

1. **에러 지점 특정** — 스택 트레이스의 최하단 (우리 코드 중)
2. **입력 추적** — 해당 함수에 어떤 값이 전달되었는가?
3. **호출자 확인** — 누가 이 함수를 호출했는가?
4. **데이터 원천** — 잘못된 값은 어디서 왔는가?
5. **근본 원인** — 값이 잘못된 최초 지점

### 예시

```
Error: Cannot read property 'name' of undefined
  at UserProfile.render (UserProfile.tsx:42)    ← 1. 에러 지점
  at Dashboard.render (Dashboard.tsx:15)        ← 3. 호출자

1. UserProfile.tsx:42 — user.name 접근 시 user가 undefined
2. user는 props.user로 전달됨
3. Dashboard.tsx:15 — <UserProfile user={currentUser} />
4. currentUser는 useAuth() 훅에서 반환
5. 근본 원인: useAuth()가 로딩 중 undefined 반환 → null check 누락
```

## 경계 로깅 (Boundary Logging)

멀티 컴포넌트 시스템에서 각 경계에 로그를 추가하여 데이터 변형 지점을 찾습니다.

```
[Client] → request: {userId: 123}
[API Gateway] → forwarded: {userId: "123"}  ← 숫자→문자열 변형!
[Service] → received: {userId: "123"}
[DB] → query: WHERE id = '123'              ← 타입 불일치
```

## 3-Strike 규칙과의 연계

동일 접근 3회 실패 시:
1. 현재까지의 시도와 결과를 정리
2. `debug-blocked` 메모리에 저장
3. 사용자에게 보고하고 다른 접근 제안
