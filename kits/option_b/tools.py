import json
import subprocess
import os
from typing import Dict, Any, Optional
from langchain_core.tools import BaseTool
from pydantic import BaseModel, Field

class DockerMCPTool(BaseTool):
    """Base class for interacting with Dockerized MCP servers via one-off execution."""

    container_name: str = Field(description="Name of the docker container")
    command: list[str] = Field(description="Command to start the MCP server inside the container")
    tool_name: str = Field(description="Name of the tool to call")

    def _run(self, **kwargs) -> str:
        """Execute the tool by spinning up the MCP server, sending a request, and capturing output."""

        # Construct JSON-RPC Request
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": self.tool_name,
                "arguments": kwargs
            }
        }

        input_str = json.dumps(request) + "\n"

        # Build Docker command
        # using -i to keep stdin open for the input
        docker_cmd = ["docker", "exec", "-i", self.container_name] + self.command

        try:
            # We need to handle the lifecycle:
            # 1. Initialize (optional for some stateless tools, but technically required)
            # 2. Call Tool
            # Since we are running a fresh process, we try to just send the call
            # (Assuming the server doesn't enforce handshake for CLI usage or we send init first)

            # Note: Strict MCP requires 'initialize' first.
            # Let's try sending initialize then call_tool in one stream.

            init_req = {
                "jsonrpc": "2.0",
                "id": 0,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "option-b-agent", "version": "1.0"}
                }
            }

            full_input = json.dumps(init_req) + "\n" + json.dumps(request) + "\n"

            process = subprocess.Popen(
                docker_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            stdout, stderr = process.communicate(input=full_input)

            if process.returncode != 0:
                return f"Error executing tool: {stderr}"

            # Parse output. There will be multiple JSON lines.
            # We look for the one with id=1
            for line in stdout.splitlines():
                if not line.strip(): continue
                try:
                    resp = json.loads(line)
                    if resp.get("id") == 1:
                        if "error" in resp:
                            return f"Tool Error: {resp['error']['message']}"
                        if "result" in resp:
                            # MCP tool calls return {content: [{type: 'text', text: '...'}, ...]}
                            content = resp["result"].get("content", [])
                            text_content = [c["text"] for c in content if c["type"] == "text"]
                            return "\n".join(text_content)
                except json.JSONDecodeError:
                    continue

            return f"No valid response found. Raw output:\n{stdout}\nStderr:\n{stderr}"

        except Exception as e:
            return f"Exception running tool: {str(e)}"

# --- Local File Tools ---

class ReadFileTool(BaseTool):
    name: str = "read_file"
    description: str = "Read the contents of a file. Args: file_path (str)"

    def _run(self, file_path: str) -> str:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            return f"Error reading file: {e}"

class WriteFileTool(BaseTool):
    name: str = "write_file"
    description: str = "Write content to a file (overwrites). Args: file_path (str), content (str)"

    def _run(self, file_path: str, content: str) -> str:
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)
            return f"Successfully wrote to {file_path}"
        except Exception as e:
            return f"Error writing file: {e}"

# --- Tool Factory ---

SERENA_CMD = ["uvx", "--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"]
CODANNA_CMD = ["uvx", "--from", "git+https://github.com/code-yeongyu/codanna", "codanna", "start-mcp-server"]

def get_tools():
    return [
        DockerMCPTool(
            name="search_code",
            description="Search for code definitions/symbols. Args: query (str)",
            container_name="mcp-serena",
            command=SERENA_CMD,
            tool_name="search_symbol"
        ),
        DockerMCPTool(
            name="search_semantic",
            description="Search code semantically (conceptually). Args: query (str)",
            container_name="mcp-codanna",
            command=CODANNA_CMD,
            tool_name="search_semantic"
        ),
        ReadFileTool(),
        WriteFileTool(),
    ]
