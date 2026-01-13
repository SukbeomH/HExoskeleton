"""
로그 조회 및 분석 API

로컬 app.log 파일을 읽고 분석하는 API 엔드포인트를 제공합니다.
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pathlib import Path
import sys
import subprocess
import json
from typing import Optional

# 프로젝트 루트를 Python 경로에 추가
backend_root = Path(__file__).parent.parent.parent
boilerplate_root = backend_root.parent.parent
sys.path.insert(0, str(backend_root))

router = APIRouter(prefix="/api/v1/logs", tags=["logs"])

# log_analyzer.js 경로
LOG_ANALYZER_SCRIPT = boilerplate_root / "scripts" / "agents" / "log_analyzer.js"


@router.get("/analyze")
async def analyze_logs(target_path: Optional[str] = None, log_file: Optional[str] = None) -> dict:
	"""
	로컬 로그 파일을 분석합니다.

	Args:
		target_path: 대상 프로젝트 경로 (기본값: boilerplate_root)
		log_file: 로그 파일 경로 (기본값: {target_path}/app.log)

	Returns:
		로그 분석 결과 (JSON)
	"""
	try:
		analyze_path = target_path if target_path else str(boilerplate_root)
		log_file_path = log_file if log_file else str(Path(analyze_path) / "app.log")

		if not LOG_ANALYZER_SCRIPT.exists():
			raise HTTPException(status_code=404, detail="log_analyzer.js not found")

		# 로그 파일 존재 여부 확인
		if not Path(log_file_path).exists():
			raise HTTPException(
				status_code=404,
				detail=f"Log file not found: {log_file_path}. Please ensure the log file exists before analysis."
			)

		# 로그 파일이 비어있는지 확인
		if Path(log_file_path).stat().st_size == 0:
			raise HTTPException(
				status_code=400,
				detail=f"Log file is empty: {log_file_path}. No logs to analyze."
			)

		# log_analyzer.js 실행
		cmd = ["node", str(LOG_ANALYZER_SCRIPT), analyze_path]
		if log_file:
			cmd.append(log_file_path)

		result = subprocess.run(
			cmd,
			cwd=analyze_path,
			capture_output=True,
			text=True,
			timeout=30,
		)

		# JSON 출력 부분 추출
		output = result.stdout
		json_match = output.split("--- Log Analysis Results (JSON) ---")

		if len(json_match) > 1:
			try:
				json_data = json.loads(json_match[1].strip())
				return json_data
			except json.JSONDecodeError:
				pass

		# JSON 파싱 실패 시 기본 응답
		return {
			"status": "error" if result.returncode != 0 else "passed",
			"return_code": result.returncode,
			"output": output,
			"error": result.stderr if result.returncode != 0 else None,
		}
	except subprocess.TimeoutExpired:
		raise HTTPException(status_code=504, detail="Log analysis timeout")
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.get("/stream")
async def stream_logs(target_path: Optional[str] = None, log_file: Optional[str] = None) -> StreamingResponse:
	"""
	로컬 로그 파일을 실시간으로 스트리밍합니다.

	Args:
		target_path: 대상 프로젝트 경로
		log_file: 로그 파일 경로

	Returns:
		실시간 로그 스트림 (Server-Sent Events)
	"""
	analyze_path = target_path if target_path else str(boilerplate_root)
	log_file_path = log_file if log_file else str(Path(analyze_path) / "app.log")

	if not Path(log_file_path).exists():
		raise HTTPException(status_code=404, detail=f"Log file not found: {log_file_path}")

	def generate_log_stream():
		"""로그 파일을 실시간으로 스트리밍"""
		try:
			with open(log_file_path, 'r', encoding='utf-8') as f:
				# 파일 끝으로 이동 (새 로그만 읽기)
				f.seek(0, 2)

				# 실시간 읽기 (간단한 구현, 실제로는 tail -f와 유사)
				import time
				while True:
					line = f.readline()
					if line:
						yield f"data: {json.dumps({'type': 'log', 'message': line.rstrip()})}\n\n"
					else:
						time.sleep(0.1)
		except Exception as e:
			yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

	return StreamingResponse(
		generate_log_stream(),
		media_type="text/event-stream",
		headers={
			"Cache-Control": "no-cache",
			"Connection": "keep-alive",
		},
	)


@router.get("/read")
async def read_logs(
	target_path: Optional[str] = None,
	log_file: Optional[str] = None,
	lines: int = 100,
) -> dict:
	"""
	로컬 로그 파일의 최근 N줄을 읽습니다.

	Args:
		target_path: 대상 프로젝트 경로
		log_file: 로그 파일 경로
		lines: 읽을 줄 수 (기본값: 100)

	Returns:
		로그 라인 배열
	"""
	try:
		analyze_path = target_path if target_path else str(boilerplate_root)
		log_file_path = log_file if log_file else str(Path(analyze_path) / "app.log")

		if not Path(log_file_path).exists():
			return {
				"status": "not_found",
				"message": f"Log file not found: {log_file_path}",
				"lines": [],
			}

		# 파일의 마지막 N줄 읽기
		with open(log_file_path, 'r', encoding='utf-8') as f:
			all_lines = f.readlines()
			recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines

		return {
			"status": "success",
			"total_lines": len(all_lines),
			"lines": [line.rstrip() for line in recent_lines],
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))

