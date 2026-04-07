# Empirical Validation 안티패턴

> SKILL.md의 합리화 테이블을 보완하는 실제 안티패턴 사례집.

---

## 1. 유령 검증 (Phantom Verification)

**패턴**: 검증 명령을 실행하지 않고 "테스트가 통과합니다"라고 보고.

```
# Bad — 실행 없이 주장
"npm test를 실행하면 통과할 것입니다."

# Good — 실제 실행 + 출력 제시
$ npm test
✓ 15 tests passed, 0 failed
```

**탐지**: Stop 훅이 Bash 실행 이력 없이 완료 키워드 감지 시 경고.

## 2. 시간차 증거 (Stale Evidence)

**패턴**: 이전 턴의 테스트 결과를 현재 변경의 증거로 사용.

```
# Bad — 3턴 전 결과 인용
"아까 테스트가 통과했으므로 이 변경도 괜찮습니다."

# Good — 변경 후 재실행
$ npm test  # 변경 후 즉시 실행
✓ 15 tests passed, 0 failed
```

**Gate Function 적용**: RUN 단계에서 "부분 실행, 이전 결과 재사용 금지" 규칙.

## 3. 부분 통과 = 전체 통과 (Partial Pass Fallacy)

**패턴**: 일부 테스트만 통과했는데 전체 통과로 보고.

```
# Bad — 실패 무시
"대부분의 테스트가 통과합니다." (3개 실패 숨김)

# Good — 전체 결과 보고
$ npm test
✓ 12 passed, ✗ 3 failed
→ 3개 실패: auth.test.ts, api.test.ts, db.test.ts
```

**Gate Function 적용**: READ 단계에서 "실패 수 카운트" + VERIFY에서 "부분 통과 ≠ 전체 통과".

## 4. 도구 혼동 (Tool Confusion)

**패턴**: 린터 통과를 테스트 통과로, 타입체크를 기능 검증으로 혼동.

| 도구 | 증명하는 것 | 증명하지 않는 것 |
|------|-----------|----------------|
| Linter (eslint, ruff) | 코드 스타일 | 기능 동작 |
| Type checker (tsc, mypy) | 타입 안전성 | 런타임 동작 |
| Build (npm build) | 컴파일 가능 | 기능 정확성 |
| Test (npm test) | 기능 동작 | 성능, 보안 |

## 5. Write-and-Forget (쓰고 잊기)

**패턴**: Write 도구로 파일 생성 후 존재·내용 확인 없이 완료 선언.

```
# Bad — Write 후 확인 없이
Write(file_path: "config.json", content: "...") → "설정 파일을 생성했습니다."

# Good — Write 후 확인
Write(file_path: "config.json", content: "...")
Read(file_path: "config.json")  # 내용 확인
$ ls -la config.json             # 존재 확인
```
