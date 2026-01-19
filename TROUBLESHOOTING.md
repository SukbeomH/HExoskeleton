# 🔧 Troubleshooting Guide

일반적인 문제와 해결 방법

---

## 🚨 일반적인 문제

### 1. MCP 서버 실행 실패

**증상**:
```bash
Error response from daemon: container mcp-serena is not running
```

**원인**: Docker 컨테이너가 정상적으로 시작되지 않았거나 종료됨

**해결**:
```bash
# 컨테이너 상태 확인
docker-compose -f mcp/docker-compose.mcp.yml ps

# 로그 확인
docker-compose -f mcp/docker-compose.mcp.yml logs serena

# 재시작
docker-compose -f mcp/docker-compose.mcp.yml restart
```

---

### 2. Antigravity에서 MCP 도구 인식 불가

**증상**: Antigravity 채팅창에서 MCP 도구(serena_search 등)가 나타나지 않음

**원인 1**: `.agent/mcp_config.json` 설정 누락 또는 오류

**해결**:
1. `.agent/mcp_config.json` 파일이 존재하는지 확인
2. 설정값이 `MCP_CONFIG.json.example`과 일치하는지 확인
3. Antigravity 프로젝트 재로드 (폴더 닫았다 다시 열기)

**원인 2**: Docker 컨테이너 미구동

**해결**: `docker ps` 명령어로 `mcp-serena`, `mcp-codanna` 등이 실행 중인지 확인

---

### 3. Context7 API 키 관련 오류

**증상**: Context7 검색 시 API 키 오류 발생

**원인**: `.env` 파일에 `CONTEXT7_API_KEY`가 설정되지 않음

**해결**:
1. `.env` 파일 생성 및 키 추가:
   ```bash
   CONTEXT7_API_KEY=your_actual_key_here
   ```
2. Docker 컨테이너 재시작:
   ```bash
   docker-compose -f mcp/docker-compose.mcp.yml up -d context7
   ```

---

### 4. 권한 문제

**증상**:
```bash
permission denied while trying to connect to the Docker daemon socket
```

**원인**: 현재 사용자가 Docker 그룹에 속해 있지 않음

**해결**: `sudo`를 사용하거나 사용자를 docker 그룹에 추가

---

## 🔍 디버깅 팁

### Docker 상태 확인
```bash
# 전체 MCP 컨테이너 확인
docker ps -a | grep mcp

# 리소스 사용량 확인
docker stats mcp-codanna
```

### 볼륨 확인
```bash
# 데이터 영속화 확인
docker volume ls | grep mcp
```

---

## 🐞 버그 리포트

문제가 해결되지 않으면 다음 정보와 함께 Issue 등록:

1. **환경 정보**:
   - OS 버전
   - Docker / Docker Compose 버전
   - Antigravity 버전

2. **에러 로그**: 터미널 출력 전문

3. **재현 단계**: 어떤 조작 시 문제가 발생했는지

---

## ✅ 자주 묻는 질문 (FAQ)

### Q: Antigravity 없이도 사용 가능한가요?
A: 네. `docker-compose`로 서버 구동 후 Cursor나 Claude Code 등 다른 도구에 수동으로 연결할 수 있습니다.

### Q: 특정 MCP 서버만 끄고 싶어요.
A: `docker-compose -f mcp/docker-compose.mcp.yml stop <service_name>` 명령을 사용하세요.

### Q: 파일 수정 내용이 MCP 서버에 반영되지 않아요.
A: MCP 서버는 실시간으로 파일을 읽지만, 인덱싱 기반 서버(Codanna 등)는 업데이트에 시간이 약간 소요될 수 있습니다.

---

## 📞 추가 도움

- [README.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/README.md) - 프로젝트 개요
- [QUICKSTART.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/QUICKSTART.md) - 시작 가이드
- [MANUAL_SETUP.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/MANUAL_SETUP.md) - 상세 매뉴얼
