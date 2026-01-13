"""
FastAPI 애플리케이션 진입점

AI-Native Boilerplate Injector 백엔드 API 서버
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import sys

# 프로젝트 루트를 Python 경로에 추가
backend_root = Path(__file__).parent
sys.path.insert(0, str(backend_root))

from app.api import injector, config, logs, agents, skills

app = FastAPI(
	title="AI-Native Boilerplate Injector API",
	description="기존 및 신규 프로젝트에 AI-Native 보일러플레이트를 주입하는 API",
	version="1.0.0",
)

# CORS 설정 (프론트엔드에서 접근 가능하도록)
app.add_middleware(
	CORSMiddleware,
	allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],  # Next.js 기본 포트
	allow_credentials=True,
	allow_methods=["*"],
	allow_headers=["*"],
)

# API 라우터 등록
app.include_router(injector.router)
app.include_router(config.router)
app.include_router(logs.router)
app.include_router(agents.router)
app.include_router(skills.router)


@app.get("/")
async def root():
	"""루트 엔드포인트"""
	return {
		"name": "AI-Native Boilerplate Injector API",
		"version": "1.0.0",
		"endpoints": {
			"detect": "POST /api/v1/detect",
			"inject": "POST /api/v1/inject",
			"config": {
				"claude_sections": "GET /api/v1/config/claude/sections",
				"update_claude": "POST /api/v1/config/claude/sections",
				"check_env": "GET /api/v1/config/env/check",
				"update_env": "POST /api/v1/config/env/update",
				"migrate_uv": "POST /api/v1/config/migrate/uv",
				"check_tools": "GET /api/v1/config/tools/check",
			},
		},
	}


@app.get("/health")
async def health():
	"""헬스 체크 엔드포인트"""
	return {"status": "healthy"}

