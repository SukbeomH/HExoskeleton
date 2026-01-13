"""
Pydantic 스키마 정의

API 요청/응답 모델을 정의합니다.
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, field_validator
from pathlib import Path


class DetectRequest(BaseModel):
	"""스택 감지 API 요청 모델"""
	target_path: str = Field(..., description="대상 프로젝트 경로")

	@field_validator("target_path")
	@classmethod
	def validate_path(cls, v: str) -> str:
		"""경로 유효성 검증"""
		path = Path(v).resolve()
		if not path.exists():
			raise ValueError(f"Path does not exist: {v}")
		if not path.is_dir():
			raise ValueError(f"Path is not a directory: {v}")
		return str(path)


class DetectResponse(BaseModel):
	"""스택 감지 API 응답 모델"""
	stack: Optional[str] = Field(None, description="감지된 스택 (python, node, go, rust 등)")
	package_manager: Optional[str] = Field(None, description="패키지 매니저 (poetry, pnpm, npm, go, cargo 등)")
	venv_path: Optional[str] = Field(None, description="가상 환경 경로 (Python의 경우)")
	python_version: Optional[str] = Field(None, description="Python 버전 (Python 프로젝트의 경우)")
	detected_files: List[str] = Field(default_factory=list, description="감지된 파일 목록")
	error: Optional[str] = Field(None, description="에러 메시지 (감지 실패 시)")


class InjectionOptions(BaseModel):
	"""주입 옵션 모델"""
	backup_existing: bool = Field(True, description="기존 파일 백업 여부")
	merge_claude_config: bool = Field(False, description=".claude/ 설정 병합 여부")
	skip_existing: bool = Field(False, description="기존 파일 건너뛰기 여부")


class InjectRequest(BaseModel):
	"""파일 주입 API 요청 모델"""
	target_path: str = Field(..., description="대상 프로젝트 경로")
	assets: List[str] = Field(..., description="주입할 자산 목록")
	options: InjectionOptions = Field(default_factory=InjectionOptions, description="주입 옵션")

	@field_validator("target_path")
	@classmethod
	def validate_path(cls, v: str) -> str:
		"""경로 유효성 검증"""
		path = Path(v).resolve()
		if not path.exists():
			raise ValueError(f"Path does not exist: {v}")
		if not path.is_dir():
			raise ValueError(f"Path is not a directory: {v}")
		return str(path)

	@field_validator("assets")
	@classmethod
	def validate_assets(cls, v: List[str]) -> List[str]:
		"""자산 목록 유효성 검증"""
		valid_assets = [
			".claude/", "scripts/", "CLAUDE.md", "mise.toml", "docs/ai-onboarding.md",
			"logging.conf", "zmp-branch-policy.json", ".pre-commit-config.yaml"
		]
		for asset in v:
			if asset not in valid_assets:
				raise ValueError(f"Invalid asset: {asset}. Valid assets: {valid_assets}")
		return v


class PostDiagnosis(BaseModel):
	"""사후 진단 결과 모델"""
	env_check: Optional[Dict[str, Any]] = Field(None, description="환경 변수 체크 결과")
	git_status: Optional[Dict[str, Any]] = Field(None, description="Git 상태 확인 결과")


class PostProcess(BaseModel):
	"""후처리 결과 모델"""
	executed: bool = Field(..., description="후처리 실행 여부")
	success: bool = Field(..., description="후처리 성공 여부")
	message: str = Field(..., description="후처리 메시지")


class InjectResponse(BaseModel):
	"""파일 주입 API 응답 모델"""
	status: str = Field(..., description="주입 상태 (success, partial, error)")
	injected_files: List[str] = Field(default_factory=list, description="주입된 파일 목록")
	backed_up_files: List[str] = Field(default_factory=list, description="백업된 파일 목록")
	skipped_files: List[str] = Field(default_factory=list, description="건너뛴 파일 목록")
	merged_files: List[str] = Field(default_factory=list, description="병합된 파일 목록")
	post_diagnosis: Optional[PostDiagnosis] = Field(None, description="사후 진단 결과")
	post_process: Optional[PostProcess] = Field(None, description="후처리 결과 (Poetry 설정 등)")
	setup_prompt: Optional[str] = Field(None, description="LLM 어시스턴트 초기 동기화 프롬프트")
	error: Optional[str] = Field(None, description="에러 메시지 (실패 시)")

