# AI-Native Boilerplate (LangChain Edition)

> Python LangChain 기반의 차세대 AI-Native 프로젝트 부트스트랩 도구

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.12-blue.svg)](https://python.org)
[![LangChain](https://img.shields.io/badge/langchain-1.0-green.svg)](https://langchain.com)

**팀원들의 코드 어시스턴트에게 작업 표준화와 MCP 툴을 구성해주는 All-in-One 솔루션**

## 🚀 주요 특징

- **🐍 Python & LangChain 1.0**: 최신 LangChain 에이전트 아키텍처 기반
- **🤖 Agentic MoE**: Architect, Artisan, Guardian, Librarian 등 전문가 에이전트 협업 시스템
- **🛠️ MCP Tools 통합**: Serena, Codanna, Shrimp 등 핵심 도구를 Docker 컨테이너로 실행하고 LangChain으로 제어
- **⚡ CLI 기반 주입**: 단 한 줄의 명령어로 프로젝트에 표준 설정 주입 (`langchain-tools inject`)
- **📡 Google Antigravity 지원**: 최신 AI-First IDE를 위한 MCP 설정 자동화
- **🧠 지식 복리화**: `CLAUDE.md`를 통한 프로젝트 간 지식 동기화 시스템
- **🏛️ AI-Native Governance**: GitHub 워크플로우, 이슈 템플릿, 기여 가이드를 통한 커뮤니티 관리 표준화
- **🤝 Community Manager Skill**: AI 에이전트가 이슈 트리아지, PR 리뷰, 기여자 온보딩을 자동 수행


## 📦 설치 및 시작

이 프로젝트는 [`uv`](https://github.com/astral-sh/uv) 패키지 매니저를 사용합니다.

```bash
# 1. 저장소 클론
git clone <repository-url>
cd boilerplate

# 2. 의존성 설치
uv sync

# 3. CLI 실행 (도움말)
uv run langchain-tools --help
```

## 💻 사용 가이드

### 1. 보일러플레이트 주입 (Inject)

새로운 프로젝트나 기존 프로젝트에 AI-Native 설정을 주입합니다.

```bash
# 프로젝트에 표준 설정 주입
uv run langchain-tools inject /path/to/target/project
```

**자동 생성되는 파일**:
- `CLAUDE.md`: AI 페르소나 및 팀 규칙
- `CONTRIBUTING.md`: 기여 가이드 (AI-Native 개발 철학 포함)
- `.github/workflows/`: GitHub Actions 자동화 (환영 메시지, 자동 라벨링)
- `.github/ISSUE_TEMPLATE/`: 구조화된 이슈 템플릿 (버그 리포트, 기능 요청)
- `.mcp.json` / `.cursor/mcp.json`: IDE별 Docker MCP 설정 (자동 주입)
- `.mcp/`: Docker MCP 런타임 파일 (`mcp-docker-runner.js`, `docker-compose.mcp.yml` 등)
- `mise.toml`: 프로젝트별 도구 관리자 설정
- `skills/`: AI 에이전트 스킬 디렉토리 (community-manager 등)


### 2. 도구 설정 가이드 (Show Config)

각 에디터별 MCP 설정 방법을 확인합니다.

```bash
uv run langchain-tools show-config /path/to/target/project
```

**지원 도구**:
- **Claude Code**: 자동 인식
- **Cursor IDE**: 자동 설정 (`.cursor/mcp.json`)
- **Google Antigravity**: 자동 인식 (`.mcp.json`)
- **Claude Desktop**: 수동 설정 가이드 제공
- **VS Code**: GitHub Copilot 자동 인식

### 3. 프로젝트 검증 (Verify)

LangChain 에이전트를 사용하여 프로젝트를 검증합니다.

```bash
uv run langchain-tools verify /path/to/target/project
```

### 4. 지식 동기화 (Sync Knowledge)

프로젝트 간에 축적된 지식(`Lessons Learned`)을 동기화합니다.

```bash
uv run langchain-tools sync-knowledge --from /project-a --to /project-b
```

### 5. Agentic MoE 실행 (Agent) (Beta)

전문가 에이전트 팀이 협업하여 복잡한 작업을 수행합니다.

```bash
# 대화형 모드 (Interactive)
uv run langchain-tools agent interactive --prompt "로그인 페이지 만들어줘"

# GUI 모드 (LangGraph Studio)
uv run langchain-tools agent studio

# 서버 모드 (API)
uv run langchain-tools agent server
```

**전문가 팀 구성**:
- **🏛️ Architect**: 사용자 의도 파악, 요구사항 분석 (`Codanna`), 구현 계획 수립 (`Shrimp`)
- **🔨 Artisan**: 계획에 따른 코드 구현 및 리팩토링 (`Serena`)
- **🛡️ Guardian**: 구현 결과 검증 (`AutoVerify`), 보안 감사 (`SecurityAudit`), 의도 일치 확인 (`IntentVerifier`)
- **📚 Librarian**: 성공 사례 지식화 및 동기화 (`CLAUDE.md`)
- **🤝 Community Manager**: 이슈 트리아지, PR 리뷰, 기여자 온보딩 자동화 (GitHub API 연계)


## 🏗️ 아키텍처

```mermaid
graph TD
    CLI[CLI] --> Inject[Injection Engine]
    CLI --> MoE[Agentic MoE (LangGraph)]
    CLI --> Sync[Knowledge Sync]

    Inject --> Templates[Jinja2 Templates]
    Inject --> DockerFiles[Docker Assets]

    MoE --> Supervisor(Supervisor Node)
    Supervisor --> Architect(Architect Node)
    Supervisor --> Artisan(Artisan Node)
    Supervisor --> Guardian(Guardian Node)
    Supervisor --> Librarian(Librarian Node)

    Architect & Artisan & Guardian --> MCP[MCP Client]
    MCP --> Docker[Docker Containers]
```

### 핵심 컴포넌트

- **`langchain_tools/`**: 메인 패키지
  - **`cli.py`**: CLI 진입점
  - **`inject/`**: 주입 엔진 및 템플릿
  - **`mcp/`**: Docker MCP 서버를 LangChain Tool로 래핑
  - **`agent/`**: 통합 검증 에이전트 및 미들웨어 설정
  - **`sync/`**: 지식 동기화 로직

- **`mcp/`**: MCP 서버 인프라
  - `docker-compose.mcp.yml`: MCP 서버 컨테이너 정의
  - `mcp-docker-runner.js`: JSON-RPC 브리지

## ⚠️ 레거시 코드

이전 버전의 JavaScript 기반 스크립트와 GUI 코드는 `.legacy/` 디렉토리에 보존되어 있습니다.
- `.legacy/scripts/`: 구형 JS 에이전트
- `.legacy/gui/`: Next.js 대시보드
