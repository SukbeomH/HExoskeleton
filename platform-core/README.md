# OmniGraph Platform Core

> Global Hub for the OmniGraph Hybrid RAG Framework

## Overview

This is the central platform that:
- Receives data from Local Spokes via ingestion API
- Stores and queries the Neo4j Knowledge Graph
- Orchestrates LangGraph agents for hybrid thinking

## Quick Start

```bash
# Install dependencies
uv sync

# Start API server
python -m uvicorn api.app:app --reload --port 8000

# Start Neo4j (requires Docker)
docker-compose up -d
```

## Architecture

```
platform-core/
├── api/                 # FastAPI server
│   ├── app.py          # Main API endpoints
│   └── mcp_server.py   # MCP interface for Neo4j
├── graph-db/           # Neo4j schema and constraints
├── ingestion/          # Data pipeline utilities
├── orchestration/      # LangGraph agent
│   ├── graph.py       # StateGraph definition
│   ├── state.py       # AgentState TypedDict
│   └── nodes/         # Graph nodes
└── dashboard/          # Visualization layer
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Service info |
| `/health` | GET | Health check |
| `/stats` | GET | Knowledge graph stats |
| `/ingest` | POST | Receive data from spokes |
| `/query` | POST | Execute Cypher queries |

## Environment Variables

```
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=omnigraph
```
