# 🚀 LLM Boilerplate Pack (Manual Mode)

**Antigravity 맞춤형 MCP & Git 워크플로우 보일러플레이트**

이 보일러플레이트는 **Option A (Manual Mode)**에 집중되어 있으며, **Google Antigravity** 환경에서 최상의 AI 코딩 경험을 제공하기 위해 설계되었습니다.

---

## ✨ 주요 기능

- 🛠️ **MCP Server Docker 구성**: Serena, Codanna, Shrimp, Context7 서버를 Docker로 즉시 구동.
- 🔗 **Antigravity 완벽 통합**: 프로젝트 스코프 MCP 설정 및 전용 Slash 커맨드 제공.
- 📦 **GSD 방법론 지원**: Spec, State, Roadmap, Decisions 기반의 체계적인 개발 프로세스.
- 🛡️ **안전한 환경**: 모든 도구 설정이 프로젝트 내부(`.agent/`, `.gsd/`)에서 관리되어 시스템 전역에 영향을 주지 않음.

---

## 🏗️ 프로젝트 구조

```
boilerplate/
├── .agent/              # Antigravity 설정 (MCP, 워크플로우)
├── .gsd/                # Get Shit Done 방법론 문서
├── mcp/                 # MCP 서버 Docker 설정 및 러너
├── MANUAL_SETUP.md      # 상세 설치 및 가이드
├── MCP_CONFIG.json.example # MCP 설정 템플릿
└── README.md            # 프로젝트 개요
```

---

## 🚀 빠른 시작

### 1. Antigravity에서 열기
이 폴더를 Antigravity 작업 공간으로 열면 `.agent/` 설정이 자동으로 인식됩니다.

### 2. 의존성 설치 및 환경 설정
Antigravity 채팅창에서 다음 명령어를 입력하세요:
```bash
/setup-boilerplate
```

### 3. MCP 서버 실행
Docker를 사용하여 MCP 서버들을 백그라운드에서 실행합니다:
```bash
/mcp-docker
```

---

## 🤖 Google Antigravity 통합

### MCP 서버 (프로젝트 스코프)
Antigravity는 다음 MCP 서버들을 자동으로 인식합니다:

| 서버 | 설명 | 언어 |
|------|------|------|
| **Serena** | Python 코드 분석 및 제안 | Python (uv) |
| **Codanna** | 고성능 코드 인텔리전스 | Rust |
| **Shrimp** | 작업 추적 및 관리 | Node.js |
| **Context7** | 시맨틱 코드 검색 | Node.js (API 키 필요) |

> **중요**: MCP 서버는 **프로젝트별로 구성**됩니다. 각 프로젝트의 `.agent/mcp_config.json` 설정을 통해 Antigravity가 프로젝트를 열 때 자동으로 도구를 로드합니다.

### 커스텀 워크플로우 (Slash 커맨드)
- `/setup-boilerplate` - 의존성 설치 및 환경 설정
- `/mcp-docker` - MCP 서버 관리 (Docker Compose)

---

## 📚 관련 문서

- [QUICKSTART.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/QUICKSTART.md) - 5분 시작 가이드
- [MANUAL_SETUP.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/MANUAL_SETUP.md) - 상세 매뉴얼
- [.agent/ANTIGRAVITY_QUICKSTART.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/.agent/ANTIGRAVITY_QUICKSTART.md) - Antigravity 사용법

---

## 🔧 요구사항

- Python 3.11+
- Docker & Docker Compose
- Node.js (MCP Runner용)
- Git

---

## 📝 라이선스

MIT License
