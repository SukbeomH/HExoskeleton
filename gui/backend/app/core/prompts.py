"""
프롬프트 생성 로직

LLM 어시스턴트 초기 동기화를 위한 맞춤형 프롬프트를 생성합니다.
Codanna 기반 전수 분석 및 MCP 활성화 단계를 포함합니다.
"""

from typing import Optional, Dict, Any
from pathlib import Path


def generate_setup_prompt(
	target_path: str,
	stack_info: Optional[Dict[str, Any]] = None,
	tool_status: Optional[Dict[str, Any]] = None,
) -> str:
	"""
	LLM 어시스턴트 초기 동기화 프롬프트 생성 (Codanna 분석 및 MCP 활성화 포함)

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
	detected_files = stack_info.get("detected_files", []) if stack_info else []

	# 패키지 매니저 기본값 설정
	if not package_manager:
		if stack == "python":
			package_manager = "uv"
		elif stack == "node":
			package_manager = "pnpm"
		else:
			package_manager = "표준 패키지 관리자"

	# 프로젝트 경로 정규화 (상대 경로 표시)
	target_path_obj = Path(target_path)
	project_name = target_path_obj.name

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

	# MCP 활성화 지시사항 (스택별)
	mcp_activation = ""
	if stack == "python" or stack == "node":
		# 웹 프로젝트인 경우 Chrome DevTools 추가
		mcp_activation = """
   - **웹 프로젝트**: `Chrome DevTools MCP` 연결을 확인하여 브라우저 UI 검증이 가능한지 테스트하라."""

	# 감지된 파일 목록 (있으면 표시)
	detected_files_note = ""
	if detected_files:
		key_files = [f for f in detected_files if any(x in f.lower() for x in ["package.json", "pyproject.toml", "cargo.toml", "go.mod"])]
		if key_files:
			detected_files_note = f"\n   - 감지된 주요 파일: {', '.join(key_files[:3])}"

	# 개선된 프롬프트 템플릿 (Codanna 분석 및 MCP 활성화 포함)
	prompt = f"""너는 이제부터 이 프로젝트의 **Senior AI-Native Software Engineer**로서 행동하라.
이 프로젝트(`{project_name}`)에는 방금 **AI-Native Boilerplate**가 주입되었다.

다음 **초기 분석 및 구성** 단계를 순차적으로 수행하라:

---

## Step 1. Codanna 전수 분석 (RESEARCH 모드)

**목적**: 주입된 보일러플레이트 자산(`CLAUDE.md`, `mise.toml`, `scripts/`)과 기존 코드베이스의 관계를 '사실' 기반으로 파악하라.

**동작**:
1. `Codanna MCP`의 `semantic_search_with_context` 또는 `get_index_info` 도구를 사용하여 프로젝트 전체 구조를 스캔하라.
2. 핵심 설정 파일(`pyproject.toml`, `package.json`, `mise.toml`, `CLAUDE.md` 등)의 위치와 내용을 확인하라.
3. 주입된 `scripts/` 디렉토리의 스크립트들이 기존 프로젝트 구조와 어떻게 통합되는지 분석하라.
4. 발견된 구조적 특이사항이나 잠재적 충돌을 기록하라.

**보고 형식**: "✅ Codanna 분석 완료 - [주요 발견사항 3-5개 요약]"

---

## Step 2. 스택 및 도구 감지 (Environment Sync)

**목적**: 기술 스택을 확정하고 패키지 매니저와 검증 도구를 준비하라.

**동작**:
1. `scripts/core/detect_stack.sh`를 실행하여 환경 변수(`DETECTED_STACK`, `DETECTED_PACKAGE_MANAGER`)를 로드하라.
2. `mise install` 상태를 최종 확인하고, 필요한 도구(`uv`, `pnpm`, `gh` 등)가 설치되어 있는지 검증하라.
3. 패키지 매니저 표준이 올바르게 적용되었는지 확인하라 (Python: `uv`, Node: `pnpm`).{detected_files_note}

**보고 형식**: "✅ 스택 감지 완료 - Stack: {stack or '미감지'}, Package Manager: {package_manager}"

---

## Step 3. MCP 서버 활성화 (Tool Activation)

**목적**: 감지된 스택과 프로젝트 성격에 따라 필요한 MCP 서버들을 활성화하고 상태를 점검하라.

**동작**:
1. **공통 필수 MCP**:
   - `Shrimp Task Manager`: `list_tasks` 또는 `get_current_config`로 초기화 확인
   - `Serena`: `get_symbols_overview`로 프로젝트 심볼 검색 가능 여부 확인
   - `Codanna`: 이미 Step 1에서 사용했으므로 정상 동작 확인됨
   - `Context7`: 대규모 코드베이스인 경우 컨텍스트 최적화 준비

2. **도메인별 MCP** (프로젝트 성격에 따라):{mcp_activation}
   - **API 프로젝트**: `Proxymock MCP` 및 `Playwright` 준비 상태 확인

3. `.mcp.json` 설정 파일을 확인하고, 각 서버의 `comment_usage`를 숙지하라.

**보고 형식**: "✅ MCP 활성화 완료 - [활성화된 MCP 서버 목록]"

---

## Step 4. 지식 베이스 동기화 (Knowledge Base Sync)

**목적**: `CLAUDE.md`의 규칙과 이 프로젝트만의 특이사항을 연결하라.

**동작**:
1. `CLAUDE.md`의 `Best Practices`와 `Anti-patterns` 섹션을 숙지하라.
2. Step 1의 Codanna 분석에서 발견한 이 프로젝트만의 구조적 특이사항이 있다면, `CLAUDE.md`의 `Lessons Learned` 섹션에 첫 번째 기록을 남겨라.
   - 형식: "### {오늘 날짜} - 초기 분석 발견사항"
   - 내용: 프로젝트 구조, 주요 디렉토리, 설정 파일 위치 등

**보고 형식**: "✅ 지식 베이스 동기화 완료 - [기록한 주요 발견사항]"

---

## Step 5. 최종 보고 및 작업 등록

**동작**:
1. 위 4단계의 결과를 종합하여 **프로젝트 초기 분석 보고서**를 작성하라:
   - 프로젝트 구조 요약
   - 스택 및 도구 상태
   - 활성화된 MCP 서버 목록
   - 발견된 특이사항 및 권장사항

2. 다음 작업(Task #1)을 `Shrimp Task Manager`에 등록하라:
   - 작업명: "프로젝트 초기 분석 완료 및 첫 작업 계획"
   - 설명: 초기 분석 결과를 바탕으로 첫 번째 개발 작업을 계획

---

**프로젝트 경로**: `{target_path}`
**패키지 매니저**: `{package_manager}`
{stack_instructions}

준비되었다면 Step 1부터 순차적으로 시작하라."""

	return prompt

