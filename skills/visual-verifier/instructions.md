# Visual Verifier Skill

## 목적 및 범위

이 스킬은 Chrome DevTools MCP와 연계하여 웹 프로젝트의 렌더링 및 네트워크 문제를 검증합니다. 브라우저를 직접 실행하여 UI가 깨지지 않았는지, 콘솔 에러가 없는지, 네트워크 요청이 올바르게 처리되는지 확인합니다.

### 적용 범위
- 웹 프로젝트 (React, Vue, Angular, Svelte, Next.js, Nuxt, Remix, SvelteKit 등)
- 개발 서버 실행 및 상태 확인
- Chrome DevTools MCP 통합 가이드 제공

## 사용 시점

다음 상황에서 이 스킬을 사용해야 합니다:
- **VERIFY 단계**: 웹 프로젝트의 UI 변경 후 검증
- **REVIEW 단계**: 브라우저 렌더링 결과 확인
- **UI 버그 확인**: 시각적 문제나 콘솔 에러 발견 시

## 입력 요구사항

### 필수 파라미터
- 없음

### 선택적 파라미터
- `port` (number): 개발 서버 포트 번호 (기본값: 3000)

### 전제 조건
- 웹 프로젝트여야 함 (package.json에 웹 프레임워크 의존성 필요)
- 개발 서버가 실행 가능해야 함 (package.json에 dev/start 스크립트 필요)

## 출력 형식

JSON 형식으로 검증 가이드를 반환합니다:

```json
{
  "timestamp": "ISO 8601 형식의 타임스탬프",
  "url": "검증할 URL",
  "verificationSteps": [
    {
      "step": "단계 번호",
      "action": "액션 이름",
      "mcpTool": "사용할 MCP 도구 이름",
      "description": "설명"
    }
  ],
  "checks": {
    "consoleErrors": {
      "description": "검증 기준",
      "severity": "high | medium | low"
    }
  },
  "results": {},
  "recommendations": []
}
```

## 검증 항목

다음 항목들을 검증합니다:
- **콘솔 에러**: JavaScript 에러, React/Vue 에러, 경고
- **네트워크 에러**: 4xx/5xx HTTP 에러
- **느린 요청**: 500ms 이상 걸리는 요청
- **렌더링 문제**: 레이아웃 깨짐, 이미지 로드 실패

## 제약사항

1. **웹 프로젝트만**: Node.js 기반 웹 프로젝트에서만 실행됩니다.
2. **MCP 통합 필요**: 실제 검증은 Chrome DevTools MCP를 통해 AI 에이전트가 수행해야 합니다.
3. **개발 서버 필요**: 개발 서버가 실행 중이거나 자동으로 시작 가능해야 합니다.

## 예시

### 실행 방법
```bash
node skills/visual-verifier/run.js [포트 번호]
```

### 출력 예시
```
🔍 Visual Verifier Agent
========================

1. Detecting stack...
   Detected stack: node (pnpm)

2. Checking if this is a web project...
   ✅ Web project detected

3. Checking dev server...
   ✅ Dev server is already running at http://localhost:3000

4. Generating Chrome DevTools MCP verification guide...

5. Verification Guide:

--- Chrome DevTools MCP Verification Steps ---

Step 1: Navigate to URL
  MCP Tool: browser_navigate
  Description: Navigate to http://localhost:3000

...

--- JSON Report ---
{
  "timestamp": "2024-01-13T09:20:00.000Z",
  "url": "http://localhost:3000",
  ...
}
```

### 결과 해석
- `verificationSteps`: AI 에이전트가 수행해야 할 MCP 도구 호출 단계
- `checks`: 각 검증 항목의 기준 및 심각도
- `recommendations`: 발견된 문제에 대한 권장사항

## Chrome DevTools MCP 도구

이 스킬은 다음 MCP 도구 사용을 안내합니다:
- `browser_navigate`: URL로 이동
- `browser_snapshot`: 접근성 스냅샷 캡처
- `browser_console_messages`: 콘솔 메시지 확인
- `browser_network_requests`: 네트워크 요청 분석

## 관련 스킬

- `log-analyzer`: 서버 로그 분석
- `security-audit`: 보안 취약점 검사
- `simplifier`: 코드 복잡도 분석

