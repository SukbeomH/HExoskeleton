# Option C: Hybrid Mode Instructions

## Overview
This mode combines a **lightweight LangChain Orchestrator** with your **existing CLI LLM subscription** (Claude Code, Codex, etc.) to minimize API costs while maintaining full control.

## Architecture
```
User Request → Orchestrator (Planning) → CLI Tool (Coding) → Orchestrator (Verification) → Merge
```

## Setup
1.  **Configure Environment**:
    Copy `.env.example` to `.env` and set:
    ```
    PROJECT_MODE="option_c"
    CLI_COMMAND_PATH="claude"  # or "codex", "gemini"
    ```

2.  **Start MCP Services**:
    ```bash
    docker-compose -f mcp/docker-compose.mcp.yml up -d
    ```

3.  **Start Dashboard**:
    ```bash
    python -m runtime.app
    ```
    Opens at `http://localhost:8001`

## Workflow
1.  Open Dashboard.
2.  Submit a task: "Refactor the auth module".
3.  Watch: `Planning` → `Executing` → `Verifying`.
4.  Review the diff, approve merge.

## Key Features
-   **Cost Efficiency**: Uses your existing Claude/Codex subscription.
-   **Full Visibility**: Real-time logs in the Dashboard.
-   **Safe Merging**: Orchestrator verifies changes before merging.
