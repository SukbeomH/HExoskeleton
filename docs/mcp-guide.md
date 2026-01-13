# MCP(Model Context Protocol) 활용 가이드

이 가이드는 AI의 감각 기관을 확장하여 **검증 피드백 루프를 견고하게** 만드는 MCP 서버 설정 및 활용 방법을 설명합니다.

## 목적 및 철학

**핵심 목적**: AI가 '작동하는 것처럼 보이는 코드'가 아닌 **'실제로 잘 작동하는 코드'**를 작성하도록 돕는 것입니다.

각 MCP 서버는 단순한 도구가 아닌, **검증 피드백 루프의 핵심 구성 요소**입니다. AI가 코드를 작성한 후, 이 도구들을 통해 스스로 검증하고 문제를 발견하며 수정하는 루프를 형성합니다. 이는 최종 결과물의 품질을 **2~3배 향상시키는 가장 중요한 요소**입니다.

## 어시스턴트별 MCP 설정 방법

어시스턴트별로 MCP 설정 방식이 다르기 때문에, 현재 프로젝트의 `.mcp.json`을 각 도구가 인식할 수 있도록 **어시스턴트 맞춤형 브릿지 설정**이 필요합니다.

### Cursor IDE 설정

**중요**: Cursor는 프로젝트 루트의 `.mcp.json`을 자동으로 읽지 않으므로, 수동으로 등록해야 합니다.

**설정 방법**:
1. **Cursor Settings** (Cmd+Shift+J 또는 Ctrl+Shift+J) → **Features** → **MCP Servers**로 이동
2. **+ Add New MCP Server** 클릭
3. 각 서버를 하나씩 추가:
   - **Type**: `command` 선택
   - **Name**: 서버 이름 (예: `Serena`, `Codanna`)
   - **Command**: `.mcp.json`에 정의된 전체 명령어 입력
     - 예: `npx -y @modelcontextprotocol/server-serena`
   - **Environment Variables** (필요한 경우): Proxymock 등 환경 변수가 필요한 서버의 경우 추가

**빠른 설정 가이드**:
```bash
# 프로젝트 루트에서 실행
scripts/core/sync-mcp.sh
```

이 스크립트는 `.mcp.json`을 파싱하여 Cursor 설정에 복사하기 쉬운 형식으로 출력합니다.

**이름 충돌 방지**:
- 여러 프로젝트를 동시에 개발하는 경우, 프로젝트별 접두어를 사용하세요
- 예: `[ProjectName]-serena`, `[ProjectName]-codanna`

### Claude Code (CLI) 설정

Claude Code는 프로젝트 루트의 `.mcp.json`을 자동으로 인식합니다.

**확인 방법**:
```bash
cd /path/to/project
claude mcp list  # MCP 서버 목록 확인
```

**수동 등록** (필요한 경우):
```bash
claude mcp add --name serena --command "npx" --args "-y" "@modelcontextprotocol/server-serena"
```

### Claude Desktop 설정

Claude Desktop은 전역 설정을 사용합니다.

**설정 파일 위치**:
- macOS: `~/.config/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/claude_desktop_config.json`

**설정 방법**:
1. 설정 파일을 열고 (없으면 생성)
2. `.mcp.json`의 `mcpServers` 섹션을 복사하여 추가
3. Claude Desktop 재시작

**주의**: Claude Desktop은 전역 설정이므로 모든 프로젝트에서 동일한 MCP 서버를 사용합니다. 프로젝트별로 다른 설정이 필요한 경우 Claude Code를 사용하세요.

### Windsurf / VS Code 설정

Windsurf는 VS Code 확장 프로그램을 통해 MCP를 설정합니다.

**설정 방법**:
1. VS Code 확장 프로그램에서 'MCP Client' 또는 유사한 확장 설치
2. 설정 파일 (`.vscode/mcp.json` 또는 전역 설정)에 `.mcp.json`의 내용 추가
3. 확장 프로그램의 문서를 참조하여 정확한 설정 방법 확인

## 초기 구성 의무 (Initial Setup Mandate)

코드를 한 줄이라도 작성하기 전에 다음 초기 구성 단계를 **반드시** 순서대로 완료해야 합니다. 이는 RIPER-5 프로토콜의 필수 요구사항입니다.

### 1. Shrimp Task Manager 초기화

**목적**: 작업 흐름을 구조화하고, 지속적인 메모리 및 프로젝트 코딩 표준을 정의합니다.

**실행 명령**:
```bash
# 프로젝트 규칙 초기화
mcp_shrimp-task-manager_init_project_rules

# 온보딩 확인
mcp_shrimp-task-manager_check_onboarding_performed
```

**이유**: SDD(Spec-Driven Development)의 단일 진실 공급원 역할을 하며, 작업을 구조화하고 종속성을 추적합니다.

### 2. Serena 활성화 및 온보딩

**목적**: 코드베이스에 대한 초기 지식(Memories)과 심볼 기반 검색 능력을 구축합니다.

**실행 명령**:
```bash
# 프로젝트 활성화
mcp_serena_activate_project [project-name]

# 온보딩 수행
mcp_serena_onboarding
```

**이유**: IDE 수준의 정확도와 효율성을 확보하기 위해 프로젝트 구조를 파악하고 메모리를 저장합니다.

### 3. Codanna 프로파일 로드

**목적**: Semantic Search 및 X-ray vision 기능을 활용합니다.

**확인 사항**:
- Codanna 프로파일 및 관련 명령(`/codanna:x-ray`, `/codanna:symbol`)이 로드되었는지 확인
- 대규모 프로젝트의 경우 색인 완료 확인

**이유**: 코드베이스에 대한 tight context를 확보하고 grep-and-hope loops를 방지합니다.

### 4. 환경 변수 설정 (선택사항)

일부 MCP 서버는 환경 변수가 필요할 수 있습니다. 필요한 경우 프로젝트 루트에 `.env` 파일을 생성하세요:

```bash
# Proxymock MCP (선택사항)
PROXYMOCK_API_KEY=your-proxymock-api-key
PROXYMOCK_ENDPOINT=https://api.proxymock.com
```

**보안 주의사항**:
- `.env` 파일은 절대 git에 커밋하지 마세요.
- `.gitignore`에 `.env`가 포함되어 있는지 확인하세요.
- 팀원들과 공유해야 하는 환경 변수 목록은 `.env.sample` 파일에 플레이스홀더로 저장하세요.

### 초기 구성 완료 확인

위의 모든 초기 구성 작업이 완료되었다는 명시적인 확인을 받은 후에만, **[MODE: RESEARCH]**로 전환하여 사용자 요청에 대한 분석을 시작할 수 있습니다.

## 전문 MCP 도구 세트 (Serena, Codanna, Shrimp, Context7)

이 섹션은 RIPER-5 프로토콜의 핵심 도구들에 대한 상세한 가이드입니다. 이 도구들은 AI가 업계 최고 수준의 개발 환경을 구축할 수 있도록 돕습니다.

### 1. Serena MCP

**목적**: 심볼 기반 검색 및 정밀 편집 도구. IDE 수준의 정확도로 코드를 검색하고 수정합니다.

**설정 방법**:
- 추가 설정 불필요 (로컬 프로젝트 활성화)

**초기 구성 의무 (Initial Setup Mandate)**:
1. 프로젝트 활성화: `mcp_serena_activate_project` 명령으로 프로젝트 활성화
2. 온보딩 수행: `mcp_serena_onboarding` 명령으로 프로젝트 구조 파악 및 메모리 저장
3. 색인 확인: 대규모 프로젝트의 경우 색인 완료 확인

**RIPER-5 모드별 활용**:

- **RESEARCH 모드**:
  - `find_symbol`: 심볼 이름으로 정확한 위치 찾기
  - `find_referencing_symbols`: 특정 심볼을 참조하는 모든 위치 찾기
  - `get_symbols_overview`: 파일의 심볼 구조 개요 파악
- **EXECUTE 모드 (필수)**:
  - `replace_symbol_body`: 함수/클래스 본문 정밀 수정
  - `insert_after_symbol`: 심볼 뒤에 코드 삽입
  - `insert_before_symbol`: 심볼 앞에 코드 삽입
  - `rename_symbol`: 심볼 이름 변경 (전체 코드베이스에 자동 반영)
  - `mcp_serena_create_text_file`: 전체 파일 덮어쓰기 (복잡한 변경 시)

**금지된 도구**:
- `edit_file`: 신뢰할 수 없고 위험하므로 사용 금지
- `replace_regex`: 너무 위험하므로 사용 포기

**검증 피드백 루프에서의 역할**:
- EXECUTE 모드에서 필수 사용
- Fourth Principle: 수정 후 즉시 `read_file`로 검증
- 외과적 정밀도(surgically precise replacement)로 코드 수정

**사용 예시**:
```
[MODE: EXECUTE]
1. Serena의 find_symbol으로 수정할 함수 찾기
2. replace_symbol_body로 함수 본문 정밀 수정
3. read_file로 변경 내용 즉시 검증
4. 문제 발견 시 재수정 또는 PLAN 모드로 복귀
```

### 2. Codanna MCP

**목적**: 시맨틱 검색 및 사실 기반 분석 도구. X-ray vision을 제공하여 코드베이스의 구조와 종속성을 신속하게 파악합니다.

**설정 방법**:
- 추가 설정 불필요 (로컬 프로젝트 색인)

**초기 구성 의무**:
1. 프로파일 로드: Codanna 프로파일 및 관련 명령(`/codanna:x-ray`, `/codanna:symbol`) 로드 확인
2. 색인 확인: 대규모 프로젝트의 경우 색인 완료 확인

**RIPER-5 모드별 활용**:

- **RESEARCH 모드 (필수)**:
  - `semantic_search_with_context`: 자연어로 관련 코드 검색 (전체 컨텍스트 포함)
  - `semantic_search_docs`: 문서 검색
  - `find_symbol`: 심볼 이름으로 찾기
  - `search_symbols`: 퍼지 매칭으로 심볼 검색
- **PLAN 모드 (필수)**:
  - `analyze_impact`: 변경사항이 전체 프로젝트에 미치는 영향 분석
  - `find_callers`: 함수를 호출하는 모든 위치 찾기
  - `get_calls`: 함수가 호출하는 모든 함수 찾기

**검증 피드백 루프에서의 역할**:
- RESEARCH 모드에서 필수 사용
- grep-and-hope loops 방지
- <10ms lookups로 효율적인 검색
- 추측 금지 원칙(S2, S3) 준수

**사용 예시**:
```
[MODE: RESEARCH]
1. Codanna의 semantic_search_with_context로 관련 코드 검색
2. analyze_impact로 변경 영향 분석
3. 정확한 사실을 기반으로 분석 진행 (추측 금지)
```

### 3. Shrimp Task Manager MCP

**목적**: 구조화된 작업 관리 및 지속적 메모리 도구. SDD(Spec-Driven Development)의 단일 진실 공급원 역할을 합니다.

**설정 방법**:
- 추가 설정 불필요

**초기 구성 의무**:
1. 프로젝트 규칙 초기화: `mcp_shrimp-task-manager_init_project_rules` 실행
2. 온보딩 확인: `mcp_shrimp-task-manager_check_onboarding_performed`로 온보딩 여부 확인

**RIPER-5 모드별 활용**:

- **RESEARCH 모드**:
  - `research_mode`: 체계적인 연구 모드 시작
- **PLAN 모드 (필수)**:
  - `plan_task`: 요청을 구조화된 개발 작업으로 변환
  - `analyze_task`: 작업 요구사항 심층 분석
  - `reflect_task`: 분석 결과 검토 및 개선
  - `split_tasks`: 복잡한 작업을 하위 작업으로 분해
- **EXECUTE 모드**:
  - `execute_task`: 특정 작업 실행 가이드 조회
  - `update_task`: 진행 상황 업데이트
- **REVIEW 모드 (필수)**:
  - `reflect_task`: 작업 흐름 전체 검토 및 개선
  - `verify_task`: 작업 완료 검증 및 점수 부여

**검증 피드백 루프에서의 역할**:
- PLAN 모드에서 작업 구조화
- EXECUTE 모드에서 진행 상황 로그
- REVIEW 모드에서 작업 검토 및 개선
- SDD의 단일 진실 공급원 역할

**사용 예시**:
```
[MODE: PLAN]
1. Shrimp의 plan_task로 작업 구조화
2. analyze_task로 요구사항 심층 분석
3. split_tasks로 하위 작업 분해
4. 사용자 승인 대기

[MODE: REVIEW]
1. Shrimp의 reflect_task로 작업 검토
2. verify_task로 완료 검증
3. 개선 사항 제안
```

### 4. Context7 MCP

**목적**: 대규모 코드베이스 컨텍스트 최적화 도구. 관련성 높은 컨텍스트만 선별하여 토큰 효율을 극대화합니다.

**설정 방법**:
- 추가 설정 불필요

**RIPER-5 모드별 활용**:

- **RESEARCH 모드**:
  - `resolve-library-id`: 라이브러리 ID 확인
  - `query-docs`: 라이브러리 문서 검색
- **모든 모드**:
  - 대규모 코드베이스에서 필요한 컨텍스트만 선별하여 토큰 절약

**검증 피드백 루프에서의 역할**:
- 토큰 효율 극대화
- 관련성 높은 컨텍스트만 선별하여 응답 품질 향상

## MCP 서버별 설정 및 활용

### 1. Chrome DevTools MCP

**목적**: 브라우저 UI 검증, 콘솔 에러 확인, 네트워크 분석

**설정 방법**:
- 추가 설정 불필요 (로컬 브라우저 사용)

**검증 피드백 루프에서의 역할**:
- **UI 변경 검증**: UI 코드를 수정한 후 반드시 브라우저를 열고 렌더링 결과 확인
- **콘솔 에러 확인**: JavaScript 런타임 에러를 직접 확인하여 수정
- **네트워크 분석**: API 요청/응답을 확인하여 올바르게 처리되는지 검증
- **성능 분석**: 렌더링 성능 및 네트워크 성능을 분석하여 최적화

**필수 사용 가이드라인**:
- **UI 변경 시**: 반드시 Chrome DevTools MCP로 렌더링 결과와 콘솔 에러를 확인할 것
- 단순 유닛 테스트를 넘어 브라우저를 직접 열고 UI가 깨지지 않았는지 확인
- 네트워크 로그에 에러가 없는지 분석

**사용 예시**:
```
AI가 UI 컴포넌트를 수정한 후:
1. Chrome DevTools MCP를 통해 브라우저 열기
2. 페이지 렌더링 확인
3. 콘솔 에러 확인 및 수정
4. 네트워크 요청 확인
5. 모든 것이 정상인지 확인 후 완료
```

### 2. Proxymock MCP

**목적**: 실제 운영 트래픽 재현 및 API 엣지 케이스 검증

**설정 방법**:
1. Proxymock 계정 생성 (또는 자체 호스팅)
2. API Key 생성
3. 환경 변수에 API Key 및 Endpoint 설정

**검증 피드백 루프에서의 역할**:
- **실제 데이터 패턴 검증**: API 로직 수정 후 실제 운영 트래픽 데이터와의 정합성 검증
- **엣지 케이스 검증**: 예외 상황과 엣지 케이스를 검증하여 '작동하는 것처럼 보이는 코드'가 아닌 '실제로 잘 작동하는 코드' 보장
- **데이터 변형 처리**: 실제 운영 환경의 다양한 데이터 형식을 처리할 수 있는지 확인

**필수 사용 가이드라인**:
- **API 로직 수정 후**: 반드시 Proxymock MCP를 통해 실제 데이터 패턴과의 정합성을 검증할 것
- 실제 운영 트래픽 데이터를 샌드박스에서 재현하여 검증

**사용 예시**:
```
AI가 API 엔드포인트를 수정한 후:
1. Proxymock MCP를 통해 실제 운영 트래픽 데이터 로드
2. 수정된 API가 실제 데이터를 올바르게 처리하는지 확인
3. 엣지 케이스 (null 값, 빈 배열, 매우 긴 문자열 등) 검증
4. 모든 케이스가 통과하는지 확인 후 완료
```

### 3. Playwright MCP

**목적**: 자동화된 E2E 테스트 실행

**설정 방법**:
- 추가 설정 불필요 (로컬 브라우저 사용)

**검증 피드백 루프에서의 역할**:
- **사용자 시나리오 검증**: 단위 테스트를 통과한 코드가 실제 사용자 시나리오에서도 올바르게 동작하는지 확인
- **통합 테스트**: 여러 컴포넌트가 함께 동작할 때 발생할 수 있는 문제를 발견
- **자동화된 검증**: 브라우저를 자동으로 제어하여 사용자 관점에서의 검증 수행

**사용 예시**:
```
AI가 기능을 구현한 후:
1. Playwright MCP를 통해 E2E 테스트 시나리오 작성
2. 사용자 플로우 전체를 자동으로 실행
3. 각 단계에서 예상대로 동작하는지 확인
4. 문제 발견 시 수정 후 재실행
```

## RIPER-5 모드별 MCP 도구 활용 가이드

RIPER-5 프로토콜의 각 모드에서 어떤 MCP 도구를 어떤 타이밍에 사용해야 하는지 상세히 설명합니다.

### MODE: RESEARCH (Codanna 의무 사용)

**필수 도구**: Codanna MCP

**활용 시점 및 방법**:
1. **프로젝트 시작 시**:
   - Codanna의 `semantic_search_with_context`로 관련 코드 검색
   - `get_index_info`로 색인 상태 확인
2. **코드 구조 파악**:
   - `find_symbol`로 핵심 심볼 찾기
   - `get_calls`, `find_callers`로 종속성 매핑
3. **불확실한 문제 해결**:
   - 추측 금지: `semantic_search_with_context`로 정확한 사실 확인
   - `analyze_impact`로 영향 범위 파악

**보조 도구**:
- **Serena MCP**: `get_symbols_overview`로 파일 구조 파악
- **Shrimp Task Manager**: `research_mode`로 체계적인 연구 모드 시작
- **Context7 MCP**: 대규모 코드베이스에서 관련 컨텍스트만 선별

**금지 사항**:
- 파일 전체 읽기
- `grep` 사용
- 추측 기반 분석

### MODE: PLAN (Shrimp & Codanna 의무 사용)

**필수 도구**: Shrimp Task Manager, Codanna MCP

**활용 시점 및 방법**:
1. **작업 구조화**:
   - Shrimp의 `plan_task`로 요청을 구조화된 개발 작업으로 변환
   - `analyze_task`로 요구사항 심층 분석
   - `split_tasks`로 복잡한 작업을 하위 작업으로 분해
2. **영향 분석**:
   - Codanna의 `analyze_impact`로 핵심 인터페이스 변경의 영향 평가
   - `find_callers`로 호출 관계 분석
3. **계획 승인 게이트**:
   - 상세 기술 명세 작성 후 사용자 명시적 승인 대기
   - 승인 없이 EXECUTE 모드로 전환 금지

**보조 도구**:
- **Context7 MCP**: 관련 라이브러리 문서 검색

**명세 필수 구성 요소**:
- 개요 및 문제 설명
- 목표 및 기술 요구사항
- 제안된 솔루션/디자인 (의사 코드 포함)
- 테스트 계획
- 작업 추정 및 타임라인

### MODE: EXECUTE (Serena MCP 의무 사용)

**필수 도구**: Serena MCP

**활용 시점 및 방법**:
1. **심볼 검색**:
   - Serena의 `find_symbol`로 수정할 심볼 찾기
   - `find_referencing_symbols`로 참조 위치 확인
2. **정밀 편집**:
   - `replace_symbol_body`로 함수/클래스 본문 수정
   - `insert_after_symbol`, `insert_before_symbol`로 코드 삽입
   - `rename_symbol`로 심볼 이름 변경
   - 복잡한 변경 시 `mcp_serena_create_text_file`로 전체 파일 덮어쓰기
3. **Fourth Principle 검증**:
   - 수정 후 즉시 `read_file`로 변경 내용 확인
   - 문제 발견 시 재수정 또는 PLAN 모드로 복귀

**금지된 도구**:
- `edit_file`: 신뢰할 수 없고 위험
- `replace_regex`: 너무 위험

**보조 도구**:
- **Chrome DevTools MCP**: UI 변경 시 실시간으로 브라우저에서 확인
- **Shrimp Task Manager**: `update_task`로 진행 상황 로그

### MODE: REVIEW (Shrimp Task Manager 의무 사용)

**필수 도구**: Shrimp Task Manager

**활용 시점 및 방법**:
1. **작업 검토**:
   - Shrimp의 `reflect_task`로 작업 흐름 전체 검토
   - `verify_task`로 완료 검증 및 점수 부여
2. **일치 확인**:
   - 최종 구현이 최종 계획과 완벽하게 일치하는지 확인
   - 사소한 편차도 명시적으로 플래그 지정


## 검증 피드백 루프 통합 활용

각 MCP 도구는 검증 피드백 루프의 특정 단계에서 활용됩니다:

### RESEARCH 단계
- **Codanna MCP**: 코드베이스 구조 파악 및 사실 기반 분석
- **Serena MCP**: 심볼 구조 개요 파악
- **Shrimp Task Manager**: 체계적인 연구 모드 시작
- **Context7 MCP**: 관련 컨텍스트 선별

### PLAN 단계
- **Shrimp Task Manager**: 작업 구조화 및 계획 수립
- **Codanna MCP**: 영향 분석

### EXECUTE 단계
- **Serena MCP**: 정밀 편집 (필수)
- **Chrome DevTools MCP**: UI 변경 시 실시간으로 브라우저에서 확인
- **Shrimp Task Manager**: 진행 상황 로그

### VERIFY 단계 (핵심)
- **Chrome DevTools MCP**: UI 및 런타임 검증
- **Proxymock MCP**: 실제 데이터 패턴 검증
- **Playwright MCP**: E2E 시나리오 검증
- **Serena MCP**: Fourth Principle 검증 (read_file)
- **Codanna MCP**: 로그 분석 시 에러 위치 정확히 찾기 (log_analyzer 스킬 연계)

### REVIEW 단계
- **Shrimp Task Manager**: 작업 검토 및 개선 (필수)

## 트러블슈팅

### MCP 서버가 시작되지 않는 경우

1. **환경 변수 확인**: `.env` 파일에 필요한 환경 변수가 모두 설정되어 있는지 확인 (해당 MCP 서버가 환경 변수를 요구하는 경우)
2. **의존성 확인**: `npx`가 정상적으로 작동하는지 확인 (`node --version`)

### Chrome DevTools MCP가 브라우저를 열지 않는 경우

1. **Chrome 설치 확인**: Chrome 또는 Chromium이 설치되어 있는지 확인
2. **헤드리스 모드**: CI 환경에서는 헤드리스 모드로 실행되도록 설정

### Proxymock MCP가 데이터를 가져오지 못하는 경우

1. **API Key 확인**: 환경 변수의 API Key가 유효한지 확인
2. **네트워크 확인**: Proxymock 서버에 접근 가능한지 확인
3. **데이터 존재 확인**: 실제 운영 트래픽 데이터가 Proxymock에 저장되어 있는지 확인

## 보안 모범 사례

1. **환경 변수 관리**: 모든 비밀키는 환경 변수로 관리하고 `.env` 파일은 git에 커밋하지 않음
2. **권한 최소화**: 각 MCP 서버에 필요한 최소한의 권한만 부여
3. **토큰 로테이션**: 정기적으로 API 토큰을 갱신하여 보안 강화
4. **로컬 테스트**: 프로덕션 환경의 민감한 데이터를 로컬에서 테스트할 때는 샘플 데이터 사용

## 참고 자료

- [MCP 공식 문서](https://modelcontextprotocol.io)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Playwright 문서](https://playwright.dev)

---

**핵심 메시지**: 이 MCP 도구들은 AI가 스스로 검증할 수 있는 가장 견고한 피드백 루프를 만드는 것이 목적입니다. 각 도구를 적절히 활용하여 '작동하는 것처럼 보이는 코드'가 아닌 '실제로 잘 작동하는 코드'를 작성하세요.

