from abc import ABC, abstractmethod
from typing import Any, Dict, Optional
from pydantic import BaseModel

class TaskContext(BaseModel):
    task_id: str
    work_dir: str
    user_input: str
    metadata: Dict[str, Any] = {}

class ExecutionResult(BaseModel):
    success: bool
    output: str
    artifacts: list[str] = []
    metadata: Dict[str, Any] = {}

class BaseCodeWorker(ABC):
    """
    Abstract Base Class for Code Execution Workers.
    This allows us to swap between:
    - AgentWorker (LangGraph API)
    - CLIWorker (Claude Code / Codex CLI)
    """

    @abstractmethod
    def execute_task(self, context: TaskContext) -> ExecutionResult:
        pass

    @abstractmethod
    def get_status(self) -> str:
        pass
