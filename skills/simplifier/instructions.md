# Code Simplifier Skill

## 목적 및 범위

이 스킬은 구현된 코드의 인지적 복잡도를 분석하고, 불필요한 추상화나 중복을 찾아 리팩토링을 제안합니다. Senior Engineer의 관점에서 '간결함(Simplicity)'을 최우선 가치로 평가합니다.

### 적용 범위
- JavaScript/TypeScript 코드 분석 (Node.js 프로젝트)
- Python 코드 분석
- 함수 복잡도, 중첩 깊이, 순환 복잡도 평가

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **VERIFY 단계**: 코드 작성 완료 후 복잡도 검증
- **REVIEW 단계**: 코드 리뷰 시 복잡도 분석
- **리팩토링 전**: 기존 코드의 복잡도 평가

## 입력 요구사항

### 필수 파라미터
- 없음 (기본적으로 프로젝트의 `src/` 디렉토리 분석)

### 선택적 파라미터
- `target_path` (string): 분석할 디렉토리 경로 (기본값: `src/`)

### 전제 조건
- `detect_stack.sh`를 통해 프로젝트 스택이 감지되어야 함
- 분석 대상 디렉토리가 존재해야 함

## 출력 형식

JSON 형식으로 제안 사항을 반환합니다:

```json
{
  "timestamp": "ISO 8601 형식의 타임스탬프",
  "totalSuggestions": "제안 개수",
  "suggestions": [
    {
      "type": "long_function | deep_nesting | high_complexity",
      "file": "파일 경로",
      "line": "라인 번호",
      "message": "제안 메시지",
      "severity": "high | medium | low"
    }
  ]
}
```

## 평가 기준

다음 기준을 초과하면 제안이 생성됩니다:
- **함수당 최대 라인 수**: 50줄
- **최대 중첩 깊이**: 4단계
- **최대 순환 복잡도**: 10
- **최대 인지적 복잡도**: 15

## 제약사항

1. **제안 기반 원칙**: 모든 분석은 제안만 제공하며, 코드를 자동으로 수정하지 않습니다.
2. **기술 중립성**: `detect_stack.sh`의 결과를 기반으로 스택별로 적절한 분석을 수행합니다.
3. **수동 검토 필수**: 제안된 변경사항은 반드시 사용자가 검토하고 승인한 후에 적용해야 합니다.

## 예시

### 실행 방법
```bash
node skills/simplifier/run.js [target_directory]
```

### 출력 예시
```
🔧 Code Simplifier Agent
========================

1. Detecting stack...
   Detected stack: node (pnpm)

2. Analyzing code complexity...
🔍 Analyzing code complexity in: /path/to/src
📦 Analyzing JavaScript/TypeScript files...

3. Generating suggestions...

📋 Found 3 suggestion(s):

[HIGH] src/utils/processor.js:45
  Nesting depth is 5 (threshold: 4). Consider refactoring to reduce nesting.

[MEDIUM] src/api/handler.js:120
  Function "processRequest" is 65 lines long (threshold: 50 lines). Consider splitting it into smaller functions.

--- JSON Output ---
{
  "timestamp": "2024-01-13T09:20:00.000Z",
  "totalSuggestions": 3,
  "suggestions": [...]
}
```

### 결과 해석
- `high` 심각도: 즉시 리팩토링을 고려해야 하는 문제
- `medium` 심각도: 리팩토링을 권장하는 문제
- `low` 심각도: 개선 여지가 있는 문제

## 관련 스킬

- `security-audit`: 보안 취약점 검사
- `log-analyzer`: 런타임 에러 분석
- `visual-verifier`: 웹 프로젝트 시각적 검증

