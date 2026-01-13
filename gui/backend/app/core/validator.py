"""
사후 진단 로직

주입 후 환경 변수 체크 및 Git 상태 확인을 수행합니다.
"""

import subprocess
import json
from pathlib import Path
from typing import Dict, Any, Optional


class PostDiagnosisValidator:
	"""사후 진단 검증 클래스"""

	def __init__(self, boilerplate_root: Path):
		"""
		초기화

		Args:
			boilerplate_root: 보일러플레이트 프로젝트 루트 경로
		"""
		self.boilerplate_root = boilerplate_root
		self.check_env_script = boilerplate_root / "scripts" / "core" / "check_env.sh"

	def validate(self, target_path: str) -> Dict[str, Any]:
		"""
		사후 진단 수행

		Args:
			target_path: 대상 프로젝트 경로

		Returns:
			진단 결과 딕셔너리
		"""
		target = Path(target_path).resolve()

		return {
			# 환경변수 체크 비활성화: 주입될 프로젝트마다 환경변수가 다를 수 있음
			# 필요시 주석을 해제하여 활성화 가능
			# "env_check": self._check_env(target),
			"env_check": None,
			"git_status": self._check_git_status(target),
		}

	def _check_env(self, target: Path) -> Optional[Dict[str, Any]]:
		"""
		환경 변수 체크

		Args:
			target: 대상 프로젝트 경로

		Returns:
			환경 변수 체크 결과
		"""
		if not self.check_env_script.exists():
			return {"error": "check_env.sh not found"}

		try:
			result = subprocess.run(
				["bash", str(self.check_env_script)],
				cwd=target,
				capture_output=True,
				text=True,
				timeout=30,
			)

			# check_env.sh는 JSON을 출력하지 않으므로, 출력을 파싱
			output = result.stdout
			has_env_sample = ".env_sample file not found" not in output
			has_missing_keys = "Missing environment variables" in output or "누락된 환경 변수" in output

			return {
				"has_env_sample": has_env_sample,
				"has_missing_keys": has_missing_keys,
				"output": output,
				"return_code": result.returncode,
			}

		except subprocess.TimeoutExpired:
			return {"error": "Environment check timed out"}
		except Exception as e:
			return {"error": str(e)}

	def _check_git_status(self, target: Path) -> Optional[Dict[str, Any]]:
		"""
		Git 상태 확인

		Args:
			target: 대상 프로젝트 경로

		Returns:
			Git 상태 확인 결과
		"""
		git_dir = target / ".git"

		if not git_dir.exists():
			return {
				"is_git_repo": False,
				"message": "Not a Git repository. Consider running 'git init' first.",
			}

		try:
			# git status 실행
			result = subprocess.run(
				["git", "status", "--porcelain"],
				cwd=target,
				capture_output=True,
				text=True,
				timeout=10,
			)

			changed_files = [line.strip() for line in result.stdout.strip().split("\n") if line.strip()]
			branch_result = subprocess.run(
				["git", "branch", "--show-current"],
				cwd=target,
				capture_output=True,
				text=True,
				timeout=10,
			)
			current_branch = branch_result.stdout.strip() if branch_result.returncode == 0 else None

			return {
				"is_git_repo": True,
				"current_branch": current_branch,
				"changed_files": changed_files,
				"has_changes": len(changed_files) > 0,
			}

		except subprocess.TimeoutExpired:
			return {"error": "Git status check timed out"}
		except Exception as e:
			return {"error": str(e)}

