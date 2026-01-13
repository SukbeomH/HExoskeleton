"""
설정 및 지식 편집기 API

CLAUDE.md, 환경 변수, uv 마이그레이션 등을 관리하는 API 엔드포인트를 제공합니다.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from pathlib import Path
import sys
import re
import subprocess
import json
from typing import Optional, Dict, List, Any
from pydantic import BaseModel

# 프로젝트 루트를 Python 경로에 추가
backend_root = Path(__file__).parent.parent.parent
boilerplate_root = backend_root.parent.parent
sys.path.insert(0, str(backend_root))

router = APIRouter(prefix="/api/v1/config", tags=["config"])

# CLAUDE.md 파일 경로
CLAUDE_MD_PATH = boilerplate_root / "CLAUDE.md"


class ClaudeSectionUpdate(BaseModel):
	"""CLAUDE.md 섹션 업데이트 요청"""
	section: str  # "lessons_learned" 또는 "team_standards"
	content: str
	action: str  # "append" 또는 "replace"


class EnvVarUpdate(BaseModel):
	"""환경 변수 업데이트 요청"""
	target_path: str
	env_vars: Dict[str, str]  # key: value 쌍


class MigrationRequest(BaseModel):
	"""uv 마이그레이션 요청"""
	target_path: str


@router.get("/claude/sections")
async def get_claude_sections() -> Dict[str, str]:
	"""
	CLAUDE.md의 주요 섹션을 읽어 반환합니다.

	Returns:
		lessons_learned와 team_standards 섹션의 내용
	"""
	try:
		if not CLAUDE_MD_PATH.exists():
			raise HTTPException(status_code=404, detail="CLAUDE.md not found")

		content = CLAUDE_MD_PATH.read_text(encoding="utf-8")

		# Lessons Learned 섹션 추출
		lessons_match = re.search(
			r"## Lessons Learned\s*\n(.*?)(?=\n## |\Z)",
			content,
			re.DOTALL
		)
		lessons_learned = lessons_match.group(1).strip() if lessons_match else ""

		# Team Standards 섹션 추출
		standards_match = re.search(
			r"## 📋 Team Standards.*?\n(.*?)(?=\n## |\Z)",
			content,
			re.DOTALL
		)
		team_standards = standards_match.group(1).strip() if standards_match else ""

		return {
			"lessons_learned": lessons_learned,
			"team_standards": team_standards,
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.post("/claude/sections")
async def update_claude_section(update: ClaudeSectionUpdate) -> Dict[str, str]:
	"""
	CLAUDE.md의 특정 섹션을 업데이트합니다.

	Args:
		update: 섹션 업데이트 요청

	Returns:
		업데이트 결과
	"""
	try:
		if not CLAUDE_MD_PATH.exists():
			raise HTTPException(status_code=404, detail="CLAUDE.md not found")

		content = CLAUDE_MD_PATH.read_text(encoding="utf-8")

		# 섹션 매핑
		section_markers = {
			"lessons_learned": ("## Lessons Learned", r"## Lessons Learned\s*\n(.*?)(?=\n## |\Z)"),
			"team_standards": ("## 📋 Team Standards", r"## 📋 Team Standards.*?\n(.*?)(?=\n## |\Z)"),
		}

		if update.section not in section_markers:
			raise HTTPException(
				status_code=400,
				detail=f"Invalid section: {update.section}. Must be one of {list(section_markers.keys())}"
			)

		marker, pattern = section_markers[update.section]

		if update.action == "replace":
			# 섹션 전체 교체
			if re.search(pattern, content, re.DOTALL):
				content = re.sub(
					pattern,
					f"{marker}\n\n{update.content}\n",
					content,
					flags=re.DOTALL
				)
			else:
				# 섹션이 없으면 추가
				content += f"\n\n{marker}\n\n{update.content}\n"
		elif update.action == "append":
			# 섹션 끝에 추가
			match = re.search(pattern, content, re.DOTALL)
			if match:
				existing_content = match.group(1)
				new_content = f"{existing_content}\n\n{update.content}\n"
				content = re.sub(
					pattern,
					f"{marker}\n\n{new_content}",
					content,
					flags=re.DOTALL
				)
			else:
				# 섹션이 없으면 생성
				content += f"\n\n{marker}\n\n{update.content}\n"
		else:
			raise HTTPException(
				status_code=400,
				detail=f"Invalid action: {update.action}. Must be 'replace' or 'append'"
			)

		# 파일 쓰기
		CLAUDE_MD_PATH.write_text(content, encoding="utf-8")

		return {
			"status": "success",
			"message": f"Section '{update.section}' updated successfully",
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.get("/env/check")
async def check_env(target_path: str) -> Dict:
	"""
	환경 변수 상태를 확인합니다.

	Args:
		target_path: 대상 프로젝트 경로

	Returns:
		환경 변수 체크 결과
	"""
	try:
		check_env_script = boilerplate_root / "scripts" / "core" / "check_env.sh"

		if not check_env_script.exists():
			raise HTTPException(status_code=404, detail="check_env.sh not found")

		# check_env.sh 실행
		result = subprocess.run(
			["/bin/sh", str(check_env_script)],
			cwd=target_path,
			capture_output=True,
			text=True,
			timeout=30,
		)

		return {
			"return_code": result.returncode,
			"output": result.stdout,
			"error": result.stderr if result.returncode != 0 else None,
		}
	except subprocess.TimeoutExpired:
		raise HTTPException(status_code=504, detail="Environment check timeout")
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.post("/env/update")
async def update_env(update: EnvVarUpdate) -> Dict[str, str]:
	"""
	환경 변수를 업데이트합니다.

	Args:
		update: 환경 변수 업데이트 요청

	Returns:
		업데이트 결과
	"""
	try:
		target_path = Path(update.target_path)
		env_file = target_path / ".env"
		env_sample_file = target_path / ".env_sample"

		# .env_sample이 없으면 생성
		if not env_sample_file.exists():
			env_sample_file.write_text("")

		# .env 파일 읽기 (존재하는 경우)
		existing_vars = {}
		if env_file.exists():
			for line in env_file.read_text().splitlines():
				if "=" in line and not line.strip().startswith("#"):
					key = line.split("=")[0].strip()
					value = "=".join(line.split("=")[1:]).strip()
					existing_vars[key] = value

		# 새 환경 변수 병합
		existing_vars.update(update.env_vars)

		# .env 파일 쓰기
		env_content = "\n".join([f"{k}={v}" for k, v in existing_vars.items()])
		env_file.write_text(env_content)

		# .env_sample도 업데이트 (키만, 값은 dummy)
		sample_content = "\n".join([f"{k}=xxxxxx" for k in existing_vars.keys()])
		env_sample_file.write_text(sample_content)

		return {
			"status": "success",
			"message": f"Updated {len(update.env_vars)} environment variables",
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.post("/migrate/uv")
async def migrate_to_uv(request: MigrationRequest) -> StreamingResponse:
	"""
	Poetry 프로젝트를 uv로 마이그레이션합니다.
	실시간 로그를 스트리밍합니다.

	Args:
		request: 마이그레이션 요청

	Returns:
		실시간 로그 스트림
	"""
	migrate_script = boilerplate_root / "scripts" / "core" / "migrate_to_uv.sh"

	if not migrate_script.exists():
		raise HTTPException(status_code=404, detail="migrate_to_uv.sh not found")

	def generate_logs():
		"""마이그레이션 로그를 스트리밍"""
		try:
			process = subprocess.Popen(
				["/bin/sh", str(migrate_script)],
				cwd=request.target_path,
				stdout=subprocess.PIPE,
				stderr=subprocess.STDOUT,
				text=True,
				bufsize=1,
			)

			for line in process.stdout:
				# SSE 형식으로 전송
				yield f"data: {json.dumps({'type': 'log', 'message': line.rstrip()})}\n\n"

			process.wait()

			# 완료 메시지
			if process.returncode == 0:
				yield f"data: {json.dumps({'type': 'success', 'message': 'Migration completed successfully'})}\n\n"
			else:
				yield f"data: {json.dumps({'type': 'error', 'message': f'Migration failed with exit code {process.returncode}'})}\n\n"
		except Exception as e:
			yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

	return StreamingResponse(
		generate_logs(),
		media_type="text/event-stream",
		headers={
			"Cache-Control": "no-cache",
			"Connection": "keep-alive",
		},
	)


@router.get("/tools/check")
async def check_tools() -> Dict[str, Dict[str, Any]]:
	"""
	필수 도구(mise, uv, mcp, pnpm, gh)의 설치 상태를 확인합니다.

	Returns:
		각 도구의 설치 상태
	"""
	result = {
		"mise": {"installed": False, "version": None},
		"uv": {"installed": False, "version": None},
		"mcp": {"installed": False, "config_exists": False},
		"pnpm": {"installed": False, "version": None},
		"gh": {"installed": False, "version": None},
	}

	# mise 확인
	try:
		mise_result = subprocess.run(
			["mise", "--version"],
			capture_output=True,
			text=True,
			timeout=5,
		)
		if mise_result.returncode == 0:
			result["mise"]["installed"] = True
			result["mise"]["version"] = mise_result.stdout.strip()
	except Exception:
		pass

	# uv 확인
	try:
		uv_result = subprocess.run(
			["uv", "--version"],
			capture_output=True,
			text=True,
			timeout=5,
		)
		if uv_result.returncode == 0:
			result["uv"]["installed"] = True
			result["uv"]["version"] = uv_result.stdout.strip()
	except Exception:
		pass

	# pnpm 확인
	try:
		pnpm_result = subprocess.run(
			["pnpm", "--version"],
			capture_output=True,
			text=True,
			timeout=5,
		)
		if pnpm_result.returncode == 0:
			result["pnpm"]["installed"] = True
			result["pnpm"]["version"] = pnpm_result.stdout.strip()
	except Exception:
		pass

	# gh (GitHub CLI) 확인
	try:
		gh_result = subprocess.run(
			["gh", "--version"],
			capture_output=True,
			text=True,
			timeout=5,
		)
		if gh_result.returncode == 0:
			result["gh"]["installed"] = True
			# 버전 정보 추출 (예: "gh version 2.40.0")
			version_line = gh_result.stdout.split("\n")[0]
			result["gh"]["version"] = version_line.strip()
	except Exception:
		pass

	# MCP 설정 파일 확인
	mcp_config = boilerplate_root / ".mcp.json"
	result["mcp"]["config_exists"] = mcp_config.exists()
	result["mcp"]["installed"] = result["mcp"]["config_exists"]

	return result

