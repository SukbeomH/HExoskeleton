"""
프롬프트 생성 로직

LLM 어시스턴트 초기 동기화를 위한 맞춤형 프롬프트를 생성합니다.
"""

from typing import Optional, Dict, Any
from pathlib import Path


def generate_setup_prompt(
	target_path: str,
	stack_info: Optional[Dict[str, Any]] = None,
	tool_status: Optional[Dict[str, Any]] = None,
) -> str:
	"""
	LLM 어시스턴트 초기 동기화 프롬프트 생성

	Args:
		target_path: 프로젝트 경로
		stack_info: 스택 정보 (stack, package_manager 등)
		tool_status: 도구 설치 상태 (선택적)

	Returns:
		생성된 프롬프트 문자열
	"""
	# 스택 정보 추출
	stack = stack_info.get("stack") if stack_info else None
	package_manager = stack_info.get("package_manager") if stack_info else None
	python_version = stack_info.get("python_version") if stack_info else None

	# 패키지 매니저 기본값 설정
	if not package_manager:
		if stack == "python":
			package_manager = "uv"
		elif stack == "node":
			package_manager = "pnpm"
		else:
			package_manager = "표준 패키지 관리자"

	# 스택별 맞춤 지시사항 생성
	stack_instructions = ""
	if stack == "python":
		stack_instructions = f"""
**5. Python 환경**: 이 프로젝트는 Python 스택을 사용하며, `uv`를 패키지 관리 표준으로 사용합니다.
   - Python 버전: {python_version if python_version else "프로젝트 설정 확인 필요"}
   - 가상 환경: `uv venv` 또는 `uv sync`를 통해 관리합니다.
   - 의존성 설치: `uv pip install -r requirements.txt` 또는 `uv sync`를 사용합니다."""
	elif stack == "node":
		stack_instructions = f"""
**5. Node.js 환경**: 이 프로젝트는 Node.js 스택을 사용하며, `pnpm`을 패키지 관리 표준으로 사용합니다.
   - 패키지 설치: `pnpm install`
   - 스크립트 실행: `pnpm run <script-name>`
   - 의존성 관리: `pnpm add <package>` 또는 `pnpm remove <package>`"""
	else:
		stack_instructions = f"""
**5. 프로젝트 스택**: 현재 프로젝트의 스택 정보를 확인하기 위해 `scripts/core/detect_stack.sh`를 실행하세요."""

	# 기본 프롬프트 템플릿
	prompt = f"""너는 이제부터 이 프로젝트의 **Senior AI-Native Software Engineer**로서 행동하라.
이 프로젝트에는 방금 **AI-Native Boilerplate**가 주입되었다.

**1. 지식 베이스 확인**: 프로젝트 루트의 `CLAUDE.md`를 먼저 읽고, 그곳에 정의된 AI Role, Persona, Anti-patterns, Team Standards를 완벽히 숙지하라.

**2. 프로토콜 준수**: 모든 작업은 `RIPER-5` 프로토콜(Research → Innovate → Plan → Execute → Review)을 엄격히 따라야 한다. 계획 수립 전에는 반드시 `spec.md`를 작성하거나 업데이트하라.

**3. MCP 도구 활용**: 사실 기반 분석을 위해 `Codanna`를, 정밀 편집을 위해 `Serena`를, 작업 관리를 위해 `Shrimp` MCP를 적극 활용하라.

**4. 환경 표준**: 이 프로젝트는 `{package_manager}`를 패키지 관리 표준으로 사용하며, 모든 검증은 `mise run verify` 또는 `scripts/verify-feedback-loop.js`를 통해 수행한다.{stack_instructions}

이제 첫 번째 작업으로, `scripts/core/detect_stack.sh`를 실행하여 현재 프로젝트의 스택을 확인하고 보고하라."""

	return prompt

