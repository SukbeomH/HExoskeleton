# ⚡ Quick Start Guide (Manual Mode)

5분 안에 MCP 기반 수동 모드 설정하기

---

## 📋 준비사항

```bash
# Python 3.11+ 확인
python --version

# Docker 확인 (MCP 서버용)
docker --version

# Node.js 확인
node --version
```

---

## 🚀 단계별 설정

### 1단계: 환경 변수 설정
복잡한 설정 없이 템플릿을 복사하여 사용합니다.

```bash
cp .env.example .env
```

`.env` 파일을 열어 다음을 확인하세요:
- `PROJECT_NAME`: 현재 프로젝트 이름

### 2단계: MCP 서버 Docker 실행
Docker Compose를 사용하여 4개의 핵심 MCP 서버(Serena, Codanna, Shrimp, Context7)를 실행합니다.

```bash
# Antigravity `/mcp-docker` 또는 다음 명령 실행
/mcp-docker
```

또는 직접 실행:
```bash
docker-compose -f mcp/docker-compose.mcp.yml up -d
```

### 3단계: 도구(Editor/IDE) 연결
AI 도구가 MCP 서버를 Stdion 방식으로 호출할 수 있도록 설정합니다.

`MCP_CONFIG.json.example`의 내용을 복사하여 환경에 맞게 추가하세요:
- **Cursor**: `Settings > Models > MCP`에서 서버 추가
- **Claude Code**: `.mcp.json` 파일 생성

### 4단계: Antigravity Slash 커맨드 활용
Antigravity를 사용 중이라면 채팅창에서 바로 명령을 내릴 수 있습니다.

- `/setup-boilerplate`: 자동 프로젝트 초기화
- `/mcp-docker`: Docker 컨네이너 상태 관리

---

## 📁 주요 디렉토리

- `mcp/`: Dockerfile 및 Docker Compose 설정
- `.agent/`: Antigravity 용 워크플로우 및 환경 설정
- `.gsd/`: 프로젝트 관리용 마크다운 명세서

---

## ⚠️ 문제 발생 시

### Docker 실행 오류
```bash
# 기존 컨테이너 청소
docker-compose -f mcp/docker-compose.mcp.yml down
docker-compose -f mcp/docker-compose.mcp.yml up -d --build
```

더 자세한 내용: [MANUAL_SETUP.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/MANUAL_SETUP.md)
