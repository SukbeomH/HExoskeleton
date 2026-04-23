---
name: refactor
description: "Use when code is hard to maintain — extract functions, eliminate smells, apply patterns without behavior change"
trigger: "리팩토링, 코드 정리, 함수 분리, 코드 스멜 제거, refactor, extract method, rename, simplify"
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Bash
---

## Quick Reference
- **Workflow**: PREPARE → IDENTIFY → REFACTOR → VERIFY
- **필수 조건**: 테스트 존재 또는 동작 명세 확인 후 시작
- **단위**: 1회 1개 코드 스멜만 처리 (multi-smell 병행 금지)
- **커밋**: 각 안전 상태마다 `commit` 스킬 패턴 적용
- **검증**: 각 단계 후 `empirical-validation` 스킬 적용

---

# HXSK Refactor Skill

<role>
You are a surgical refactoring agent. You improve code maintainability without changing external behavior.
Every refactoring step must be: tested → committed → verified before proceeding.
</role>

---

## PREPARE

Before refactoring:

1. **테스트 확인**
   ```bash
   # 테스트 존재 여부 확인
   find . -name "*.test.*" -o -name "*_test.*" -o -name "*spec*" | head -10
   ```
   테스트 없으면 동작 명세를 먼저 작성하거나 사용자에게 확인.

2. **브랜치 생성**
   ```bash
   git checkout -b refactor/{describe-smell}
   ```

3. **현재 상태 커밋** — `commit` 스킬 패턴으로 안전 기점 확보

---

## IDENTIFY

### 10가지 코드 스멜 카탈로그

| 스멜 | 신호 | 해결 방향 |
|------|------|-----------|
| Long method | 함수 40줄+ | 책임별 Extract Method |
| Duplicated logic | 유사 블록 3회+ | 공통 함수 추출 |
| God object | 클래스 10+ 메서드 | Single Responsibility로 분리 |
| Excessive parameters | 파라미터 4개+ | 파라미터 객체로 그룹화 |
| Feature envy | A가 B의 데이터를 자주 사용 | 로직을 B로 이동 |
| Primitive obsession | 원시 타입 남용 | 도메인 타입/값 객체 도입 |
| Magic values | 의미없는 숫자/문자열 | 상수/enum으로 교체 |
| Nested conditionals | if 3단계+ 중첩 | Guard clause로 평탄화 |
| Dead code | 미호출 함수/변수 | 완전 삭제 |
| Inappropriate intimacy | 과도한 내부 접근 | 위임(delegation)으로 캡슐화 |

**PICK ONE** — 이번 세션에서 처리할 스멜 하나만 선택한다.

---

## REFACTOR

### 핵심 원칙
1. **동작 보존** — 외부 인터페이스 변경 없음
2. **증분 진행** — 한 번에 한 가지만 변경
3. **테스트 통과 유지** — 각 변경 후 즉시 확인

### 기법별 가이드

**Extract Method** (Long method 해결):
```
긴 함수 → 의도를 드러내는 이름의 작은 함수들로 분리
변경 전: one_big_function() { step1; step2; step3; }
변경 후: handle_request() { validate(); process(); respond(); }
```

**Guard Clause** (Nested conditionals 해결):
```
중첩 if → 조기 반환으로 평탄화
변경 전: if (ok) { if (valid) { if (auth) { ... }}}
변경 후: if (!ok) return; if (!valid) return; if (!auth) return; ...
```

**Introduce Named Constant** (Magic values 해결):
```
변경 전: if (status == 3) { ... }
변경 후: MAX_RETRY = 3; if (status == MAX_RETRY) { ... }
```

각 기법 적용 후:
```bash
# 테스트 실행
<test command>
# 통과하면 커밋
git add -A && git commit -m "refactor: <what changed>"
```

---

## VERIFY

`empirical-validation` 스킬로 최종 검증:
- 모든 기존 테스트 통과
- 인터페이스 변경 없음 (`git diff main -- *.d.ts` 또는 API 명세 확인)
- 성능 저하 없음 (해당 시)

---

## 관련 스킬

- `commit` — 각 안전 상태 커밋 프로토콜
- `clean` — shellcheck/shfmt 코드 품질 (shell scripts)
- `verifier` — 구현 완료 후 전체 검증
- `empirical-validation` — 경험적 검증 (테스트 실행 + 결과 확인)
