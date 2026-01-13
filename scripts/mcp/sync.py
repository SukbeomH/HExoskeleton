#!/usr/bin/env python3
"""
MCP 동기화 엔진
.mcp.json을 파싱하여 Cursor, Claude Desktop용 설정 스니펫을 생성합니다.
표준 도구(mise, uv, npx)만을 사용하여 프로젝트 환경이 자동 적용되도록 구성합니다.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, List

# 모든 출력은 stderr로 리다이렉트 (stdio 오염 방지)
def log(message: str, level: str = "info") -> None:
	"""stderr로 로그 출력"""
	prefix = {
		"info": "ℹ️",
		"success": "✅",
		"warning": "⚠️",
		"error": "❌",
	}.get(level, "ℹ️")
	print(f"{prefix} {message}", file=sys.stderr)


def load_mcp_config(project_root: Path) -> Dict[str, Any]:
	"""프로젝트 루트의 .mcp.json 파일 로드"""
	mcp_json_path = project_root / ".mcp.json"
	if not mcp_json_path.exists():
		log(f".mcp.json 파일을 찾을 수 없습니다: {mcp_json_path}", "error")
		sys.exit(1)

	try:
		with open(mcp_json_path, "r", encoding="utf-8") as f:
			return json.load(f)
	except json.JSONDecodeError as e:
		log(f".mcp.json 파싱 오류: {e}", "error")
		sys.exit(1)
	except Exception as e:
		log(f".mcp.json 읽기 오류: {e}", "error")
		sys.exit(1)


def is_path_like(arg: str) -> bool:
	"""인자가 파일 경로인지 판단 (npm 패키지 이름 등은 제외)"""
	# npm 패키지 이름 패턴 제외 (@scope/package, package-name 등)
	if arg.startswith("@") or (not os.path.sep in arg and not arg.startswith("./") and not arg.startswith("../")):
		return False
	# 실제 파일/디렉토리 경로인지 확인
	return os.path.sep in arg or arg.startswith("./") or arg.startswith("../")


def normalize_path(path_str: str, project_root: Path) -> str:
	"""상대 경로를 절대 경로로 변환"""
	if os.path.isabs(path_str):
		return path_str
	return str((project_root / path_str).resolve())


def build_command(server_name: str, server_config: Dict[str, Any], project_root: Path) -> str:
	"""
	서버 설정을 기반으로 mise x를 사용한 실행 명령어 생성

	규칙:
	- Serena: uvx 사용 (설치 없이 실행)
	- 기타 npx 서버: mise x -- npx -y [package]
	- 경로 관련 인자는 절대 경로로 변환
	"""
	command = server_config.get("command", "")
	args = server_config.get("args", [])

	# Serena는 uvx 사용
	if server_name == "serena":
		# uvx는 @modelcontextprotocol/server-serena를 직접 실행
		package = args[-1] if args else "@modelcontextprotocol/server-serena"
		return f"uvx {package}"

	# npx 서버는 mise x -- npx -y [package] 형식
	if command == "npx":
		# -y 플래그가 없으면 추가
		if "-y" not in args:
			args = ["-y"] + args

		# 경로 관련 인자가 있는지 확인하고 절대 경로로 변환
		normalized_args = []
		for arg in args:
			# 실제 파일 경로인 경우만 절대 경로로 변환
			if is_path_like(arg):
				normalized_args.append(normalize_path(arg, project_root))
			else:
				normalized_args.append(arg)

		# mise x -- npx -y [args...] 형식으로 구성
		args_str = " ".join(normalized_args)
		return f"mise x -- npx {args_str}"

	# 기타 명령어는 mise x -- [command] [args...] 형식
	normalized_args = []
	for arg in args:
		if is_path_like(arg):
			normalized_args.append(normalize_path(arg, project_root))
		else:
			normalized_args.append(arg)

	args_str = " ".join(normalized_args) if normalized_args else ""
	return f"mise x -- {command} {args_str}".strip()


def generate_cursor_config(mcp_config: Dict[str, Any], project_root: Path) -> str:
	"""Cursor IDE용 설정 스니펫 생성"""
	servers = mcp_config.get("mcpServers", {})
	project_name = project_root.name

	output = []
	output.append("🔧 Cursor IDE 설정 (Settings > Features > MCP Servers)")
	output.append("=" * 60)
	output.append("")
	output.append("다음 서버들을 하나씩 추가하세요:")
	output.append("")

	for server_name, server_config in servers.items():
		display_name = server_name.replace("-", " ").title()
		command = build_command(server_name, server_config, project_root)
		env_vars = server_config.get("env", {})
		description = server_config.get("comment", "No description")

		output.append(f"Name: {display_name}")
		output.append("Type: command")
		output.append(f"Command: {command}")

		if env_vars:
			output.append("Environment Variables:")
			for key, value in env_vars.items():
				# 환경 변수 플레이스홀더 처리
				if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
					env_key = value[2:-1]
					output.append(f"  {key}=${env_key}  # .env 파일에서 설정하세요")
				else:
					output.append(f"  {key}={value}")

		output.append(f"Description: {description}")
		output.append("---")
		output.append("")

	output.append("💡 팁:")
	output.append(f"   - 이름 충돌을 방지하기 위해 프로젝트별 접두어를 사용할 수 있습니다 (예: {project_name}-serena)")
	output.append("   - 각 서버를 추가한 후 'Test Connection' 버튼으로 연결을 확인하세요.")
	output.append("")

	return "\n".join(output)


def generate_claude_desktop_config(mcp_config: Dict[str, Any], project_root: Path) -> str:
	"""Claude Desktop용 설정 스니펫 생성"""
	servers = mcp_config.get("mcpServers", {})

	# mise x를 사용하도록 변환된 서버 설정 생성
	converted_servers = {}
	for server_name, server_config in servers.items():
		converted_config = server_config.copy()
		command = build_command(server_name, server_config, project_root)

		# command와 args를 분리
		parts = command.split()

		# 충분한 요소가 있는지 확인 후 접근
		if len(parts) >= 3 and parts[0] == "mise" and parts[1] == "x" and parts[2] == "--":
			# mise x -- 이후의 명령어 추출
			converted_config["command"] = parts[3] if len(parts) > 3 else ""
			converted_config["args"] = parts[4:] if len(parts) > 4 else []
		elif len(parts) >= 1 and parts[0] == "uvx":
			converted_config["command"] = "uvx"
			converted_config["args"] = parts[1:] if len(parts) > 1 else []
		elif len(parts) >= 1:
			converted_config["command"] = parts[0]
			converted_config["args"] = parts[1:] if len(parts) > 1 else []
		else:
			# 빈 명령어인 경우 기본값 설정
			converted_config["command"] = ""
			converted_config["args"] = []

		converted_servers[server_name] = converted_config

	output = []
	output.append("🤖 Claude Desktop 설정 (Global Config)")
	output.append("=" * 60)
	output.append("")
	output.append("~/.config/claude_desktop_config.json 파일에 다음 내용을 추가하세요:")
	output.append("")

	config_json = {
		"mcpServers": converted_servers
	}

	output.append(json.dumps(config_json, indent=2, ensure_ascii=False))
	output.append("")
	output.append("💡 팁:")
	output.append("   - Claude Desktop은 전역 설정을 사용하므로 모든 프로젝트에서 동일한 MCP 서버를 사용합니다.")
	output.append("   - 프로젝트별로 다른 설정이 필요한 경우 Claude Code를 사용하세요.")
	output.append("")

	return "\n".join(output)


def main():
	"""메인 함수"""
	# 프로젝트 루트 찾기 (스크립트 위치 기준)
	script_dir = Path(__file__).parent
	project_root = script_dir.parent.parent

	# 현재 작업 디렉토리 확인
	cwd = Path.cwd()
	if (cwd / ".mcp.json").exists():
		project_root = cwd

	log(f"프로젝트 루트: {project_root}")

	# .mcp.json 로드
	mcp_config = load_mcp_config(project_root)
	log(".mcp.json 로드 완료", "success")

	# 설정 스니펫 생성
	cursor_config = generate_cursor_config(mcp_config, project_root)
	claude_desktop_config = generate_claude_desktop_config(mcp_config, project_root)

	# stdout으로 출력 (stderr는 로그용)
	print("\n" + cursor_config)
	print("\n" + claude_desktop_config)

	log("MCP 동기화 가이드 생성 완료", "success")


if __name__ == "__main__":
	main()

