# Claude Knowledge Updater Skill

## 목적 및 범위

이 스킬은 검증 피드백 루프 결과를 CLAUDE.md의 'Lessons Learned' 섹션에 자동으로 추가합니다. 이를 통해 팀의 지식이 복리로 축적되도록 돕습니다.

### 적용 범위
- 검증 피드백 루프 실행 결과 기록
- CLAUDE.md의 'Lessons Learned' 섹션 자동 업데이트
- 검증 결과를 마크다운 형식으로 변환

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **Approve 단계**: 검증 피드백 루프 실행 후 결과 기록
- **지식 축적**: 검증 결과를 팀 지식으로 변환
- **자동화**: 검증 결과의 자동 기록

## 입력 요구사항

### 필수 파라미터
- `verification_result_json` (string): 검증 결과 JSON 문자열

### 전제 조건
- CLAUDE.md 파일이 프로젝트 루트에 존재해야 함
- 검증 결과가 JSON 형식이어야 함

## 출력 형식

CLAUDE.md 파일에 마크다운 형식으로 결과를 추가합니다:

```markdown
#### [YYYY-MM-DD] 검증 피드백 루프 실행 결과

- **코드 복잡도 분석**: N개의 개선 제안 발견
  - suggestion_type: suggestion_message
- **검증 에러**: N개의 에러 발견
  - error_message
- **보안 감사**: N개의 취약점 발견
  - package_name: severity
- **적용 여부**: 승인됨 | 거부됨 | 건너뜀
```

## 처리 프로세스

1. **섹션 확인**: CLAUDE.md에 'Lessons Learned' 섹션이 있는지 확인
2. **섹션 생성**: 없으면 자동으로 생성
3. **결과 변환**: 검증 결과를 마크다운 형식으로 변환
4. **파일 업데이트**: CLAUDE.md에 결과 추가

## 제약사항

1. **JSON 형식 필수**: 검증 결과는 반드시 JSON 형식이어야 합니다.
2. **CLAUDE.md 필수**: 프로젝트 루트에 CLAUDE.md 파일이 존재해야 합니다.
3. **읽기 전용 원칙**: 이 스킬은 CLAUDE.md만 수정하며, 다른 파일은 변경하지 않습니다.

## 예시

### 실행 방법
```bash
node skills/claude-knowledge-updater/run.js '<검증 결과 JSON>'
```

### 입력 예시
```json
{
  "steps": {
    "verify": {
      "simplifier": {
        "suggestions": [
          {
            "type": "long_function",
            "message": "Function is too long"
          }
        ]
      },
      "security": {
        "status": "completed",
        "vulnerabilities": []
      }
    },
    "approve": {
      "status": "approved"
    }
  }
}
```

### 출력 예시
CLAUDE.md에 다음 내용이 추가됩니다:

```markdown
### 📚 Lessons Learned (자동 업데이트)

이 섹션은 검증 피드백 루프 실행 결과가 자동으로 추가됩니다.

#### [2024-01-13] 검증 피드백 루프 실행 결과

- **코드 복잡도 분석**: 1개의 개선 제안 발견
  - long_function: Function is too long
- **보안 감사**: 취약점 없음
- **적용 여부**: 승인됨
```

## 관련 스킬

이 스킬은 다른 검증 스킬들의 결과를 종합하여 사용됩니다:
- `simplifier`: 코드 복잡도 분석 결과
- `security-audit`: 보안 감사 결과
- `log-analyzer`: 로그 분석 결과
- `visual-verifier`: 시각적 검증 결과

