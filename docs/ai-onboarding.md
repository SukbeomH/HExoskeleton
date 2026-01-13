<!--
이 문서는 AI와 함께 작업하는 팀원들을 위한 온보딩 가이드입니다.
AI를 단순한 도구가 아닌 '함께 성장하는 페어 프로그래머'로 대우하는 방법을 설명합니다.
-->

# 🚀 AI-Native 팀 온보딩 가이드

우리 팀은 AI를 단순한 도구가 아닌 **'함께 성장하는 페어 프로그래머'**로 대우합니다. 이 가이드는 AI와 함께 효율적으로 코드를 작성하고, 팀의 지식을 복리로 축적하는 방법을 설명합니다.

## 1. 초기 환경 설정 (Getting Started)

### Docker를 통한 GUI 실행 (가장 권장 - 로컬 도구 설치 불필요)

로컬에 Node.js나 Python을 설치하지 않고도 Docker로 즉시 시작할 수 있습니다:

```bash
# 1. 주입 대상 프로젝트 경로를 환경 변수로 설정 (선택사항)
export TARGET_PROJECT_PATH=/path/to/target/project

# 2. Docker Compose로 GUI 실행
mise run docker-up
# 또는 직접 실행
docker-compose up -d

# 3. 브라우저에서 접속
# - 프론트엔드: http://localhost:3000
# - 백엔드 API: http://localhost:8000

# 4. GUI에서 다음 단계 수행:
#    - 대상 프로젝트 경로 입력
#    - 스택 자동 감지 확인
#    - 주입할 자산 선택 (.claude/, scripts/, CLAUDE.md, mise.toml 등)
#    - 주입 옵션 설정 (백업, 병합 등)
#    - 주입 실행
#    - AI 초기화 프롬프트 복사하여 Cursor/Claude Code에 붙여넣기

# 5. 종료
mise run docker-down
```

**Docker 사용 시 장점**:
- 로컬 도구 설치 불필요 (Node.js, Python, uv 등)
- 격리된 환경에서 안전하게 실행
- 팀원 모두 동일한 환경 보장
- Agent Skills가 컨테이너 내에서 실행되어 호스트 시스템에 영향 없음

### 로컬 환경에서 GUI 실행

```bash
# 1. GUI 실행
mise run gui
# 브라우저에서 http://localhost:3000 접속

# 2. GUI에서 다음 단계 수행:
#    - 대상 프로젝트 경로 입력
#    - 스택 자동 감지 확인
#    - 주입할 자산 선택 (.claude/, scripts/, CLAUDE.md, mise.toml 등)
#    - 주입 옵션 설정 (백업, 병합 등)
#    - 주입 실행
#    - AI 초기화 프롬프트 복사하여 Cursor/Claude Code에 붙여넣기
```

**AI 초기화 프롬프트**: 주입 완료 후 GUI에서 자동 생성된 프롬프트를 복사하여 Cursor/Claude Code에 붙여넣으면, AI가 즉시 프로젝트 환경을 이해하고 작업을 시작할 수 있습니다.

### 수동 설정 (GUI 없이)

모든 개발 환경은 `mise`를 통해 표준화되어 있습니다. 터미널에서 다음 명령어를 실행하여 도구들을 설치하세요.

```bash
# 1. 툴체인 자동 설치 (Node, Python, AI CLI 등)
mise install

# 2. 보일러플레이트 파일 수동 복사
cp -r .claude/ scripts/ CLAUDE.md mise.toml <your-project>/

# 3. 대상 프로젝트로 이동
cd <your-project>
mise install

# 4. 검증
mise run verify

# 5. AI 권한 설정 (사전 정의된 화이트리스트 로드)
# .claude/settings.json의 설정을 확인하세요.
```

**이유**: `mise`를 통한 환경 표준화는 팀 전체가 동일한 도구 버전을 사용하게 하여 "내 컴퓨터에서는 되는데" 문제를 방지합니다.

### MCP 서버 설정 (필수)

보일러플레이트 주입 후, 프로젝트 루트의 `.mcp.json` 파일을 어시스턴트에 등록해야 AI가 Codanna, Serena, Shrimp 등의 MCP 도구를 사용할 수 있습니다.

**빠른 설정 (Cursor 사용자)**:
```bash
# 프로젝트 루트에서 실행
mise run mcp-sync
```

이 명령어는 `.mcp.json`을 파싱하여 Cursor 설정에 복사하기 쉬운 형식의 가이드를 생성합니다. 생성된 Command 필드에는 `mise x --`가 포함되어 있어 프로젝트 환경이 자동으로 적용됩니다.

**설정 방법**:
1. **Cursor IDE**:
   - `mise run mcp-sync` 실행하여 가이드 생성
   - Cursor Settings → Features → MCP Servers에서 생성된 가이드 복사
   - 이름 충돌 방지를 위해 `[ProjectName]-[ServerName]` 형식의 별칭 사용 권장

2. **Claude Code**:
   - 프로젝트 루트의 `.mcp.json`이 자동으로 인식됩니다
   - 확인: `claude mcp list`

3. **Claude Desktop**:
   - 전역 설정 파일(`~/.config/claude_desktop_config.json`)에 `.mcp.json`의 내용을 병합

**중요**: MCP 서버가 등록되지 않으면 AI가 Codanna(시맨틱 검색), Serena(정밀 편집), Shrimp(작업 관리) 등의 핵심 도구를 사용할 수 없어 RIPER-5 프로토콜을 제대로 수행할 수 없습니다.

자세한 설정 방법은 [MCP 가이드](../docs/mcp-guide.md)를 참조하세요.

## 2. 핵심 워크플로우: "The 3-Step Loop"

우리 팀은 결과물의 품질을 보장하기 위해 반드시 다음 루프를 준수합니다.

### **Step 1: Plan (설계 공유)**

* **방법**: 작업 시작 시 반드시 `[MODE: PLAN]` 또는 `Plan 모드`로 시작합니다.
* **목적**: AI가 코드를 쓰기 전, 팀의 컨벤션과 `spec.md`를 이해했는지 확인합니다.
* **팁**: "이 기능을 구현하기 위한 계획을 세워줘"라고 요청하고, 제안된 파일 구조와 로직을 먼저 승인하세요.
* **도구 활용**:
  - **Shrimp Task Manager**: 작업을 구조화된 개발 작업으로 변환
  - **Codanna**: 변경사항이 전체 프로젝트에 미치는 영향 분석

**이유**: 계획 단계에서 충분히 다듬으면, 실행 단계에서 AI가 한 번에 완성할 수 있어 전체 시간이 단축됩니다.

### **Step 1.5: 프로젝트 내부 제어권 획득 (Post-Injection)**

* **시점**: 보일러플레이트 주입이 완료된 직후
* **방법**:
  1. 원본 보일러플레이트 GUI를 종료합니다
  2. 주입된 프로젝트 디렉토리로 이동합니다
  3. 주입된 프로젝트 내부에서 `mise run gui`를 실행합니다
* **목적**: 주입된 프로젝트가 자생적인 AI-Native 생태계로 동작하도록 합니다
* **이점**:
  - **로컬 최적화**: 프로젝트의 `app.log` 파일이 실시간으로 GUI에 매핑되어 로컬 로그 분석이 가능합니다
  - **독립성**: 주입된 `gui/backend`는 현재 프로젝트의 루트를 기준으로 동작하여 원본 보일러플레이트와 분리됩니다
  - **프로젝트 전용 Agent Hub**: 해당 프로젝트에 맞게 커스터마이징된 `instructions.md`와 `schema.json`을 기반으로 에이전트 스킬을 관리할 수 있습니다
  - **지식 업데이트**: GUI를 통해 수정된 `CLAUDE.md`의 내용이 해당 프로젝트 폴더 내에 즉시 저장되어 AI의 다음 작업에 반영됩니다

**이유**: 각 프로젝트는 독립적인 AI-Native 생태계로 동작해야 하며, 원본 보일러플레이트와의 혼선을 방지하기 위함입니다.

### **Step 2: Build (자동 구현)**

* **방법**: 계획이 승인되면 `[MODE: EXECUTE]`로 전환하여 AI가 코드를 작성하게 합니다.
* **도구 활용**:
  - **Serena**: 심볼 기반 정밀 편집 (IDE 수준의 정확도)
  - **Fourth Principle**: 수정 후 즉시 `read_file`로 검증
* **주의**: 대량의 파일 수정이 일어날 때는 터미널을 지켜보며 이상 동작 시 즉시 중단(`Ctrl+C`)하세요.

**이유**: 계획이 충분히 구체적이면, AI가 자동으로 구현하는 것이 수동으로 하나씩 지시하는 것보다 빠르고 정확합니다.

### **Step 3: Verify (자율 검증)**

* **방법**: 구현 직후 `/verify-app` 커맨드 또는 통합 검증 루프를 실행합니다.
* **통합 검증 루프**: `node scripts/verify-feedback-loop.js [target_directory]` 실행 시 다음 에이전트들이 자동 실행됩니다:
  - **기본 검증** (`auto_verify.sh`): 린트, 타입 체크, 테스트
  - **코드 단순화 분석** (`simplifier.js`): 복잡도 분석 및 리팩토링 제안
  - **보안 감사** (`security-audit.js`): 취약점 스캔
  - **로컬 로그 분석** (`log_analyzer.js`): ERROR/CRITICAL 로그 감지 (Codanna/Serena MCP 연계)
  - **시각적 검증** (`visual_verifier.js`): 웹 프로젝트의 경우 UI 검증 (Chrome DevTools MCP)
  - **Git 규칙 검증** (`git-guard.js`): Git Guide 규칙 준수 확인
* **GUI를 통한 검증**: GUI의 Agent Skills Hub에서 각 스킬을 개별적으로 실행하고 실시간 결과를 확인할 수 있습니다.
* **사용 방법**:
  ```bash
  # boilerplate 프로젝트에서 실행하고, 대상 프로젝트 경로를 인자로 전달
  cd /path/to/boilerplate
  node scripts/verify-feedback-loop.js /path/to/target/project

  # 인자를 전달하지 않으면 현재 작업 디렉토리를 사용
  node scripts/verify-feedback-loop.js
  ```
* **개별 Agent 실행**:
  ```bash
  # 모든 Agent는 boilerplate 프로젝트 디렉토리에서 실행
  cd /path/to/boilerplate

  # 대상 프로젝트 경로를 인자로 전달
  node scripts/agents/security-audit.js /path/to/target/project
  node scripts/agents/simplifier.js /path/to/target/project
  node scripts/agents/log_analyzer.js /path/to/target/project /path/to/app.log
  node scripts/agents/visual_verifier.js /path/to/target/project 3000
  node scripts/agents/git-guard.js /path/to/target/project
  ```
* **스택 감지 실패 처리**: 스택이 감지되지 않은 경우, Agent는 경고만 표시하고 계속 진행합니다. 이는 정상적인 동작이며, 스택이 없는 프로젝트에서도 일부 검증을 수행할 수 있습니다.
* **핵심**: 모든 검증 결과를 종합하여 사용자 승인을 요청하며, 심각한 에러가 발견되면 승인을 차단합니다.

**이유**: 검증 피드백 루프가 있으면 최종 결과물 품질이 2~3배 향상됩니다. AI가 스스로 문제를 발견하고 수정하는 것이 인간이 하나씩 체크하는 것보다 효율적입니다. Agent Skills 표준 기반 통합 관리를 통해 모든 검증 단계를 일관되게 실행할 수 있습니다.

## 3. 팀의 뇌: CLAUDE.md 관리법

`CLAUDE.md`는 우리 팀의 **공유 메모리**입니다. AI가 똑똑해지느냐 멍청해지느냐는 이 파일의 관리에 달렸습니다.

* **언제 업데이트하나요?**: AI가 특정 실수를 반복하거나, 새로운 팀 컨벤션이 결정되었을 때.
* **PR 기반 업데이트**: PR 리뷰 중 AI에게 가르칠 내용이 있다면 코멘트에 `@.claude` 태그를 남기세요. GitHub Action이 이를 요약하여 `CLAUDE.md`에 자동 반영합니다.
* **GUI를 통한 편집**: GUI의 Config Editor에서 CLAUDE.md의 Lessons Learned와 Team Standards 섹션을 직접 편집할 수 있습니다.
* **금기 사항**: `CLAUDE.md`를 한 번에 너무 크게 수정하지 마세요. AI가 컨텍스트 과부하를 느낄 수 있습니다.

**이유**: CLAUDE.md는 팀의 지식이 복리로 쌓이는 공간입니다. 시간이 지날수록 AI가 더 똑똑해지고, 팀의 실수를 반복하지 않게 됩니다.

## 4. AI 협업 에티켓 (Etiquette)

토큰을 아끼고 AI의 응답 정확도를 높이는 대화 매너입니다.

* **파일 참조 우선**: 코드를 복사해서 붙여넣지 마세요. `@filename`을 사용하거나 파일을 열어둔 채로 질문하세요.
* **스레드 집중(Focused Thread)**: 한 채팅에서 여러 주제를 다루지 마세요. 새로운 기능 작업 시에는 반드시 세션을 초기화(`Ctrl+L` 또는 새 창)합니다.
* **인색한 칭찬, 명확한 지시**: AI에게 모호하게 "좋아"라고 하지 마세요. "계획의 2번 항목은 좋으나 3번은 보안상 위험하니 수정해"와 같이 구체적으로 지시하세요.

**이유**: 토큰은 비용입니다. 효율적인 대화 방식은 비용을 절감하고 응답 품질을 향상시킵니다.

## 5. 세션 관리 및 알림 설정 가이드

Boris Cherny처럼 여러 세션을 운영할 때 컨텍스트 혼선을 방지하는 방법:

### 세션 목적 명확화

* **세션 분리 전략**: 각 세션은 명확한 목적을 가져야 합니다.
  - 세션 1: 백엔드 API 개발
  - 세션 2: 프론트엔드 UI 개발
  - 세션 3: 인프라 설정
  - 세션 4: 코드 리뷰 및 문서화

**이유**: 세션을 목적별로 분리하면 컨텍스트가 섞이지 않고, 각 세션에서 AI가 더 집중할 수 있습니다.

### 시스템 알림 설정

* **터미널 알림**: 터미널에서 여러 Claude를 병렬 실행할 때, 각 탭에 번호를 붙이고 시스템 알림으로 입력이 필요한 시점을 파악합니다.
* **웹 세션 관리**: 웹에서도 여러 세션을 운영할 수 있지만, 각 세션의 목적을 명확히 하세요.

**이유**: 여러 세션을 운영할 때, 어떤 세션에서 입력이 필요한지 놓치지 않도록 알림이 중요합니다.

### 세션 간 컨텍스트 공유

* **@.claude 태그 활용**: 한 세션에서 학습한 내용을 다른 세션에 전달하려면 `@.claude` 태그를 사용하여 CLAUDE.md에 기록하세요.
* **세션 초기화 시점**: 새로운 기능 작업을 시작할 때는 반드시 세션을 초기화하여 이전 컨텍스트와의 혼선을 방지하세요.

**이유**: 세션 간 컨텍스트를 공유하면서도 각 세션의 집중도를 유지하는 것이 중요합니다.

### 모노레포 및 다중 언어 환경

* **컨텍스트 분리**: 모노레포나 다중 언어 환경에서는 각 서브프로젝트별로 세션을 분리하세요.
* **스택 감지 활용**: `detect_stack.sh`를 실행하여 현재 작업 중인 스택을 명확히 하고, 해당 스택에 맞는 도구만 사용하세요.

**이유**: 모노레포에서는 여러 언어와 프레임워크가 섞여 있어, 컨텍스트가 섞이면 AI가 혼란스러워할 수 있습니다.

## 6. 보안 및 가드레일

* **Secrets 관리**: `.env` 파일이나 API Key가 프롬프트에 포함되지 않도록 주의하세요.
* **MCP 도구 활용**: 외부 도구 연계가 필요할 땐 명시적으로 도구 사용을 요청하세요.
* **사용자 허가**: `git push`나 인프라 변경(`terraform apply`)은 반드시 AI가 생성한 요약을 읽고 **사용자가 직접 최종 승인**해야 합니다.

**이유**: 보안은 절대 타협할 수 없습니다. AI가 자동으로 위험한 작업을 수행하지 않도록 가드레일이 필요합니다.

## 7. 팀 Git Flow 및 Python 표준

### Git Flow 워크플로우

우리 팀은 엄격한 Git 컨벤션을 따릅니다:

1. **이슈 선행 생성**: 모든 변경사항은 반드시 GitHub Issue를 먼저 생성
2. **브랜치 생성**: GitHub Issue 화면에서 "Development > Create a branch" 기능 사용
   - Prefix 필수: `feature/` (신규 기능) 또는 `hotfix/` (버그 수정)
   - 형식: `feature/{issue_number}-{description}` 또는 `hotfix/{issue_number}-{description}`
3. **커밋 메시지**: `Resolved #{Issue No} - {Description}` 형식 강제
   - 주의: "Resovled"가 아닌 "Resolved"로 정확히 작성
4. **PR 병합**:
   - `feature/` 또는 `hotfix/` → `develop`: 반드시 **Squash and merge**
   - `develop` → `main`: **Merge pull request** (Create merge commit)
5. **Git 규칙 검증**: `git-guard` Agent Skill을 사용하여 브랜치명, 커밋 메시지, Issue 번호 포함 여부를 자동으로 검증할 수 있습니다.

### Python 프로젝트 표준

1. **uv 설정** (Poetry 대체):
   ```bash
   # Python 버전 설치
   uv python install 3.11

   # 의존성 동기화 (uv.lock 및 .venv 생성)
   uv sync

   # 명령 실행
   uv run pytest
   uv run python main.py
   ```
   - Poetry 프로젝트 마이그레이션: GUI의 Config Editor에서 "UV 마이그레이션" 탭 사용 또는 `scripts/core/migrate_to_uv.sh` 실행
   - `detect_stack.sh`가 자동으로 poetry.lock을 감지하고 마이그레이션 제안

2. **로깅 설정**:
   - 프로젝트 루트에 `logging.conf` 파일 사용
   - `colorlog` 패키지 설치: `uv add colorlog`
   - 로거 사용 예시:
   ```python
   import logging.config
   logging.config.fileConfig('logging.conf')
   logger = logging.getLogger('appLogger')
   logger.info("Application started")
   ```

3. **Pre-commit 훅**:
   - `.pre-commit-config.yaml` 파일 사용
   - 설치: `uv run pre-commit install`
   - 실행: `uv run pre-commit run --all-files`

4. **Ruff 사용**:
   - 포매팅: `uv run ruff format`
   - 린팅: `uv run ruff check --fix`

## 8. GUI 기능 활용

### Agent Skills Hub

GUI의 Agent Skills Hub에서 다음 6가지 Agent Skills를 실행할 수 있습니다:

1. **Simplifier**: 코드 복잡도 분석 및 리팩토링 제안
2. **Log Analyzer**: 로컬 로그 분석 및 에러 추적 (Codanna/Serena MCP 연계)
3. **Security Audit**: 보안 취약점 감사 (Python: safety, Node.js: npm/pnpm audit)
4. **Visual Verifier**: 웹 프로젝트 시각적 검증 (Chrome DevTools MCP)
5. **Git Guard**: Git Guide 규칙 준수 검증
6. **Claude Knowledge Updater**: 검증 결과를 CLAUDE.md에 자동 기록

각 스킬의 Instructions와 Engineering Philosophy를 확인할 수 있으며, 실시간으로 실행 결과를 모니터링할 수 있습니다.

### Log Monitor

GUI의 Log Monitor에서 실시간 로그를 확인하고, 에러 발생 시 "Analyze with AI" 버튼으로 즉시 분석할 수 있습니다.

### Knowledge Base

GUI의 Knowledge Base에서:
- **Knowledge Timeline**: CLAUDE.md의 Lessons Learned를 타임라인으로 시각화
- **Tool Reference**: AI-Native 툴체인 명세 및 설계 의도 설명

### Config Editor

GUI의 Config Editor에서:
- **CLAUDE.md 편집**: Lessons Learned, Team Standards 섹션 직접 편집
- **환경변수 관리**: 수동으로 환경변수 확인 및 업데이트
- **UV 마이그레이션**: Poetry 프로젝트를 uv로 자동 마이그레이션
- **도구 상태 확인**: mise, uv, MCP, pnpm, gh 설치 상태 확인

### Tutorial

GUI의 Tutorial 페이지에서:
- **인터랙티브 가이드**: 3-Step Loop (Plan, Execute, Verify) 시각화
- **도구별 가이드**: 각 단계에서 사용할 도구 설명
- **AI 초기화 가이드**: 프롬프트 복사 및 사용법 안내

## 💡 온보딩 체크리스트

* [ ] `mise` 설치 및 환경 구성 완료
* [ ] 보일러플레이트 주입 (GUI 또는 수동)
* [ ] AI 초기화 프롬프트 복사하여 Cursor/Claude Code에 붙여넣기
* [ ] `CLAUDE.md`의 `Anti-patterns` 섹션 1회 정독
* [ ] 팀 Git Flow 및 Python 표준 섹션 정독
* [ ] 첫 번째 작업 시 `/verify-app`으로 전체 테스트 통과 확인
* [ ] PR 생성 시 AI가 작성한 요약본 검토 후 제출
* [ ] 세션 관리 전략 수립 (단일 세션 vs 병렬 세션)
* [ ] Python 프로젝트인 경우: `logging.conf` 및 `.pre-commit-config.yaml` 확인
* [ ] GUI 기능 탐색 (Agent Skills Hub, Log Monitor, Knowledge Base 등)

---

> **"우리는 코드를 더 적게 쓰고, 더 가치 있는 문제를 해결하는 데 집중합니다."**
> 가이드에 의문이 생기면 언제든 팀 채널에 공유해 주세요.
