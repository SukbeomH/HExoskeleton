# Security Audit Skill

## 목적 및 범위

이 스킬은 `detect_stack.sh` 결과를 기반으로 스택별 보안 점검을 수행합니다. Python 프로젝트는 `safety check`를, Node.js 프로젝트는 `npm/pnpm audit`을 실행하여 의존성 취약점을 검사합니다.

### 적용 범위
- **Python 프로젝트**: `safety` 도구를 사용한 취약점 검사
- **Node.js 프로젝트**: `npm audit` 또는 `pnpm audit`을 사용한 취약점 검사
- **패키지 매니저별 지원**: uv, Poetry, npm, pnpm

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **VERIFY 단계**: 코드 배포 전 보안 검사
- **PR 생성 전**: 취약점 확인
- **의존성 업데이트 후**: 새로 추가된 의존성의 취약점 확인

## 입력 요구사항

### 필수 파라미터
- 없음

### 선택적 파라미터
- `target_directory` (string): 프로젝트 루트 디렉토리 경로 (기본값: 상위 디렉토리)

### 전제 조건
- Python 프로젝트: `safety` 패키지가 설치되어 있어야 함 (`poetry add safety --group dev` 또는 `uv add safety --dev`)
- Node.js 프로젝트: `npm` 또는 `pnpm`이 설치되어 있어야 함
- `detect_stack.sh`를 통해 프로젝트 스택이 감지되어야 함

## 출력 형식

JSON 형식으로 보안 감사 결과를 반환합니다:

```json
{
  "timestamp": "ISO 8601 형식의 타임스탬프",
  "stack": "python | node",
  "packageManager": "npm | pnpm | poetry | uv",
  "audit": {
    "stack": "python | node",
    "tool": "safety | npm | pnpm",
    "status": "secure | vulnerable | error | tool_not_found | not_supported",
    "vulnerabilities": [
      {
        "name": "패키지 이름",
        "severity": "심각도",
        "title": "취약점 제목",
        "url": "상세 정보 URL"
      }
    ],
    "errors": []
  }
}
```

## 상태 코드

- **secure**: 취약점 없음
- **vulnerable**: 취약점 발견 (종료 코드 1)
- **error**: 감사 실행 중 오류 발생
- **tool_not_found**: 필요한 도구가 설치되지 않음
- **not_supported**: 해당 스택은 지원되지 않음

## 제약사항

1. **제안 기반 원칙**: 취약점을 자동으로 수정하지 않으며, 발견된 취약점 목록만 제공합니다.
2. **기술 중립성**: `detect_stack.sh`의 결과를 기반으로 스택별로 적절한 도구를 선택합니다.
3. **도구 설치 필요**: Python 프로젝트는 `safety` 패키지가 설치되어 있어야 합니다.

## 예시

### 실행 방법
```bash
node skills/security-audit/run.js [target_directory]
```

### 출력 예시 (취약점 발견)
```
🔒 Security Audit Agent
========================

1. Detecting stack...
   Detected stack: node (pnpm)

2. Running security audit...
🔍 Running Node.js security audit...
❌ Found 2 vulnerability(ies)

3. Audit Results:
{
  "timestamp": "2024-01-13T09:20:00.000Z",
  "stack": "node",
  "packageManager": "pnpm",
  "audit": {
    "status": "vulnerable",
    "vulnerabilities": [
      {
        "name": "lodash",
        "severity": "high",
        "title": "Command Injection",
        "url": "https://..."
      }
    ]
  }
}

❌ Security vulnerabilities found. Please review and fix.
```

### 출력 예시 (취약점 없음)
```
✅ No vulnerabilities found
✅ Security audit passed.
```

### 결과 해석
- `status: "vulnerable"`: 취약점 발견 (즉시 수정 권장, 종료 코드 1)
- `status: "secure"`: 취약점 없음 (정상, 종료 코드 0)
- `status: "tool_not_found"`: 필요한 도구 미설치 (경고, 종료 코드 0)

## 관련 스킬

- `log-analyzer`: 런타임 에러 분석
- `simplifier`: 코드 복잡도 분석
- `visual-verifier`: 웹 프로젝트 시각적 검증

