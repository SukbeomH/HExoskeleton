#!/bin/sh
# detect_stack.sh - 실무 대응형 스택 감지 엔진
#
# 목적: 프로젝트 루트의 파일을 스캔하여 스택을 감지하고 환경 변수로 내보냅니다.
# 사내 표준(Poetry, pnpm)을 우선 반영하여 정확한 스택 감지를 수행합니다.
#
# 사용법:
#   source scripts/core/detect_stack.sh
#   또는
#   . scripts/core/detect_stack.sh
#
# 출력: 환경 변수로 감지된 스택 정보를 내보냅니다.
#   - DETECTED_STACK: python, node, go, rust 등
#   - DETECTED_PACKAGE_MANAGER: poetry, pnpm, npm, go, cargo 등
#   - DETECTED_VENV_PATH: Poetry의 경우 .venv 경로
#   - DETECTED_PYTHON_VERSION: pyproject.toml에서 추출한 Python 버전
#
# POSIX 표준을 준수하여 다양한 환경에서 동작하도록 작성되었습니다.

set -e

# 색상 출력을 위한 함수 (터미널이 지원하는 경우)
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

# 프로젝트 루트 디렉토리 찾기
# 1. PROJECT_ROOT 환경 변수가 있으면 사용
# 2. 없으면 현재 작업 디렉토리 사용 (백엔드 API에서 cwd=target으로 실행)
# 3. 그것도 아니면 스크립트 위치 기준으로 계산 (기존 로직)
if [ -n "$PROJECT_ROOT" ]; then
	# 환경 변수가 설정된 경우 사용
	PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd)
elif [ -n "$PWD" ] && [ "$PWD" != "/" ]; then
	# 현재 작업 디렉토리 사용 (백엔드 API에서 cwd=target으로 실행하는 경우)
	PROJECT_ROOT="$PWD"
else
	# 기존 로직: 스크립트 위치 기준
	SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
	PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
fi

# 초기값 설정
DETECTED_STACK=""
DETECTED_PACKAGE_MANAGER=""
DETECTED_VENV_PATH=""
DETECTED_PYTHON_VERSION=""

echo "${BLUE}🔍 [Stack Detection] Scanning project root: $PROJECT_ROOT${NC}"

# 1. Python/uv 스택 감지 (uv 우선, Poetry는 마이그레이션 대상)
if [ -f "$PROJECT_ROOT/pyproject.toml" ] && [ -f "$PROJECT_ROOT/uv.lock" ]; then
	DETECTED_STACK="python"
	DETECTED_PACKAGE_MANAGER="uv"
	
	# uv 가상 환경 경로 확인
	if [ -d "$PROJECT_ROOT/.venv" ]; then
		DETECTED_VENV_PATH=".venv"
	fi
	
	# pyproject.toml에서 Python 버전 추출
	if command -v grep >/dev/null 2>&1; then
		PYTHON_VERSION=$(grep -E "^python\s*=|^requires-python\s*=" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null | head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed "s/.*=\s*'\([^']*\)'.*/\1/" || echo "")
		if [ -n "$PYTHON_VERSION" ]; then
			# 버전 범위에서 최소 버전 추출 (예: ">=3.11,<4.0" -> "3.11")
			DETECTED_PYTHON_VERSION=$(echo "$PYTHON_VERSION" | sed 's/[^0-9.]*\([0-9]\+\.[0-9]\+\).*/\1/' | head -1)
		fi
	fi
	
	echo "${GREEN}✅ Detected: Python/uv stack${NC}"
	echo "   Package Manager: uv"
	
	if [ -n "$DETECTED_VENV_PATH" ]; then
		echo "   Virtual Environment: $DETECTED_VENV_PATH"
	else
		echo "${YELLOW}   ⚠️  Virtual environment not found. Run 'uv sync' to create.${NC}"
	fi
	
	# 사내망 인증서 설치 여부 확인 (certifi 패키지 확인)
	if [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
		if grep -q "certifi" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null || grep -q "certifi" "$PROJECT_ROOT/uv.lock" 2>/dev/null; then
			echo "   Certificate: certifi package detected"
		else
			echo "${YELLOW}   ⚠️  certifi package not found. Consider installing for self-signed certificates.${NC}"
		fi
	fi
	
	echo "${BLUE}   💡 Tip: Use 'uv run <command>' to run commands in the virtual environment.${NC}"
	
elif [ -f "$PROJECT_ROOT/pyproject.toml" ] && [ -f "$PROJECT_ROOT/poetry.lock" ]; then
	# Poetry 프로젝트 감지 (마이그레이션 대상)
	DETECTED_STACK="python"
	DETECTED_PACKAGE_MANAGER="poetry"
	
	# Poetry 가상 환경 경로 확인
	if [ -d "$PROJECT_ROOT/.venv" ]; then
		DETECTED_VENV_PATH=".venv"
	elif [ -d "$PROJECT_ROOT/venv" ]; then
		DETECTED_VENV_PATH="venv"
	else
		# Poetry가 관리하는 가상 환경 경로 확인
		if command -v poetry >/dev/null 2>&1; then
			POETRY_VENV=$(poetry env info --path 2>/dev/null || echo "")
			if [ -n "$POETRY_VENV" ]; then
				DETECTED_VENV_PATH="$POETRY_VENV"
			fi
		fi
	fi
	
	# pyproject.toml에서 Python 버전 추출
	if command -v grep >/dev/null 2>&1; then
		PYTHON_VERSION=$(grep -E "^python\s*=|^requires-python\s*=" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null | head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed "s/.*=\s*'\([^']*\)'.*/\1/" || echo "")
		if [ -n "$PYTHON_VERSION" ]; then
			# 버전 범위에서 최소 버전 추출 (예: ">=3.11,<4.0" -> "3.11")
			DETECTED_PYTHON_VERSION=$(echo "$PYTHON_VERSION" | sed 's/[^0-9.]*\([0-9]\+\.[0-9]\+\).*/\1/' | head -1)
		fi
	fi
	
	echo "${GREEN}✅ Detected: Python/Poetry stack${NC}"
	echo "   Package Manager: Poetry"
	
	# uv 마이그레이션 확인 (poetry.lock이 있으면 uv로 마이그레이션 제안)
	if [ -f "$PROJECT_ROOT/poetry.lock" ]; then
		if command -v uv >/dev/null 2>&1; then
			if [ ! -f "$PROJECT_ROOT/uv.lock" ]; then
				echo "${YELLOW}   ⚠️  poetry.lock detected. Consider migrating to uv:${NC}"
				echo "${YELLOW}      Run: scripts/core/migrate_to_uv.sh${NC}"
			fi
		fi
	fi
	
	if [ -n "$DETECTED_VENV_PATH" ]; then
		echo "   Virtual Environment: $DETECTED_VENV_PATH"
	else
		echo "${YELLOW}   ⚠️  Virtual environment not found. Run 'poetry shell' to activate.${NC}"
	fi
	
	# 사내망 인증서 설치 여부 확인 (certifi 패키지 확인)
	if [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
		if grep -q "certifi" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null || grep -q "certifi" "$PROJECT_ROOT/poetry.lock" 2>/dev/null; then
			echo "   Certificate: certifi package detected"
		else
			echo "${YELLOW}   ⚠️  certifi package not found. Consider installing for self-signed certificates.${NC}"
		fi
	fi
	
	# Poetry shell 활성화 필요성 안내
	if [ -z "$VIRTUAL_ENV" ]; then
		echo "${YELLOW}   💡 Tip: Run 'poetry shell' to activate the virtual environment.${NC}"
	fi
elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
	# pyproject.toml만 있고 lock 파일이 없는 경우 (Python 프로젝트로 감지, 패키지 매니저는 미확정)
	DETECTED_STACK="python"
	DETECTED_PACKAGE_MANAGER="unknown"
	
	# pyproject.toml에서 Python 버전 추출
	if command -v grep >/dev/null 2>&1; then
		PYTHON_VERSION=$(grep -E "^python\s*=|^requires-python\s*=" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null | head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed "s/.*=\s*'\([^']*\)'.*/\1/" || echo "")
		if [ -n "$PYTHON_VERSION" ]; then
			DETECTED_PYTHON_VERSION=$(echo "$PYTHON_VERSION" | sed 's/[^0-9.]*\([0-9]\+\.[0-9]\+\).*/\1/' | head -1)
		fi
	fi
	
	# 가상 환경 경로 확인
	if [ -d "$PROJECT_ROOT/.venv" ]; then
		DETECTED_VENV_PATH=".venv"
	elif [ -d "$PROJECT_ROOT/venv" ]; then
		DETECTED_VENV_PATH="venv"
	fi
	
	echo "${GREEN}✅ Detected: Python project (pyproject.toml found)${NC}"
	echo "${YELLOW}   ⚠️  No lock file found (poetry.lock or uv.lock)${NC}"
	echo "${YELLOW}   💡 Tip: Consider using uv or Poetry for dependency management${NC}"
	
	if [ -n "$DETECTED_VENV_PATH" ]; then
		echo "   Virtual Environment: $DETECTED_VENV_PATH"
	fi
fi

# 2. Node.js/pnpm 스택 감지 (사내 표준 우선)
if [ -z "$DETECTED_STACK" ]; then
	if [ -f "$PROJECT_ROOT/pnpm-lock.yaml" ]; then
		DETECTED_STACK="node"
		DETECTED_PACKAGE_MANAGER="pnpm"
		echo "${GREEN}✅ Detected: Node.js/pnpm stack${NC}"
		echo "   Package Manager: pnpm"
	elif [ -f "$PROJECT_ROOT/package-lock.json" ]; then
		DETECTED_STACK="node"
		DETECTED_PACKAGE_MANAGER="npm"
		echo "${GREEN}✅ Detected: Node.js/npm stack${NC}"
		echo "   Package Manager: npm"
	elif [ -f "$PROJECT_ROOT/yarn.lock" ]; then
		DETECTED_STACK="node"
		DETECTED_PACKAGE_MANAGER="yarn"
		echo "${GREEN}✅ Detected: Node.js/yarn stack${NC}"
		echo "   Package Manager: yarn"
	elif [ -f "$PROJECT_ROOT/package.json" ]; then
		# package.json만 있고 lock 파일이 없는 경우 (npm 기본)
		DETECTED_STACK="node"
		DETECTED_PACKAGE_MANAGER="npm"
		echo "${GREEN}✅ Detected: Node.js/npm stack (no lock file)${NC}"
		echo "   Package Manager: npm"
		echo "${YELLOW}   ⚠️  No lock file found. Consider running 'npm install' to create package-lock.json${NC}"
	fi
fi

# 3. Go 스택 감지
if [ -z "$DETECTED_STACK" ] && [ -f "$PROJECT_ROOT/go.mod" ]; then
	DETECTED_STACK="go"
	DETECTED_PACKAGE_MANAGER="go"
	echo "${GREEN}✅ Detected: Go stack${NC}"
	echo "   Package Manager: go modules"
fi

# 4. Rust 스택 감지
if [ -z "$DETECTED_STACK" ] && [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
	DETECTED_STACK="rust"
	DETECTED_PACKAGE_MANAGER="cargo"
	echo "${GREEN}✅ Detected: Rust stack${NC}"
	echo "   Package Manager: cargo"
fi

# 5. 스택을 감지하지 못한 경우
if [ -z "$DETECTED_STACK" ]; then
	echo "${YELLOW}⚠️  No supported stack detected.${NC}"
	echo "   Supported stacks: Python/uv (Poetry → uv 마이그레이션 지원), Node.js (pnpm/npm/yarn), Go, Rust"
	echo "   Please ensure project root contains:"
	echo "     - Python: pyproject.toml + uv.lock (우선) 또는 pyproject.toml + poetry.lock (마이그레이션 대상)"
	echo "     - Node.js: package.json + pnpm-lock.yaml or package-lock.json"
	echo "     - Go: go.mod"
	echo "     - Rust: Cargo.toml"
	exit 1
fi

# 환경 변수로 내보내기 (export)
export DETECTED_STACK
export DETECTED_PACKAGE_MANAGER
if [ -n "$DETECTED_VENV_PATH" ]; then
	export DETECTED_VENV_PATH
fi
if [ -n "$DETECTED_PYTHON_VERSION" ]; then
	export DETECTED_PYTHON_VERSION
fi

echo "${BLUE}📋 [Stack Detection] Summary:${NC}"
echo "   DETECTED_STACK=$DETECTED_STACK"
echo "   DETECTED_PACKAGE_MANAGER=$DETECTED_PACKAGE_MANAGER"
if [ -n "$DETECTED_VENV_PATH" ]; then
	echo "   DETECTED_VENV_PATH=$DETECTED_VENV_PATH"
fi
if [ -n "$DETECTED_PYTHON_VERSION" ]; then
	echo "   DETECTED_PYTHON_VERSION=$DETECTED_PYTHON_VERSION"
fi

echo "${GREEN}✅ Stack detection completed successfully${NC}"

