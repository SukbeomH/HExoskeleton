"""
Core Library: Shared components for all operational modes.

This package contains framework-agnostic utilities used by:
- Option A (Manual): Logging only
- Option B (Full Auto): Logging + Git
- Option C (Hybrid): Logging + Git + CLIWorker
"""

from langchain_tools.core.base_worker import BaseCodeWorker, TaskContext, ExecutionResult
from langchain_tools.core.logging import StructuredLogger, LogEvent
from langchain_tools.core.git import GitWorkflowManager, WorkflowPhase, TaskState
from langchain_tools.core.cli_worker import CLIWorker

__all__ = [
    # Interfaces
    "BaseCodeWorker",
    "TaskContext",
    "ExecutionResult",
    # Logging
    "StructuredLogger",
    "LogEvent",
    # Git
    "GitWorkflowManager",
    "WorkflowPhase",
    "TaskState",
    # Workers
    "CLIWorker",
]
