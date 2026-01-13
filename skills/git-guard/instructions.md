# Git Guard Skill

## 목적 및 범위

이 스킬은 Git Guide 규칙 준수를 검증하고, 브랜치 명명 규칙, 커밋 메시지 형식, Issue 번호 포함 여부 등을 확인합니다. 팀의 Git 워크플로우 일관성을 유지하여 협업 효율성을 높입니다.

### 적용 범위
- 브랜치 명명 규칙 검증 (bugfix/{issue_number}-{description}, feature/{issue_number}-{description})
- 커밋 메시지 형식 검증 (Resolved #{Issue No} - {Description})
- Issue 번호 추출 및 검증
- 현재 Git 상태 분석

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **커밋 전**: 커밋 메시지가 Git Guide 규칙을 준수하는지 검증
- **브랜치 생성 후**: 브랜치명이 규칙에 맞는지 확인
- **PR 생성 전**: 모든 규칙 준수 여부 최종 확인
- **CI/CD 파이프라인**: 자동화된 검증 단계

## 입력 요구사항

### 필수 파라미터
- 없음 (기본적으로 현재 Git 저장소 분석)

### 선택적 파라미터
- `target_path` (string): 검증할 Git 저장소 경로 (기본값: 현재 작업 디렉토리)
- `check_branch` (boolean): 브랜치명 검증 여부 (기본값: true)
- `check_commit` (boolean): 최근 커밋 메시지 검증 여부 (기본값: true)

### 전제 조건
- Git 저장소가 초기화되어 있어야 함
- `git` 명령어가 시스템에 설치되어 있어야 함

## 출력 형식

JSON 형식으로 검증 결과를 반환합니다:

```json
{
  "timestamp": "ISO 8601 형식의 타임스탬프",
  "status": "passed | failed | warning",
  "checks": {
    "branch_name": {
      "valid": true,
      "message": "브랜치명이 규칙을 준수합니다",
      "current": "feature/50-cli-command-support",
      "issue_number": "50"
    },
    "commit_message": {
      "valid": true,
      "message": "커밋 메시지가 규칙을 준수합니다",
      "latest": "Resolved #50 - Added CLI command support",
      "issue_number": "50"
    }
  },
  "violations": [
    {
      "type": "branch_name | commit_message",
      "severity": "error | warning",
      "message": "위반 내용 설명",
      "suggestion": "수정 제안"
    }
  ]
}
```

## 검증 기준

다음 기준을 초과하면 제안이 생성됩니다:

### 브랜치 명명 규칙
- **필수 Prefix**: `bugfix/` 또는 `feature/`
- **Issue 번호 포함**: `{prefix}/{issue_number}-{description}` 형식
- **예시**: `feature/50-cli-command-support`, `bugfix/123-fix-login-error`

### 커밋 메시지 규칙
- **필수 형식**: `Resolved #{Issue No} - {Description}`
- **Issue 번호 포함**: 커밋 메시지에 Issue 번호가 반드시 포함되어야 함
- **예시**: `Resolved #50 - Added CLI command support for specific page`

## 제약사항

1. **제안 기반 원칙**: 모든 검증은 제안만 제공하며, 자동으로 수정하지 않습니다.
2. **사용자 승인 필수**: 검증 결과를 사용자가 확인하고 직접 수정해야 합니다.
3. **Git 저장소 필수**: Git이 초기화되지 않은 디렉토리에서는 검증을 수행할 수 없습니다.

## 예시

### 실행 방법
```bash
node skills/git-guard/run.js [target_directory]
```

### 출력 예시
```
🔒 Git Guard Agent
========================

1. Checking Git repository...
   ✓ Git repository found

2. Validating branch name...
   ✓ Branch name: feature/50-cli-command-support
   ✓ Matches pattern: feature/{issue_number}-{description}
   ✓ Issue number extracted: 50

3. Validating commit message...
   ✓ Latest commit: Resolved #50 - Added CLI command support
   ✓ Matches pattern: Resolved #{Issue No} - {Description}
   ✓ Issue number extracted: 50

--- JSON Output ---
{
  "timestamp": "2024-01-13T09:20:00.000Z",
  "status": "passed",
  "checks": {
    "branch_name": {
      "valid": true,
      "message": "브랜치명이 규칙을 준수합니다",
      "current": "feature/50-cli-command-support",
      "issue_number": "50"
    },
    "commit_message": {
      "valid": true,
      "message": "커밋 메시지가 규칙을 준수합니다",
      "latest": "Resolved #50 - Added CLI command support",
      "issue_number": "50"
    }
  },
  "violations": []
}
```

### 결과 해석
- `status: "passed"`: 모든 검증 통과
- `status: "failed"`: 필수 규칙 위반 발견
- `status: "warning"`: 경고 수준의 문제 발견

## 관련 스킬

- `security-audit`: 보안 취약점 검사
- `log-analyzer`: 런타임 에러 분석
- `visual-verifier`: 웹 프로젝트 시각적 검증

