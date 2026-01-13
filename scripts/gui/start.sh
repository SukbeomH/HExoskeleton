#!/bin/sh
# GUI 서버 실행 스크립트
#
# 백엔드 및 프론트엔드를 동시에 기동합니다.
# 백엔드: FastAPI (포트 8000)
# 프론트엔드: Next.js (포트 3000)

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# GUI 디렉토리 위치 확인 (주입된 프로젝트는 scripts/gui/, 원본은 gui/)
if [ -d "$PROJECT_ROOT/gui/backend" ]; then
	# 원본 보일러플레이트 구조
	BACKEND_DIR="$PROJECT_ROOT/gui/backend"
	FRONTEND_DIR="$PROJECT_ROOT/gui/frontend"
elif [ -d "$SCRIPT_DIR/backend" ]; then
	# 주입된 프로젝트 구조 (scripts/gui/)
	BACKEND_DIR="$SCRIPT_DIR/backend"
	FRONTEND_DIR="$SCRIPT_DIR/frontend"
else
	# 둘 다 없는 경우
	BACKEND_DIR="$PROJECT_ROOT/gui/backend"
	FRONTEND_DIR="$PROJECT_ROOT/gui/frontend"
fi

# 색상 출력을 위한 함수
if [ -t 1 ]; then
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[1;33m'
	BLUE='\033[0;34m'
	NC='\033[0m'
else
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	NC=''
fi

echo "${BLUE}🚀 Starting Boilerplate Injector GUI...${NC}"

# 백엔드 디렉토리 확인
if [ ! -d "$BACKEND_DIR" ]; then
	echo "${RED}❌ Backend directory not found: $BACKEND_DIR${NC}"
	exit 1
fi

# 프론트엔드 디렉토리 확인
if [ ! -d "$FRONTEND_DIR" ]; then
	echo "${RED}❌ Frontend directory not found: $FRONTEND_DIR${NC}"
	exit 1
fi

# 백엔드 시작
echo "${BLUE}📦 Starting backend (FastAPI)...${NC}"
cd "$BACKEND_DIR"

# uv 또는 venv 사용 확인
if command -v uv >/dev/null 2>&1 && [ -f "uv.lock" ]; then
	# uv 프로젝트인 경우
	echo "${BLUE}📥 Syncing backend dependencies (uv)...${NC}"
	uv sync
elif [ -f "pyproject.toml" ] && [ -f "poetry.lock" ]; then
	# Poetry 프로젝트인 경우 (마이그레이션 대상)
	if command -v poetry >/dev/null 2>&1; then
		echo "${BLUE}📥 Installing backend dependencies (poetry)...${NC}"
		poetry install
		echo "${YELLOW}💡 Consider migrating to uv: scripts/core/migrate_to_uv.sh${NC}"
	else
		echo "${YELLOW}⚠️  Poetry not found. Creating venv...${NC}"
		if [ ! -d "venv" ] && command -v python3 >/dev/null 2>&1; then
			python3 -m venv venv
		fi
		if [ -f "venv/bin/activate" ]; then
			. venv/bin/activate
		fi
		if [ ! -f ".installed" ] || [ "requirements.txt" -nt ".installed" ]; then
			echo "${BLUE}📥 Installing backend dependencies...${NC}"
			pip install -q -r requirements.txt
			touch .installed
		fi
	fi
elif [ ! -d "venv" ] && command -v python3 >/dev/null 2>&1; then
	# 기본 venv 생성
	echo "${YELLOW}⚠️  Virtual environment not found. Creating...${NC}"
	python3 -m venv venv
	if [ -f "venv/bin/activate" ]; then
		. venv/bin/activate
	fi
	if [ ! -f ".installed" ] || [ "requirements.txt" -nt ".installed" ]; then
		echo "${BLUE}📥 Installing backend dependencies...${NC}"
		pip install -q -r requirements.txt
		touch .installed
	fi
fi

# 백엔드 실행 (백그라운드)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/injector-backend.log 2>&1 &
BACKEND_PID=$!
echo "${GREEN}✅ Backend started (PID: $BACKEND_PID)${NC}"
echo "${BLUE}   Logs: /tmp/injector-backend.log${NC}"
echo "${BLUE}   API: http://localhost:8000${NC}"

# 프론트엔드 시작
echo "${BLUE}🌐 Starting frontend (Next.js)...${NC}"
cd "$FRONTEND_DIR"

# 의존성 설치 확인
if [ ! -d "node_modules" ]; then
	echo "${BLUE}📥 Installing frontend dependencies...${NC}"
	npm install
fi

# 프론트엔드 실행 (백그라운드)
npm run dev > /tmp/injector-frontend.log 2>&1 &
FRONTEND_PID=$!
echo "${GREEN}✅ Frontend started (PID: $FRONTEND_PID)${NC}"
echo "${BLUE}   Logs: /tmp/injector-frontend.log${NC}"
echo "${BLUE}   UI: http://localhost:3000${NC}"

echo ""
echo "${GREEN}✅ Boilerplate Injector GUI is running!${NC}"
echo "${BLUE}   Project-Specific Control Plane Started at: $PROJECT_ROOT${NC}"
echo "${BLUE}   Frontend: http://localhost:3000${NC}"
echo "${BLUE}   Backend API: http://localhost:8000${NC}"
echo ""
echo "${YELLOW}Press Ctrl+C to stop both servers${NC}"

# 종료 처리
trap "echo ''; echo '${YELLOW}Stopping servers...${NC}'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT TERM

# 대기
wait

