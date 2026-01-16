"""LangChain Tools CLI.

보일러플레이트 주입, 검증, 지식 동기화를 위한 명령줄 인터페이스.

사용법:
    uv run python -m langchain_tools.cli inject /path/to/project
    uv run python -m langchain_tools.cli verify /path/to/project
    uv run python -m langchain_tools.cli show-config /path/to/project
    uv run python -m langchain_tools.cli sync-knowledge --from /a --to /b
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import NoReturn


def create_parser() -> argparse.ArgumentParser:
    """CLI 파서를 생성합니다."""
    parser = argparse.ArgumentParser(
        prog="langchain_tools",
        description="AI-Native 보일러플레이트 CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  # 프로젝트에 보일러플레이트 주입
  uv run python -m langchain_tools.cli inject /path/to/project

  # 프로젝트 검증 실행
  uv run python -m langchain_tools.cli verify /path/to/project

  # 도구별 설정 가이드 출력
  uv run python -m langchain_tools.cli show-config /path/to/project

  # 프로젝트 간 지식 동기화
  uv run python -m langchain_tools.cli sync-knowledge --from /a --to /b

  # Agentic MoE 실행
  uv run python -m langchain_tools.cli agent interactive --prompt "Hello"
""",
    )

    subparsers = parser.add_subparsers(dest="command", help="명령어")

    # inject 명령
    inject_parser = subparsers.add_parser(
        "inject",
        help="보일러플레이트를 대상 프로젝트에 주입",
    )
    inject_parser.add_argument(
        "target",
        type=Path,
        help="주입 대상 프로젝트 경로",
    )
    inject_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="실제 파일을 생성하지 않고 미리보기만 표시",
    )
    inject_parser.add_argument(
        "--force",
        action="store_true",
        help="기존 파일 덮어쓰기",
    )

    # verify 명령
    verify_parser = subparsers.add_parser(
        "verify",
        help="프로젝트 검증 실행",
    )
    verify_parser.add_argument(
        "target",
        type=Path,
        nargs="?",
        default=Path.cwd(),
        help="검증 대상 프로젝트 경로 (기본값: 현재 디렉토리)",
    )

    # show-config 명령
    config_parser = subparsers.add_parser(
        "show-config",
        help="도구별 MCP 설정 가이드 출력",
    )
    config_parser.add_argument(
        "target",
        type=Path,
        nargs="?",
        default=Path.cwd(),
        help="대상 프로젝트 경로 (기본값: 현재 디렉토리)",
    )
    config_parser.add_argument(
        "--for",
        dest="tool",
        choices=["all", "claude-code", "cursor", "claude-desktop", "vscode", "antigravity"],
        default="all",
        help="특정 도구에 대한 가이드만 출력",
    )

    # sync-knowledge 명령
    sync_parser = subparsers.add_parser(
        "sync-knowledge",
        help="프로젝트 간 CLAUDE.md 지식 동기화",
    )
    sync_parser.add_argument(
        "--from",
        dest="source",
        type=Path,
        required=True,
        help="소스 프로젝트 경로",
    )
    sync_parser.add_argument(
        "--to",
        dest="destination",
        type=Path,
        required=True,
        help="대상 프로젝트 경로",
    )
    sync_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="실제 변경 없이 미리보기만 표시",
    )

    # agent 명령
    agent_parser = subparsers.add_parser(
        "agent",
        help="Agentic MoE 실행",
    )
    agent_parser.add_argument(
        "mode",
        choices=["interactive", "plan", "code", "verify", "studio", "server"],
        default="interactive",
        help="실행 모드 (interactive, studio, server 등)",
    )
    agent_parser.add_argument(
        "--prompt",
        help="초기 프롬프트 (Optional)",
    )
    return parser


def cmd_inject(args: argparse.Namespace) -> int:
    """inject 명령 실행."""
    from langchain_tools.inject import inject_boilerplate

    target = args.target.resolve()

    if not target.exists():
        print(f"❌ 대상 경로가 존재하지 않습니다: {target}", file=sys.stderr)
        return 1

    result = inject_boilerplate(
        target,
        dry_run=args.dry_run,
        force=args.force,
    )

    if result["status"] == "success":
        print(f"✅ 보일러플레이트 주입 완료: {target}")
        print("\n📋 생성된 파일:")
        for f in result.get("created_files", []):
            print(f"  - {f}")

        # 설정 가이드 출력
        print("\n" + "=" * 50)
        _print_setup_guide(target)
        return 0
    else:
        print(f"❌ 주입 실패: {result.get('message', 'Unknown error')}", file=sys.stderr)
        return 1


def cmd_verify(args: argparse.Namespace) -> int:
    """verify 명령 실행."""
    from langchain_tools.tools import (
        AutoVerifyTool,
        SimplifierTool,
        SecurityAuditTool,
        GitGuardTool,
    )

    target = args.target.resolve()
    print(f"🔍 검증 실행: {target}\n")

    tools = [
        ("스택 검증", AutoVerifyTool(project_root=target)),
        ("코드 복잡도", SimplifierTool(project_root=target)),
        ("보안 감사", SecurityAuditTool(project_root=target)),
        ("Git 규칙", GitGuardTool(project_root=target)),
    ]

    all_passed = True
    for name, tool in tools:
        print(f"▶ {name}...", end=" ")
        try:
            result = tool.invoke({})
            status = result.get("status", "unknown")
            if status in ("passed", "success", "secure"):
                print("✅")
            elif status == "skipped":
                print("⏭️ (건너뜀)")
            else:
                print(f"❌ ({status})")
                all_passed = False
        except Exception as e:
            print(f"❌ (오류: {e})")
            all_passed = False

    print()
    if all_passed:
        print("✅ 모든 검증 통과")
        return 0
    else:
        print("⚠️ 일부 검증 실패")
        return 1


def cmd_show_config(args: argparse.Namespace) -> int:
    """show-config 명령 실행."""
    target = args.target.resolve()
    tool_filter = args.tool

    _print_setup_guide(target, tool_filter=tool_filter)
    return 0


def _print_setup_guide(target: Path, tool_filter: str = "all") -> None:
    """도구별 설정 가이드를 출력합니다."""
    from langchain_tools.inject.setup_guide import generate_setup_guide

    guide = generate_setup_guide(target, tool_filter=tool_filter)
    print(guide)


def cmd_sync_knowledge(args: argparse.Namespace) -> int:
    """sync-knowledge 명령 실행."""
    from langchain_tools.sync import sync_knowledge

    source = args.source.resolve()
    destination = args.destination.resolve()

    for path, name in [(source, "소스"), (destination, "대상")]:
        if not path.exists():
            print(f"❌ {name} 경로가 존재하지 않습니다: {path}", file=sys.stderr)
            return 1

    result = sync_knowledge(
        source,
        destination,
        dry_run=args.dry_run,
    )

    if result["status"] == "success":
        print(f"✅ 지식 동기화 완료")
        print(f"  - 동기화된 항목: {result.get('synced_count', 0)}개")
        return 0
    else:
        print(f"❌ 동기화 실패: {result.get('message', 'Unknown error')}", file=sys.stderr)
        return 1

def cmd_agent(args: argparse.Namespace) -> int:
    """agent 명령 실행."""
    from langchain_tools.agent.graph.host import create_agent_graph
    from langchain_core.messages import HumanMessage
    from langchain_tools.agent.graph.state import AgentState

    mode = args.mode

    if mode == 'studio':
        print("🚀 Starting LangGraph Studio...")
        # Check if langgraph-cli is installed
        try:
            import subprocess
            subprocess.run(["langgraph", "dev"], check=True)
        except FileNotFoundError:
            print("❌ 'langgraph' CLI not found. Please install it with: uv pip install langgraph-cli[inmem]")
            return 1
        return 0

    if mode == 'server':
        print("🚀 Starting API Server...")
        # Basic Uvicorn runner for the graph (if we were to wrap it in FastAPI)
        # For now, we guide to use studio or implement simple uvicorn run if needed.
        # But let's just use langgraph dev as it provides the server too.
        print("ℹ️  For API server, LangGraph Studio also provides an API endpoint.")
        print("   Running 'langgraph dev' is recommended.")
        import subprocess
        subprocess.run(["langgraph", "dev"], check=True)
        return 0

    # Interactive Mode
    print(f"🚀 Starting Agentic MoE (Mode: {mode})...")

    prompt = args.prompt

    initial_state: AgentState = {
        "messages": [HumanMessage(content=prompt)] if prompt else [],
        "intent_path": None,
        "plan_path": None,
        "changed_files": [],
        "retry_count": 0
    }

    graph = create_agent_graph()

    print("🤖 [Supervisor] Routing...")

    try:
        # Run graph
        for event in graph.stream(initial_state):
            for key, value in event.items():
                print(f"  -> Node '{key}' executed.")
                if value and "messages" in value:
                    last_msg = value["messages"][-1].content
                    print(f"     Output: {last_msg}")
        return 0
    except KeyboardInterrupt:
        print("\n🛑 Agent stopped by user.")
        return 0
    except Exception as e:
        print(f"❌ 에이전트 실행 중 오류 발생: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


def main() -> NoReturn:
    """CLI 진입점."""
    parser = create_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    commands = {
        "inject": cmd_inject,
        "verify": cmd_verify,
        "show-config": cmd_show_config,
        "sync-knowledge": cmd_sync_knowledge,
        "agent": cmd_agent,
    }

    handler = commands.get(args.command)
    if handler:
        sys.exit(handler(args))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
