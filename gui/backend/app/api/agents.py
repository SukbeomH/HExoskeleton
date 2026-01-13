"""
에이전트 실행 API

각 서브 에이전트를 개별적으로 실행하고 결과를 반환하는 API 엔드포인트를 제공합니다.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from pathlib import Path
import sys
import subprocess
import json
from typing import Optional, Dict
from pydantic import BaseModel

# 프로젝트 루트를 Python 경로에 추가
backend_root = Path(__file__).parent.parent.parent
boilerplate_root = backend_root.parent.parent
sys.path.insert(0, str(backend_root))

router = APIRouter(prefix="/api/v1/agents", tags=["agents"])


class AgentRunRequest(BaseModel):
	"""에이전트 실행 요청"""
	agent_name: str  # "simplifier", "visual_verifier", "security_audit", "log_analyzer", "git_guard"
	target_path: Optional[str] = None
	options: Optional[Dict] = None


# 에이전트 스크립트 매핑
AGENT_SCRIPTS = {
	"simplifier": boilerplate_root / "scripts" / "agents" / "simplifier.js",
	"visual_verifier": boilerplate_root / "scripts" / "agents" / "visual_verifier.js",
	"security_audit": boilerplate_root / "scripts" / "agents" / "security-audit.js",
	"log_analyzer": boilerplate_root / "scripts" / "agents" / "log_analyzer.js",
	"git_guard": boilerplate_root / "skills" / "git-guard" / "run.js",
}


@router.post("/run")
async def run_agent(request: AgentRunRequest) -> Dict:
	"""
	개별 에이전트를 실행합니다.

	Args:
		request: 에이전트 실행 요청

	Returns:
		에이전트 실행 결과
	"""
	try:
		if request.agent_name not in AGENT_SCRIPTS:
			raise HTTPException(
				status_code=400,
				detail=f"Invalid agent name: {request.agent_name}. Must be one of {list(AGENT_SCRIPTS.keys())}"
			)

		script_path = AGENT_SCRIPTS[request.agent_name]

		if not script_path.exists():
			raise HTTPException(
				status_code=404,
				detail=f"Agent script not found: {script_path}"
			)

		# Node.js 스크립트 실행
		cmd = ["node", str(script_path)]

		# 옵션이 있으면 JSON으로 전달
		if request.options:
			import tempfile
			with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
				json.dump(request.options, f)
				cmd.append(f.name)

		# 작업 디렉토리 설정
		cwd = request.target_path if request.target_path else boilerplate_root

		result = subprocess.run(
			cmd,
			cwd=cwd,
			capture_output=True,
			text=True,
			timeout=300,  # 5분 타임아웃
		)

		if result.returncode != 0:
			return {
				"status": "failed",
				"error": result.stderr,
				"output": result.stdout,
			}

		# JSON 결과 파싱 시도
		try:
			output_json = json.loads(result.stdout)
			return {
				"status": "success",
				"result": output_json,
			}
		except json.JSONDecodeError:
			# JSON이 아니면 텍스트로 반환
			return {
				"status": "success",
				"result": {
					"output": result.stdout,
				},
			}
	except subprocess.TimeoutExpired:
		raise HTTPException(status_code=504, detail="Agent execution timeout")
	except Exception as e:
		raise HTTPException(status_code=500, detail=str(e))


@router.post("/run/stream")
async def run_agent_stream(request: AgentRunRequest) -> StreamingResponse:
	"""
	에이전트를 실행하고 실시간 로그를 스트리밍합니다.

	Args:
		request: 에이전트 실행 요청

	Returns:
		실시간 로그 스트림 (Server-Sent Events)
	"""
	if request.agent_name not in AGENT_SCRIPTS:
		raise HTTPException(
			status_code=400,
			detail=f"Invalid agent name: {request.agent_name}"
		)

	script_path = AGENT_SCRIPTS[request.agent_name]

	if not script_path.exists():
		raise HTTPException(
			status_code=404,
			detail=f"Agent script not found: {script_path}"
		)

	def generate_logs():
		"""에이전트 실행 로그를 스트리밍"""
		try:
			cmd = ["node", str(script_path)]

			if request.options:
				import tempfile
				with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
					json.dump(request.options, f)
					cmd.append(f.name)

			cwd = request.target_path if request.target_path else boilerplate_root

			process = subprocess.Popen(
				cmd,
				cwd=cwd,
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
				yield f"data: {json.dumps({'type': 'success', 'message': 'Agent completed successfully'})}\n\n"
			else:
				yield f"data: {json.dumps({'type': 'error', 'message': f'Agent failed with exit code {process.returncode}'})}\n\n"
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

