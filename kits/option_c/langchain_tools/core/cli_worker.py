"""
CLI Wrapper: Executes external CLI LLMs (Claude Code, Codex, etc.)

This module provides the CLIWorker class that implements BaseCodeWorker
for the Hybrid (Option C) mode.
"""

import subprocess
import os
from pathlib import Path
from typing import Iterator

from langchain_tools.core.base_worker import BaseCodeWorker, TaskContext, ExecutionResult
from langchain_tools.core.logging import StructuredLogger, LogEvent
from langchain_tools.core.git import GitWorkflowManager, WorkflowPhase


class CLIWorker(BaseCodeWorker):
    """
    Executes coding tasks using external CLI tools like Claude Code or Codex.
    """

    def __init__(
        self,
        cli_command: str = "claude",
        project_path: str = ".",
        timeout: int = 600
    ):
        self.cli_command = cli_command
        self.project_path = Path(project_path)
        self.timeout = timeout
        self.logger = StructuredLogger(str(self.project_path / ".logs" / "events.db"))
        self.git_mgr = GitWorkflowManager(str(self.project_path))
        self._status = "idle"

    def execute_task(self, context: TaskContext) -> ExecutionResult:
        """Execute a coding task using the configured CLI tool."""
        self._status = "executing"

        # Create guide file for the CLI
        guide_path = self.project_path / ".langchain-guides" / f"{context.task_id}.md"
        guide_path.parent.mkdir(parents=True, exist_ok=True)

        guide_content = f"""# Task: {context.task_id}

## User Request
{context.user_input}

## Instructions
Please implement the changes as described above.
Commit your changes when complete.
"""
        guide_path.write_text(guide_content)

        self.logger.log(LogEvent(
            task_id=context.task_id,
            phase="cli_execution",
            actor=self.cli_command,
            message=f"Starting CLI execution with guide: {guide_path}"
        ))

        # Update Git state
        self.git_mgr.update_phase(WorkflowPhase.EXECUTING)

        try:
            # Build command
            cmd = self._build_command(context, guide_path)

            # Execute
            process = subprocess.Popen(
                cmd,
                cwd=self.project_path,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            # Stream output
            output_lines = []
            for line in self._stream_output(process, context.task_id):
                output_lines.append(line)

            returncode = process.wait(timeout=self.timeout)

            if returncode != 0:
                stderr = process.stderr.read() if process.stderr else ""
                self._status = "failed"
                self.git_mgr.update_phase(WorkflowPhase.FAILED)
                return ExecutionResult(
                    success=False,
                    output="\n".join(output_lines),
                    metadata={"error": stderr, "returncode": returncode}
                )

            # Success
            self._status = "complete"
            self.git_mgr.update_phase(WorkflowPhase.VERIFYING)

            return ExecutionResult(
                success=True,
                output="\n".join(output_lines),
                artifacts=[str(guide_path)]
            )

        except subprocess.TimeoutExpired:
            self._status = "timeout"
            self.logger.log(LogEvent(
                task_id=context.task_id,
                phase="cli_execution",
                actor=self.cli_command,
                level="ERROR",
                message=f"CLI execution timed out after {self.timeout}s"
            ))
            return ExecutionResult(
                success=False,
                output="Timeout",
                metadata={"error": "timeout"}
            )
        except Exception as e:
            self._status = "error"
            return ExecutionResult(
                success=False,
                output=str(e),
                metadata={"error": str(e)}
            )

    def _build_command(self, context: TaskContext, guide_path: Path) -> list[str]:
        """Build the CLI command based on the configured tool."""
        if "claude" in self.cli_command.lower():
            return [
                self.cli_command,
                "-p", str(guide_path),
                "--allowedTools", "Edit,Write,Bash"
            ]
        elif "codex" in self.cli_command.lower():
            return [
                self.cli_command,
                "--task", context.task_id,
                "--guide", str(guide_path)
            ]
        else:
            # Generic fallback
            return [self.cli_command, str(guide_path)]

    def _stream_output(self, process: subprocess.Popen, task_id: str) -> Iterator[str]:
        """Stream and log output from the CLI process."""
        if process.stdout:
            for line in process.stdout:
                line = line.strip()
                if line:
                    self.logger.log(LogEvent(
                        task_id=task_id,
                        phase="cli_execution",
                        actor=self.cli_command,
                        message=line
                    ))
                    yield line

    def get_status(self) -> str:
        return self._status
