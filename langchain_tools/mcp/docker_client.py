"""Docker MCP 클라이언트.

Docker 컨테이너로 실행되는 MCP 서버와 JSON-RPC 통신.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any


# mcp-docker-runner.js 경로
MCP_RUNNER_PATH = Path(__file__).parent.parent.parent / "mcp" / "mcp-docker-runner.js"


class MCPDockerClient:
    """Docker MCP 서버와 JSON-RPC 통신을 수행하는 클라이언트.

    mcp-docker-runner.js를 통해 Docker 컨테이너와 통신합니다.
    Antigravity 및 다른 IDE와 호환되도록 JSON-RPC만 stdout으로 출력합니다.
    """

    def __init__(
        self,
        container_name: str,
        *,
        project_path: Path | None = None,
        timeout: int = 120,
    ):
        """클라이언트 초기화.

        Args:
            container_name: MCP 컨테이너 이름 (serena, codanna, shrimp)
            project_path: 대상 프로젝트 경로 (TARGET_PROJECT_PATH 환경 변수로 전달)
            timeout: 타임아웃 (초)
        """
        self.container_name = container_name
        self.project_path = project_path or Path.cwd()
        self.timeout = timeout
        self._request_id = 0

    def _next_request_id(self) -> int:
        """다음 요청 ID를 반환합니다."""
        self._request_id += 1
        return self._request_id

    def call(
        self,
        method: str,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """MCP 서버에 JSON-RPC 요청을 보냅니다.

        Args:
            method: RPC 메서드 이름
            params: 메서드 파라미터

        Returns:
            응답 딕셔너리 또는 에러
        """
        request = {
            "jsonrpc": "2.0",
            "id": self._next_request_id(),
            "method": method,
            "params": params or {},
        }

        try:
            result = subprocess.run(
                ["node", str(MCP_RUNNER_PATH), self.container_name],
                input=json.dumps(request) + "\n",
                capture_output=True,
                text=True,
                timeout=self.timeout,
                env={
                    **subprocess.os.environ,
                    "TARGET_PROJECT_PATH": str(self.project_path),
                },
            )

            # stdout에서 JSON-RPC 응답 파싱
            for line in result.stdout.strip().split("\n"):
                if line.strip().startswith("{"):
                    try:
                        response = json.loads(line)
                        if "result" in response:
                            return {"status": "success", "result": response["result"]}
                        elif "error" in response:
                            return {"status": "error", "error": response["error"]}
                    except json.JSONDecodeError:
                        continue

            # 응답이 없으면 stderr 확인
            return {
                "status": "error",
                "error": result.stderr or "No response from MCP server",
            }

        except subprocess.TimeoutExpired:
            return {
                "status": "error",
                "error": f"Timeout after {self.timeout}s",
            }
        except FileNotFoundError:
            return {
                "status": "error",
                "error": f"mcp-docker-runner.js not found at {MCP_RUNNER_PATH}",
            }
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
            }

    def list_tools(self) -> dict[str, Any]:
        """MCP 서버에서 사용 가능한 도구 목록을 반환합니다."""
        return self.call("tools/list")

    def call_tool(
        self,
        tool_name: str,
        arguments: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """MCP 서버의 특정 도구를 호출합니다."""
        return self.call("tools/call", {
            "name": tool_name,
            "arguments": arguments or {},
        })
