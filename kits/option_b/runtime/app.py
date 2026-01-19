"""
Runtime Dashboard for Option B: LangGraph Agent with Real-time UI.

Run with: python -m runtime.app
Opens at: http://localhost:8002
"""

from fastapi import FastAPI, WebSocket, Request, BackgroundTasks, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pathlib import Path
import asyncio
import json
import os
from dotenv import load_dotenv
from datetime import datetime
from typing import AsyncIterator, Dict, Any

from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, AIMessage
from langgraph.prebuilt import create_react_agent
from langchain_tools.core.logging import StructuredLogger, LogEvent
from langchain_tools.core.git import GitWorkflowManager

# Import tools from Option B
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from tools import get_tools

app = FastAPI(title="Agent Dashboard - Option B")

BASE_DIR = Path(__file__).parent.resolve()
templates = Jinja2Templates(directory=BASE_DIR / "templates")

# Load environment variables
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

# Initialize
logger = StructuredLogger(str(PROJECT_PATH / ".logs" / "events.db"))
git_mgr = GitWorkflowManager(str(PROJECT_PATH))

# Global state
active_websockets = set()
current_task_id = None


def get_llm():
    """Initialize LLM based on environment variables."""
    openai_key = os.getenv("OPENAI_API_KEY")
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")

    if openai_key:
        return ChatOpenAI(model="gpt-4o", temperature=0)
    elif anthropic_key:
        return ChatAnthropic(model="claude-3-5-sonnet-20240620", temperature=0)
    else:
        raise ValueError("No API Key found. Set OPENAI_API_KEY or ANTHROPIC_API_KEY")


async def broadcast_event(event: dict):
    """Broadcast event to all connected WebSocket clients."""
    dead_sockets = set()
    for ws in active_websockets:
        try:
            await ws.send_json(event)
        except:
            dead_sockets.add(ws)

    # Clean up dead connections
    active_websockets.difference_update(dead_sockets)


async def run_agent_task(task_id: str, user_message: str):
    """Run LangGraph agent with real-time streaming."""
    global current_task_id
    current_task_id = task_id

    try:
        # Initialize
        model = get_llm()
        tools = get_tools()
        graph = create_react_agent(model, tools)

        # Log start
        logger.log(LogEvent(
            task_id=task_id,
            phase="executing",
            actor="agent",
            message=f"Starting agent: {user_message}"
        ))

        await broadcast_event({
            "type": "agent_start",
            "task_id": task_id,
            "message": user_message
        })

        # Stream agent execution
        async for event in graph.astream(
            {"messages": [HumanMessage(content=user_message)]},
            stream_mode="values"
        ):
            if "messages" in event:
                last_msg = event["messages"][-1]

                # Log AI messages
                if last_msg.type == "ai":
                    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
                        for tc in last_msg.tool_calls:
                            log_msg = f"🛠️ Calling tool: {tc['name']}"
                            logger.log(LogEvent(
                                task_id=task_id,
                                phase="executing",
                                actor="agent",
                                message=log_msg
                            ))
                            await broadcast_event({
                                "type": "tool_call",
                                "tool": tc['name'],
                                "args": tc.get('args', {})
                            })
                    elif last_msg.content:
                        logger.log(LogEvent(
                            task_id=task_id,
                            phase="executing",
                            actor="agent",
                            message=f"💡 {last_msg.content}"
                        ))
                        await broadcast_event({
                            "type": "ai_message",
                            "content": last_msg.content
                        })

                # Log tool outputs
                elif last_msg.type == "tool":
                    output_preview = last_msg.content[:200] if last_msg.content else ""
                    logger.log(LogEvent(
                        task_id=task_id,
                        phase="executing",
                        actor="tool",
                        message=f"✅ {output_preview}"
                    ))
                    await broadcast_event({
                        "type": "tool_output",
                        "content": output_preview
                    })

            # Small delay to prevent overwhelming
            await asyncio.sleep(0.1)

        # Completion
        logger.log(LogEvent(
            task_id=task_id,
            phase="complete",
            actor="agent",
            message="✅ Task completed successfully"
        ))

        await broadcast_event({
            "type": "agent_complete",
            "task_id": task_id
        })

    except Exception as e:
        error_msg = f"❌ Error: {str(e)}"
        logger.log(LogEvent(
            task_id=task_id,
            phase="failed",
            actor="agent",
            message=error_msg
        ))

        await broadcast_event({
            "type": "agent_error",
            "error": str(e)
        })


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})


@app.get("/api/state")
async def get_state():
    """Get current state."""
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
    """Stream logs and agent events via WebSocket."""
    await websocket.accept()
    active_websockets.add(websocket)

    try:
        # Send existing logs
        if current_task_id:
            events = logger.query_events(current_task_id, limit=100)
            for event in events:
                await websocket.send_json(event.dict())

        # Keep connection alive
        while True:
            # Wait for client ping or disconnect
            await websocket.receive_text()
            await asyncio.sleep(1)

    except WebSocketDisconnect:
        active_websockets.discard(websocket)
    except Exception:
        active_websockets.discard(websocket)


@app.post("/api/chat/send")
async def send_chat(request: Request, background_tasks: BackgroundTasks):
    """Send user message to agent."""
    data = await request.json()
    message = data.get("message", "")
    task_id = f"chat-{datetime.now().strftime('%Y%m%d%H%M%S')}"

    if not message:
        return {"error": "Message is required"}, 400

    # Initialize task
    git_mgr.init_task(task_id, f"feature/{task_id}")

    # Run agent in background
    background_tasks.add_task(run_agent_task, task_id, message)

    return {"success": True, "task_id": task_id}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
