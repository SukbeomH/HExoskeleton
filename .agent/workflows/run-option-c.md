---
description: Run Option C Hybrid Dashboard
---

# Run Option C Hybrid Dashboard

Step-by-step workflow for running the Hybrid mode with real-time dashboard and CLI integration.

## Prerequisites

1. Boilerplate already injected into target project via Launcher
2. `.agent-booster/` directory exists in target project
3. Virtual environment activated

## Start Dashboard Server

// turbo-all
1. Navigate to injected directory:
```bash
cd <your-project>/.agent-booster
```

2. Verify environment variables:
```bash
cat .env
```

Ensure these are set:
- `PROJECT_MODE="option_c"`
- `LOG_DB_PATH=".logs/events.db"`
- `CLI_COMMAND_PATH` (set to "mock" for testing, or path to real CLI)

3. Start the Dashboard:
```bash
python -m uvicorn runtime.app:app --host 0.0.0.0 --port 8001 --reload
```

4. Open browser to `http://localhost:8001`

## Testing with Mock Agent

5. In the Dashboard, click **"▶️ Start Demo"**
   - This runs `mock_agent.py` to simulate agent behavior
   - No API keys required
   - Logs appear in real-time

6. Test control buttons:
   - **⏸️ Pause** - Suspends execution
   - **▶️ Resume** - Continues execution
   - **🗑️ Clear** - Clears log display

## Using Real CLI Integration

7. Update `.env` to use real CLI:
```bash
CLI_COMMAND_PATH="/path/to/claude"  # or other CLI tool
```

8. Restart Dashboard (Ctrl+C then repeat step 3)

9. Click **"▶️ Start"** to run with real CLI

## Verify Logs

10. Check SQLite logs:
```bash
sqlite3 .logs/events.db "SELECT * FROM logs ORDER BY timestamp DESC LIMIT 10;"
```

11. Check Git integration (if enabled):
```bash
git branch  # Should see feature/ai-task-* branches
git log --oneline
```

## WebSocket Testing

12. Open browser console (F12) and check WebSocket connection:
   - Look for: `WebSocket connection established`
   - Messages should stream in real-time

## Stopping the Dashboard

13. Press `Ctrl+C` in terminal to stop server

14. Optionally stop MCP servers (if running):
```bash
cd /Users/sukbeom/Desktop/workspace/boilerplate/mcp
docker-compose -f docker-compose.mcp.yml down
```

## Troubleshooting

**Dashboard not loading:**
- Check port 8001 is not in use: `lsof -ti:8001`
- Verify `.env` file exists
- Check console for errors

**Logs not appearing:**
- Refresh browser (F5)
- Check WebSocket connection in browser console
- Verify `LOG_DB_PATH` in `.env`

**Mock agent not running:**
- Check Python path in `mock_agent.sh`
- Verify execute permissions: `chmod +x mock_agent.sh`
- Run directly: `python mock_agent.py "test task"`
