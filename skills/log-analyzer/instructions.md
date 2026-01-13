# Log Analyzer Skill

## 목적 및 범위

이 스킬은 `logging.conf`에 의해 생성되는 `app.log`를 분석하여 ERROR/CRITICAL 로그를 감지하고, Codanna/Serena MCP를 통해 관련 소스 코드를 정밀 분석합니다.

### 적용 범위
- Python 프로젝트의 `app.log` 파일 분석
- 로깅 포맷: `[%(asctime)s.%(msecs)d] [%(levelname)s] [%(name)s] [%(threadName)s:%(thread)d] [%(module)s:%(funcName)s:%(lineno)d] - %(message)s`
- ERROR/CRITICAL 로그 자동 감지
- 민감 정보 마스킹 처리

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **VERIFY 단계**: 코드 실행 후 로그 분석
- **PLAN 단계**: 에러 패턴 파악을 위한 로그 분석
- **REVIEW 단계**: 런타임 에러 확인

## 입력 요구사항

### 필수 파라미터
- 없음

### 선택적 파라미터
- `target_directory` (string): 프로젝트 루트 디렉토리 경로 (기본값: 상위 디렉토리)
- `log_file_path` (string): 분석할 로그 파일 경로 (기본값: `app.log`)

### 전제 조건
- `app.log` 파일이 존재해야 함 (없으면 경고만 출력)
- 로그 포맷이 표준 `logging.conf` 포맷과 일치해야 함

## 출력 형식

JSON 형식으로 로그 분석 결과를 반환합니다:

```json
{
  "status": "passed | failed",
  "summary": {
    "error_count": "에러 개수",
    "critical_count": "크리티컬 개수",
    "warning_count": "경고 개수",
    "has_severe_errors": "심각한 에러 존재 여부"
  },
  "errors": [
    {
      "timestamp": "타임스탬프",
      "levelname": "ERROR",
      "module": "모듈 이름",
      "funcName": "함수 이름",
      "lineno": "라인 번호",
      "message": "에러 메시지 (마스킹됨)"
    }
  ],
  "criticals": [],
  "warnings": [],
  "code_analysis_guides": [
    {
      "log_entry": {},
      "analysis_guides": [
        {
          "tool": "Codanna | Serena",
          "action": "MCP 액션",
          "query": "검색 쿼리",
          "description": "설명"
        }
      ]
    }
  ],
  "timestamp": "ISO 8601 형식의 타임스탬프"
}
```

## 분석 항목

다음 로그 레벨을 분석합니다:
- **ERROR**: 에러 로그 (심각도: high)
- **CRITICAL**: 크리티컬 로그 (심각도: high)
- **WARNING**: 경고 로그 (심각도: medium)
- **INFO**: 정보 로그 (참고용)

## 제약사항

1. **제안 기반 원칙**: 로그 분석 결과는 제안만 제공하며, 코드를 자동으로 수정하지 않습니다.
2. **민감 정보 마스킹**: 로그 내의 패스워드, 토큰, API 키 등 민감 정보는 자동으로 마스킹됩니다.
3. **MCP 통합 필요**: 실제 코드 분석은 Codanna/Serena MCP를 통해 AI 에이전트가 수행해야 합니다.

## 예시

### 실행 방법
```bash
node skills/log-analyzer/run.js [target_directory] [log_file_path]
```

### 출력 예시
```
📋 Local Log Analyzer
=====================

Analyzing log file: /path/to/app.log

📊 Analysis Summary:
   Total lines: 1250
   Errors: 3
   Criticals: 0
   Warnings: 12

--- Log Analysis Results (JSON) ---
{
  "status": "failed",
  "summary": {
    "error_count": 3,
    "critical_count": 0,
    "warning_count": 12,
    "has_severe_errors": true
  },
  "errors": [...],
  "code_analysis_guides": [...]
}

❌ Severe errors found in logs. Approval blocked.
```

### 결과 해석
- `status: "failed"`: ERROR 또는 CRITICAL 로그가 발견됨 (승인 차단)
- `status: "passed"`: 심각한 에러 없음
- `code_analysis_guides`: ERROR/CRITICAL 로그에 대한 코드 분석 가이드 (Codanna/Serena MCP 사용)

## MCP 통합 가이드

ERROR/CRITICAL 로그가 발견되면 다음 MCP 도구 사용을 안내합니다:
- **Codanna**: `semantic_search_with_context` - 관련 코드 패턴 검색
- **Serena**: `find_symbol` - 심볼 정의 찾기
- **Serena**: `find_referencing_symbols` - 참조 관계 분석

## 관련 스킬

- `security-audit`: 보안 취약점 검사
- `simplifier`: 코드 복잡도 분석
- `visual-verifier`: 웹 프로젝트 시각적 검증

