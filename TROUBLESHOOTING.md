# 🔧 Troubleshooting Guide

일반적인 문제와 해결 방법

---

## 🚨 일반적인 문제

### 1. 포트 충돌

**증상**:
```
ERROR: Address already in use
OSError: [Errno 48] Address already in use
```

**원인**: 8000 또는 8001 포트가 이미 사용 중

**해결**:
```bash
# Mac/Linux
lsof -ti:8000 | xargs kill
lsof -ti:8001 | xargs kill

# 또는 수동으로 프로세스 찾기
lsof -i:8000
lsof -i:8001
# PID 확인 후
kill -9 <PID>
```

---

### 2. Dashboard 로그가 안 보임

**증상**: "Start Demo" 클릭했지만 로그 출력 없음

**원인 1**: WebSocket 연결 실패
```javascript
// 브라우저 개발자 도구 콘솔 확인
WebSocket connection to 'ws://localhost:8001/ws/logs' failed
```

**해결**: 페이지 새로고침 (F5 또는 Ctrl+R)

**원인 2**: `PROJECT_ROOT` 환경 변수 미설정
```bash
# .env 파일 확인
cat .agent-booster/.env | grep PROJECT_ROOT
```

**해결**: `.env` 파일에 절대 경로 설정
```bash
PROJECT_ROOT="/absolute/path/to/project"
```

**원인 3**: `TaskContext` 타입 에러
```
ValidationError: work_dir
```

**해결**: 이미 수정됨 (최신 코드 사용 시 발생 안 함)

---

### 3. Mock Agent 실행 안 됨

**증상**: "Starting CLI Worker..." 이후 멈춤

**원인**: `.env`의 `CLI_COMMAND_PATH` 설정 오류

**해결**:
```bash
# .env 파일 확인
cat .agent-booster/.env

# mock_agent.sh 경로로 수정
CLI_COMMAND_PATH="/absolute/path/to/boilerplate/kits/option_c/mock_agent.sh"
```

권한 확인:
```bash
chmod +x /path/to/mock_agent.sh
```

---

### 4. Launcher GUI 안 열림

**증상**: `python -m launcher.app` 실행했지만 브라우저 안 열림

**해결**:
```bash
# 수동으로 브라우저 열기
open http://localhost:8000
# 또는
xdg-open http://localhost:8000  # Linux
```

**로그 확인**:
```bash
# 서버 실행 중인지 확인
ps aux | grep launcher
```

---

### 5. 주입 실패

**증상**: "Injection failed" 또는 파일 생성 안 됨

**원인 1**: 권한 문제
```bash
# 대상 디렉토리 쓰기 권한 확인
ls -la /path/to/target/directory
```

**원인 2**: `.agent-booster` 이미 존재
```bash
# 기존 디렉토리 확인
ls -la .agent-booster
```

**해결**: 기존 디렉토리 제거 후 재주입
```bash
rm -rf .agent-booster
# Launcher에서 재주입
```

---

### 6. Pydantic 경고

**증상**:
```
PydanticDeprecatedSince20: The `__fields__` attribute is deprecated
```

**원인**: Python 3.14 + Pydantic v2 호환성

**해결**: 경고이므로 무시 가능 (기능 정상 작동)

장기 해결: `langchain_core` 업그레이드 대기

---

### 7. SQLite 로그 DB 오류

**증상**:
```
sqlite3.OperationalError: database is locked
```

**원인**: 여러 프로세스가 동시에 DB 접근

**해결**:
```bash
# Dashboard 재시작
# 또는 DB 파일 삭제 후 재생성
rm .logs/events.db
```

---

## 🔍 디버깅 팁

### 로그 확인
```bash
# Dashboard 서버 로그 (터미널에서 확인)
cd .agent-booster
python -m uvicorn runtime.app:app --port 8001

# SQLite DB 직접 확인
sqlite3 .logs/events.db "SELECT * FROM logs ORDER BY timestamp DESC LIMIT 10;"
```

### 환경 변수 확인
```python
# Python REPL에서
import os
from dotenv import load_dotenv
load_dotenv('.agent-booster/.env')
print(os.getenv('PROJECT_ROOT'))
print(os.getenv('CLI_COMMAND_PATH'))
```

### 네트워크 확인
```bash
# 포트 리스닝 확인
netstat -an | grep 8001

# localhost 연결 테스트
curl http://localhost:8001/api/state
```

---

## 🐞 버그 리포트

문제가 해결되지 않으면 다음 정보와 함께 Issue 등록:

1. **환경 정보**:
   ```bash
   python --version
   uname -a  # OS 정보
   ```

2. **에러 로그**: 전체 traceback

3. **재현 단계**: 문제 재현 방법

4. **설정 파일**: `.env` 내용 (민감 정보 제거)

---

## ✅ 자주 묻는 질문 (FAQ)

### Q: Claude CLI 없이 테스트 가능한가요?
A: 네! `mock_agent.sh`로 테스트하세요.

### Q: 실제 프로젝트에 주입해도 안전한가요?
A: 네. `.agent-booster/` 서브디렉토리에만 파일 생성하고 `.gitignore`에 자동 추가됩니다.

### Q: 주입 후 제거하려면?
A: `.agent-booster` 디렉토리만 삭제하면 됩니다.
```bash
rm -rf .agent-booster
```

### Q: Dashboard 비밀번호 설정 가능한가요?
A: 현재는 로컬호스트만 지원. 외부 접근 시 reverse proxy + 인증 추가 필요.

### Q: MCP 서버가 필수인가요?
A: Option A, B에서는 선택사항. Option C는 MCP 없이 CLI만으로도 동작.

---

## 📞 추가 도움

- [README.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/README.md) - 프로젝트 개요
- [QUICKSTART.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/QUICKSTART.md) - 시작 가이드
- GitHub Issues - 버그 리포트 및 기능 요청
