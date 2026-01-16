# Option B: Full Auto Mode Instructions

## Overview
This mode provides a **Fully Autonomous AI Agent** powered by LangGraph. It connects to the Dockerized MCP tools (Serena, Codanna) and uses an external LLM (OpenAI/Anthropic) to plan, execute, and verify tasks autonomously.

## Prerequisites
- Docker & Docker Compose
- Python 3.12+
- OpenAI API Key (or Anthropic API Key)

## Setup
1.  **Configure Environment**:
    Copy `.env.example` to `.env` and set:
    ```bash
    PROJECT_MODE="option_b"
    OPENAI_API_KEY="sk-..."  # Required
    # OR
    ANTHROPIC_API_KEY="sk-ant-..."
    ```

2.  **Start MCP Services**:
    ```bash
    docker-compose -f mcp/docker-compose.mcp.yml up -d
    ```

3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

## Usage
Run the agent with a natural language task:

```bash
python agent.py "Refactor the auth module to use JWT instead of sessions"
```

## How it works
1.  **Plan**: The agent breaks down your request into steps.
2.  **Research**: It uses **Serena** (Symbol Search) and **Codanna** (Semantic Search) to understand the codebase.
3.  **Act**: It writes code to modify your project files.
4.  **Verify**: It (optionally) runs tests to ensure correctness.
