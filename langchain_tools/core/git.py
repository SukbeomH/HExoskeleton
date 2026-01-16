import json
import subprocess
from enum import Enum
from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel

class WorkflowPhase(str, Enum):
    IDLE = "idle"
    PLANNING = "planning"
    EXECUTING = "executing"
    VERIFYING = "verifying"
    MERGED = "merged"
    FAILED = "failed"

class TaskState(BaseModel):
    task_id: str
    phase: WorkflowPhase
    branch_name: str
    locked_files: List[str] = []

class GitWorkflowManager:
    """
    Manages the Git lifecycle for tasks.
    - Creates branches
    - Commits changes
    - Manages 'lock' state (via a hidden file used by Orchestrator)
    """
    def __init__(self, repo_path: str = "."):
        self.repo_path = Path(repo_path)
        self.state_file = self.repo_path / ".git" / "langchain_task_state.json"

    def _run_git(self, args: List[str]) -> str:
        result = subprocess.run(
            ["git"] + args,
            cwd=self.repo_path,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()

    def init_task(self, task_id: str, branch_name: str) -> TaskState:
        # Create branch
        try:
            self._run_git(["checkout", "-b", branch_name])
        except subprocess.CalledProcessError:
            # Branch might exist, switch to it
            self._run_git(["checkout", branch_name])

        state = TaskState(
            task_id=task_id,
            phase=WorkflowPhase.PLANNING,
            branch_name=branch_name
        )
        self._save_state(state)
        return state

    def update_phase(self, phase: WorkflowPhase):
        state = self.load_state()
        if state:
            state.phase = phase
            self._save_state(state)

    def lock_files(self, files: List[str]):
        state = self.load_state()
        if state:
            state.locked_files = files
            self._save_state(state)

    def commit_changes(self, message: str, author: str = "AI Worker"):
        # config user if needed (omitted for brevity, assuming global config)
        self._run_git(["add", "."])
        self._run_git(["commit", "-m", f"{message} (by {author})", "--allow-empty"])

    def _save_state(self, state: TaskState):
        with open(self.state_file, "w") as f:
            f.write(state.model_dump_json(indent=2))

    def load_state(self) -> Optional[TaskState]:
        if not self.state_file.exists():
            return None
        try:
            with open(self.state_file, "r") as f:
                return TaskState.model_validate_json(f.read())
        except Exception:
            return None
