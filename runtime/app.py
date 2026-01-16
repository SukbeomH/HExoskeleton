"""
Runtime Dashboard: Real-time Agent Monitoring.

Run with: python -m runtime.app
Opens at: http://localhost:8001
"""

from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
import asyncio
import json

from langchain_tools.core.logging import StructuredLogger, LogEvent
from langchain_tools.core.git import GitWorkflowManager

app = FastAPI(title="Agent Dashboard")

BASE_DIR = Path(__file__).parent
templates = Jinja2Templates(directory=BASE_DIR / "templates")

# Default project path (can be overridden)
PROJECT_PATH = Path.cwd()
logger = StructuredLogger(str(PROJECT_PATH / ".logs" / "events.db"))
git_mgr = GitWorkflowManager(str(PROJECT_PATH))


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
async def start_task(request: Request):
    """Start a new task (for demo/testing)."""
    data = await request.json()
    task_id = data.get("task_id", "demo-task")

    git_mgr.init_task(task_id, f"feature/{task_id}")
    logger.log(LogEvent(
        task_id=task_id,
        phase="init",
        actor="dashboard",
        message=f"Task {task_id} started"
    ))

    return {"success": True, "task_id": task_id}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
