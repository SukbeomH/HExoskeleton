"""
Runtime Dashboard: Real-time Agent Monitoring.

Run with: python -m runtime.app
Opens at: http://localhost:8001
"""

from fastapi import FastAPI, WebSocket, Request, BackgroundTasks
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
import asyncio
import json
import os
from dotenv import load_dotenv

from langchain_tools.core.logging import StructuredLogger, LogEvent
from langchain_tools.core.git import GitWorkflowManager
from langchain_tools.core.cli_worker import CLIWorker, TaskContext

app = FastAPI(title="Agent Dashboard")

BASE_DIR = Path(__file__).parent.resolve()
templates = Jinja2Templates(directory=BASE_DIR / "templates")

# Load environment variables (looking for .env in current dir, or parent, or .agent-booster/)
load_dotenv(BASE_DIR.parent / ".env")

# --- Path Resolution Strategy ---
env_root = os.getenv("PROJECT_ROOT")

if env_root:
    PROJECT_PATH = Path(env_root).resolve()
elif BASE_DIR.parent.name == ".agent-booster":
    PROJECT_PATH = BASE_DIR.parent.parent.resolve()
else:
    PROJECT_PATH = Path.cwd().resolve()

# Ensure we aren't using .agent-booster as root by accident
if PROJECT_PATH.name == ".agent-booster":
    PROJECT_PATH = PROJECT_PATH.parent.resolve()

print(f"✅ Dashboard Configured for Project Root: {PROJECT_PATH}")

# Initialize with absolute paths
logger = StructuredLogger(str(PROJECT_PATH / ".logs" / "events.db"))
git_mgr = GitWorkflowManager(str(PROJECT_PATH))

# Initialize Worker
# We default to "echo" to allow safe testing without real Claude Code installed
cli_command = os.getenv("CLI_COMMAND_PATH", "echo")
worker = CLIWorker(cli_command=cli_command, project_path=str(PROJECT_PATH))


def run_cli_task(task_id: str, prompt: str):
    """Background task to run the CLI worker."""
    context = TaskContext(
        task_id=task_id,
        work_dir=PROJECT_PATH,
        user_input=prompt,
        file_paths=[]
    )

    logger.log(LogEvent(task_id=task_id, phase="executing", actor="worker", message="Starting CLI Worker..."))

    result = worker.execute_task(context)

    if result.success:
        logger.log(LogEvent(task_id=task_id, phase="complete", actor="worker", message="Task completed successfully"))
    else:
        logger.log(LogEvent(task_id=task_id, phase="failed", actor="worker", message=f"Task failed: {result.output}"))


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})


@app.get("/api/state")
async def get_state():
    """Get current orchestrator state."""
    state = git_mgr.load_state()
    if state:
        return {
            "task_id": state.task_id,
            "phase": state.phase.value,
            "branch": state.branch_name,
            "locked_files": state.locked_files
        }
    return {"phase": "idle", "message": "No active task"}


@app.websocket("/ws/logs")
async def websocket_logs(websocket: WebSocket):
    """Stream logs in real-time via WebSocket."""
    await websocket.accept()

    last_count = 0

    try:
        while True:
            # Get current task
            state = git_mgr.load_state()
            task_id = state.task_id if state else "default"

            # Query new events
            events = logger.query_events(task_id, limit=100)

            if len(events) > last_count:
                # Send only new events
                new_events = events[last_count:]
                for event in new_events:
                    await websocket.send_json(event.dict())
                last_count = len(events)

            await asyncio.sleep(0.5)
    except Exception:
        await websocket.close()


@app.post("/api/task/start")
async def start_task(request: Request, background_tasks: BackgroundTasks):
    """Start a new task (runs CLI worker in background)."""
    data = await request.json()
    task_id = data.get("task_id", f"task-{os.urandom(4).hex()}")
    prompt = data.get("prompt", "Refactor the authentication module")

    git_mgr.init_task(task_id, f"feature/{task_id}")

    logger.log(LogEvent(
        task_id=task_id,
        phase="init",
        actor="dashboard",
        message=f"Task {task_id} initialized. Prompt: {prompt}"
    ))

    # Run the worker in the background
    background_tasks.add_task(run_cli_task, task_id, prompt)

    return {"success": True, "task_id": task_id}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
