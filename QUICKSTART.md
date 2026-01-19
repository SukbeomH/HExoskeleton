# ⚡ Quick Start Guide

5분 안에 LLM Boilerplate Pack 시작하기

---

## 📋 준비사항

```bash
# Python 3.11+ 확인
python --version

# Docker 확인 (MCP 서버용)
docker --version
```

---

## 🚀 설치 및 실행

### 1단계: 가상환경 생성 및 의존성 설치

```bash
cd /path/to/boilerplate
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

pip install -r requirements.txt
```

### 2단계: Launcher 실행

```bash
python -m launcher.app
```

브라우저가 자동으로 `http://localhost:8000`을 엽니다.

### 3단계: 프로젝트 스캔

1. **프로젝트 경로 입력**
   - 예: `.legacy` (상대 경로)
   - 예: `/absolute/path/to/project` (절대 경로)

2. **Scan Project 클릭**
   - 자동으로 프로젝트 분석
   - 적합한 모드 추천

### 4단계: 모드 선택 및 주입

#### 옵션 A: Manual Mode
- 설정 파일만 필요한 경우
- MCP 서버 Docker Compose 포함
- 사용자가 직접 도구 제어

#### 옵션 B: Full Auto
- 완전 자동화 원하는 경우
- LangGraph 에이전트 사용
- API 키 필요 (`.env` 설정)

#### 옵션 C: Hybrid ⭐ 추천
- Dashboard로 모니터링하면서 제어
- Pause/Resume 가능
- **실시간 로그 확인**

**Inject Selected Kit 클릭**

### 5단계: 사용

#### Option C 선택한 경우:

```bash
# 주입된 디렉토리로 이동
cd your-project/.agent-booster

# Dashboard 실행
python -m uvicorn runtime.app:app --host 0.0.0.0 --port 8001
```

브라우저에서 `http://localhost:8001` 접속

**Dashboard 사용법**:
1. **▶️ Start Demo** - Mock Agent 실행
2. **⏸️ Pause** - 실행 일시정지
3. **▶️ Resume** - 재개
4. **🗑️ Clear** - 로그 지우기

---

## 🎯 첫 테스트

### Mock Agent로 테스트

Option C Dashboard에서:
1. "Start Demo" 클릭
2. 로그에서 다음 확인:
   - `[Mock Agent] 🤔 Analyzing request...`
   - `[Mock Agent] ✅ Task completed successfully!`
3. Pause/Resume 버튼 테스트

### 실제 CLI 연동 (선택)

`.agent-booster/.env` 파일 수정:
```bash
CLI_COMMAND_PATH="claude"  # 또는 실제 CLI 경로
```

---

## 📁 주입된 구조

주입 후 프로젝트 구조:
```
your-project/
├── .agent-booster/        # 🆕 주입된 디렉토리
│   ├── .env              # 환경 변수
│   ├── runtime/          # Dashboard (Option C)
│   ├── langchain_tools/  # 핵심 라이브러리
│   └── .logs/           # SQLite 로그
├── .gitignore           # 🆕 .agent-booster 추가됨
└── (기존 프로젝트 파일들)
```

---

## ⚠️ 문제 발생 시

### 포트 충돌
```bash
# 기존 프로세스 종료
lsof -ti:8000 | xargs kill
lsof -ti:8001 | xargs kill
```

### Dashboard 로그 안 보임
1. 브라우저 새로고침 (F5)
2. WebSocket 연결 확인 (개발자 도구)
3. `.env` 파일의 `PROJECT_ROOT` 확인

더 자세한 내용: [TROUBLESHOOTING.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/TROUBLESHOOTING.md)

---

## 🎓 다음 단계

- [ ] 실제 프로젝트에 주입해보기
- [ ] Dashboard에서 실시간 로그 확인
- [ ] 실제 Claude CLI와 연동
- [ ] Git 워크플로우 확인

궁금한 점이 있다면 [README.md](file:///Users/sukbeom/Desktop/workspace/boilerplate/README.md) 참조!
