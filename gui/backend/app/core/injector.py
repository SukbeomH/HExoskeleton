"""
파일 주입 로직

보일러플레이트 자산을 대상 프로젝트로 복사합니다.
"""

import shutil
import json
from pathlib import Path
from typing import List, Dict, Any, Optional
from app.core.backup import BackupManager
from app.models.schemas import InjectionOptions


class BoilerplateInjector:
	"""보일러플레이트 주입 클래스"""

	# 주입 가능한 자산 목록 및 소스 경로
	ASSETS_MAP = {
		".claude/": ".claude/",
		"scripts/": "scripts/",
		"CLAUDE.md": "CLAUDE.md",
		"mise.toml": "mise.toml",
		".mcp.json": ".mcp.json",
		"docs/ai-onboarding.md": "docs/ai-onboarding.md",
		"logging.conf": "logging.conf",
		"zmp-branch-policy.json": "zmp-branch-policy.json",
		".pre-commit-config.yaml": ".pre-commit-config.yaml",
		".github/workflows/": ".github/workflows/",
	}

	def __init__(self, boilerplate_root: Path):
		"""
		초기화

		Args:
			boilerplate_root: 보일러플레이트 프로젝트 루트 경로
		"""
		self.boilerplate_root = boilerplate_root
		self.backup_manager = BackupManager()

	def inject(
		self,
		target_path: str,
		assets: List[str],
		options: InjectionOptions,
	) -> Dict[str, Any]:
		"""
		보일러플레이트 자산 주입

		Args:
			target_path: 대상 프로젝트 경로
			assets: 주입할 자산 목록
			options: 주입 옵션

		Returns:
			주입 결과 딕셔너리
		"""
		target = Path(target_path).resolve()
		injected_files = []
		backed_up_files = []
		skipped_files = []
		merged_files = []

		try:
			for asset in assets:
				if asset not in self.ASSETS_MAP:
					continue

				source_path = self.boilerplate_root / self.ASSETS_MAP[asset]
				target_asset_path = target / asset.rstrip("/")

				# 소스 파일이 존재하는지 확인
				if not source_path.exists():
					skipped_files.append(asset)
					continue

				# 대상 경로에 이미 존재하는 경우
				if target_asset_path.exists():
					if options.skip_existing:
						skipped_files.append(asset)
						continue

					if options.backup_existing:
						backup_path = self.backup_manager.create_backup(target_asset_path)
						if backup_path:
							backed_up_files.append(str(backup_path.relative_to(target)))

					# .claude/ 설정 병합
					if asset == ".claude/" and options.merge_claude_config:
						if self._merge_claude_config(source_path, target_asset_path):
							merged_files.append(asset)
							continue

				# 파일/디렉토리 복사
				if self._copy_asset(source_path, target_asset_path):
					injected_files.append(asset)
				else:
					skipped_files.append(asset)

			return {
				"status": "success" if injected_files else "partial",
				"injected_files": injected_files,
				"backed_up_files": backed_up_files,
				"skipped_files": skipped_files,
				"merged_files": merged_files,
			}

		except Exception as e:
			return {
				"status": "error",
				"injected_files": injected_files,
				"backed_up_files": backed_up_files,
				"skipped_files": skipped_files,
				"merged_files": merged_files,
				"error": str(e),
			}

	def _copy_asset(self, source: Path, target: Path) -> bool:
		"""
		자산 복사

		Args:
			source: 소스 경로
			target: 대상 경로

		Returns:
			복사 성공 여부
		"""
		try:
			# 대상 디렉토리 생성
			target.parent.mkdir(parents=True, exist_ok=True)

			if source.is_file():
				shutil.copy2(source, target)
			elif source.is_dir():
				if target.exists():
					shutil.rmtree(target)
				shutil.copytree(source, target, dirs_exist_ok=True)

			return True
		except Exception as e:
			print(f"Error copying {source} to {target}: {e}")
			return False

	def _merge_claude_config(self, source_claude: Path, target_claude: Path) -> bool:
		"""
		.claude/ 설정 병합

		Args:
			source_claude: 소스 .claude/ 디렉토리
			target_claude: 대상 .claude/ 디렉토리

		Returns:
			병합 성공 여부
		"""
		try:
			source_settings = source_claude / "settings.json"
			target_settings = target_claude / "settings.json"

			if not source_settings.exists():
				return False

			# 기존 설정이 없으면 그냥 복사
			if not target_settings.exists():
				shutil.copy2(source_settings, target_settings)
				return True

			# 기존 설정 로드
			with open(target_settings, "r", encoding="utf-8") as f:
				target_config = json.load(f)

			with open(source_settings, "r", encoding="utf-8") as f:
				source_config = json.load(f)

			# JSON 구조 검증
			if not isinstance(target_config, dict):
				raise ValueError("Target config is not a valid JSON object")
			if not isinstance(source_config, dict):
				raise ValueError("Source config is not a valid JSON object")

			# 설정 병합
			merged_config = self._merge_json_config(target_config, source_config)

			# 병합된 설정 저장
			with open(target_settings, "w", encoding="utf-8") as f:
				json.dump(merged_config, f, indent=2, ensure_ascii=False)

			return True

		except Exception as e:
			print(f"Error merging .claude config: {e}")
			return False

	def _merge_json_config(self, target: Dict, source: Dict) -> Dict:
		"""
		JSON 설정 병합

		Args:
			target: 기존 설정
			source: 새 설정

		Returns:
			병합된 설정
		"""
		merged = target.copy()

		# permissions: 합집합 (중복 제거)
		if "permissions" in source:
			target_perms_list = target.get("permissions", [])
			source_perms_list = source.get("permissions", [])

			# 리스트 타입 검증
			if not isinstance(target_perms_list, list):
				target_perms_list = []
			if not isinstance(source_perms_list, list):
				source_perms_list = []

			# 모든 항목이 문자열인지 확인
			target_perms = set(p for p in target_perms_list if isinstance(p, str))
			source_perms = set(p for p in source_perms_list if isinstance(p, str))
			merged["permissions"] = sorted(list(target_perms | source_perms))

		# hooks: 새 설정 우선 (기존 설정 백업 후)
		if "hooks" in source:
			merged["hooks"] = source["hooks"]

		# 기타 설정: 새 설정으로 덮어쓰기 (단, 기존 설정이 없을 때만)
		for key, value in source.items():
			if key not in merged:
				merged[key] = value

		return merged

	def _post_process_python(self, target: Path) -> Dict[str, Any]:
		"""
		Python 프로젝트 후처리: Poetry 프로젝트를 uv로 마이그레이션

		Args:
			target: 대상 프로젝트 경로

		Returns:
			후처리 결과 딕셔너리
		"""
		result = {
			"executed": False,
			"success": False,
			"message": "",
			"migration": False,
		}

		# Python 프로젝트인지 확인 (pyproject.toml 존재)
		pyproject_toml = target / "pyproject.toml"
		poetry_lock = target / "poetry.lock"

		if not pyproject_toml.exists():
			result["message"] = "Not a Python project, skipping post-process"
			return result

		# poetry.lock이 있으면 uv 마이그레이션 실행
		if poetry_lock.exists():
			try:
				import subprocess

				# migrate_to_uv.sh 실행
				migrate_script = self.boilerplate_root / "scripts" / "core" / "migrate_to_uv.sh"
				if not migrate_script.exists():
					result["message"] = "migrate_to_uv.sh not found"
					return result

				result["executed"] = True
				result["migration"] = True

				# 마이그레이션 스크립트 실행
				migrate_result = subprocess.run(
					["bash", str(migrate_script), str(target)],
					cwd=target,
					capture_output=True,
					text=True,
					timeout=300,  # 5분 타임아웃
				)

				if migrate_result.returncode == 0:
					result["success"] = True
					result["message"] = "Successfully migrated from Poetry to uv"
					if migrate_result.stdout:
						result["message"] += f"\n{migrate_result.stdout[-500:]}"  # 마지막 500자만
				else:
					result["success"] = False
					result["message"] = f"Migration failed: {migrate_result.stderr[-500:] if migrate_result.stderr else 'Unknown error'}"

			except subprocess.TimeoutExpired:
				result["executed"] = True
				result["success"] = False
				result["message"] = "Migration timed out (exceeded 5 minutes)"
			except FileNotFoundError:
				result["executed"] = False
				result["message"] = "bash or migrate_to_uv.sh not found"
			except Exception as e:
				result["executed"] = True
				result["success"] = False
				result["message"] = f"Unexpected error during migration: {str(e)}"
		else:
			# poetry.lock이 없으면 단순히 uv 프로젝트로 확인
			result["message"] = "Not a Poetry project (no poetry.lock), skipping migration"

		return result

