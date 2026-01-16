"""보일러플레이트 주입 엔진."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader

from langchain_tools.tools.stack_detector import StackDetectorTool


# 템플릿 디렉토리
TEMPLATES_DIR = Path(__file__).parent / "templates"
# MCP 소스 디렉토리 (boilerplate/mcp)
MCP_SOURCE_DIR = Path(__file__).parent.parent.parent / "mcp"



def get_template_env() -> Environment:
    """Jinja2 템플릿 환경을 반환합니다."""
    return Environment(
        loader=FileSystemLoader(str(TEMPLATES_DIR)),
        trim_blocks=True,
        lstrip_blocks=True,
    )


def detect_stack(target: Path) -> dict[str, Any]:
    """대상 프로젝트의 스택을 감지합니다."""
    detector = StackDetectorTool(project_root=target)
    return detector._run()


def inject_boilerplate(
    target: Path,
    *,
    dry_run: bool = False,
    force: bool = False,
) -> dict[str, Any]:
    """보일러플레이트를 대상 프로젝트에 주입합니다.

    Args:
        target: 주입 대상 프로젝트 경로
        dry_run: True면 실제 파일 생성 없이 미리보기만 표시
        force: True면 기존 파일 덮어쓰기

    Returns:
        주입 결과 딕셔너리
    """
    result: dict[str, Any] = {
        "status": "success",
        "created_files": [],
        "skipped_files": [],
        "errors": [],
    }

    # 스택 감지
    stack_info = detect_stack(target)

    # 템플릿 컨텍스트
    context = {
        "project_name": target.name,
        "stack": stack_info["stack"],
        "package_manager": stack_info["package_manager"],
    }

    # 주입할 파일 목록
    files_to_inject = [
        ("CLAUDE.md.j2", "CLAUDE.md"),
        ("mise.toml.j2", "mise.toml"),
        (".mcp.json.j2", ".mcp.json"),
        (".cursor/mcp.json.j2", ".cursor/mcp.json"),
    ]

    # [New] Docker MCP 런타임 파일 복사
    mcp_dest_dir = target / ".mcp"
    mcp_dest_dir.mkdir(parents=True, exist_ok=True)

    # Docker 빌드 및 실행에 필요한 모든 파일 복사
    mcp_files_to_copy = [
        "mcp-docker-runner.js",
        "docker-compose.mcp.yml",
        "codanna.Dockerfile",
        "serena.Dockerfile",
        "shrimp.Dockerfile",
        "SKCC_ROOT.pem"
    ]

    for filename in mcp_files_to_copy:
        src = MCP_SOURCE_DIR / filename
        dst = mcp_dest_dir / filename

        if src.exists():
            if not dst.exists() or force:
                if not dry_run:
                    shutil.copy2(src, dst)
                result["created_files"].append(str(dst))
            else:
                result["skipped_files"].append(str(dst))
        else:
            # 필수 파일이 아니면 경고만 (예: pem 파일이 없을 수도 있음)
            if filename.endswith(".pem"):
                 result["errors"].append(f"Warning: SSL Cert not found: {src}")
            else:
                 result["errors"].append(f"MCP source file not found: {src}")


    env = get_template_env()

    for template_name, output_name in files_to_inject:
        output_path = target / output_name

        # 디렉토리 생성
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # 기존 파일 확인
        if output_path.exists() and not force:
            result["skipped_files"].append(str(output_path))
            continue

        try:
            # 템플릿 렌더링
            template_path = TEMPLATES_DIR / template_name
            if template_path.exists():
                template = env.get_template(template_name)
                content = template.render(**context)

                if not dry_run:
                    output_path.write_text(content, encoding="utf-8")

                result["created_files"].append(str(output_path))
            else:
                result["errors"].append(f"템플릿 없음: {template_name}")

        except Exception as e:
            result["errors"].append(f"{output_name}: {str(e)}")
            result["status"] = "partial"

    if result["errors"] and not result["created_files"]:
        result["status"] = "failed"

    return result
