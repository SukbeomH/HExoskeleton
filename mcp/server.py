"""
OmniGraph Local MCP Server

Provides:
1. CodeGraph Rust integration (AST analysis, dependency analysis)
2. Memory system (team knowledge storage and retrieval)

Usage:
    uv run python mcp/server.py
"""

from mcp.server.fastmcp import FastMCP
import subprocess
import shutil
import json
import os
from datetime import datetime
from typing import Optional, List, Dict, Any
from pathlib import Path

# Initialize FastMCP server
mcp = FastMCP("OmniGraph Local")

# Memory file path (relative to project root)
MEMORY_FILE = Path(".agent/memory.jsonl")


# =============================================================================
# Memory System
# =============================================================================

def _ensure_memory_file() -> Path:
    """Ensure memory file exists and return its path."""
    if not MEMORY_FILE.parent.exists():
        MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not MEMORY_FILE.exists():
        MEMORY_FILE.touch()
    return MEMORY_FILE


def _load_memories() -> List[Dict[str, Any]]:
    """Load all memories from JSONL file."""
    path = _ensure_memory_file()
    memories = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    memories.append(json.loads(line))
    except Exception:
        pass
    return memories


def _save_memory(memory: Dict[str, Any]) -> None:
    """Append a memory to the JSONL file."""
    path = _ensure_memory_file()
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(memory, ensure_ascii=False) + "\n")


@mcp.tool()
def memory_store(
    content: str,
    category: str = "general",
    tags: Optional[List[str]] = None,
    metadata: Optional[Dict[str, Any]] = None
) -> str:
    """
    Store knowledge in project memory for future reference.

    Use this to save:
    - Project conventions and patterns
    - Team decisions and rationale
    - Lessons learned from debugging
    - Architecture notes
    - API quirks and workarounds

    Args:
        content: The knowledge to store (be specific and actionable)
        category: One of 'convention', 'decision', 'pattern', 'issue', 'general'
        tags: Optional list of tags for filtering
        metadata: Optional additional metadata

    Returns:
        Confirmation with memory ID
    """
    memory = {
        "id": f"mem_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{len(_load_memories())}",
        "content": content,
        "category": category,
        "tags": tags or [],
        "metadata": metadata or {},
        "created_at": datetime.now().isoformat(),
        "source": "agent"
    }

    _save_memory(memory)

    return json.dumps({
        "status": "stored",
        "id": memory["id"],
        "category": category,
        "message": f"Memory stored successfully. Use 'memory_find' to retrieve."
    }, indent=2)


@mcp.tool()
def memory_find(
    query: Optional[str] = None,
    category: Optional[str] = None,
    tags: Optional[List[str]] = None,
    limit: int = 10
) -> str:
    """
    Retrieve stored knowledge from project memory.

    Use this to recall:
    - Past decisions about the project
    - Known patterns and conventions
    - Previously encountered issues

    Args:
        query: Optional text to search in content
        category: Filter by category ('convention', 'decision', 'pattern', 'issue', 'general')
        tags: Filter by tags (any match)
        limit: Maximum results to return (default: 10)

    Returns:
        List of matching memories with metadata
    """
    memories = _load_memories()
    results = []

    for mem in memories:
        # Filter by category
        if category and mem.get("category") != category:
            continue

        # Filter by tags (any match)
        if tags:
            mem_tags = set(mem.get("tags", []))
            if not any(t in mem_tags for t in tags):
                continue

        # Filter by query (simple substring match)
        if query:
            content = mem.get("content", "").lower()
            if query.lower() not in content:
                continue

        results.append(mem)

        if len(results) >= limit:
            break

    return json.dumps({
        "status": "found",
        "count": len(results),
        "total_memories": len(memories),
        "results": results
    }, indent=2, ensure_ascii=False)


@mcp.tool()
def memory_list_categories() -> str:
    """
    List all memory categories and their counts.

    Returns:
        Category breakdown of stored memories
    """
    memories = _load_memories()
    categories: Dict[str, int] = {}

    for mem in memories:
        cat = mem.get("category", "general")
        categories[cat] = categories.get(cat, 0) + 1

    return json.dumps({
        "status": "ok",
        "total_memories": len(memories),
        "categories": categories,
        "available_categories": ["convention", "decision", "pattern", "issue", "general"]
    }, indent=2)


# =============================================================================
# CodeGraph Integration
# =============================================================================

def _is_codegraph_available() -> bool:
    """Check if codegraph CLI is installed."""
    return shutil.which("codegraph") is not None


def _mock_impact_analysis(file_paths: list[str]) -> dict:
    """Fallback mock implementation when codegraph is not available."""
    return {
        "status": "mock",
        "message": "CodeGraph CLI not found. Install from: https://github.com/Jakedismo/codegraph-rust",
        "files": file_paths,
        "incoming_dependencies": ["(mock) No real data available"],
        "outgoing_dependencies": ["(mock) No real data available"],
        "risk_level": "unknown"
    }


@mcp.tool()
def agentic_impact(file_paths: list[str]) -> str:
    """
    Analyzes the impact of changes to specific files using CodeGraph.
    Returns a dependency analysis report.

    Falls back to mock data if codegraph CLI is not installed.
    """
    if not _is_codegraph_available():
        mock_result = _mock_impact_analysis(file_paths)
        return json.dumps(mock_result, indent=2)

    try:
        cmd = ["codegraph", "impact"] + file_paths
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error running CodeGraph: {e.stderr}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"


@mcp.tool()
def codegraph_search(query: str, limit: int = 10) -> str:
    """
    Searches the local codebase for symbols matching the query.
    Uses CodeGraph's search functionality.
    """
    if not _is_codegraph_available():
        return json.dumps({
            "status": "mock",
            "message": "CodeGraph CLI not found.",
            "query": query,
            "results": []
        }, indent=2)

    try:
        cmd = ["codegraph", "search", query, "--limit", str(limit)]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"


@mcp.tool()
def codegraph_index(paths: Optional[list[str]] = None) -> str:
    """
    Triggers CodeGraph to re-index the codebase.
    Optionally accepts specific paths to index.
    """
    if not _is_codegraph_available():
        return json.dumps({
            "status": "mock",
            "message": "CodeGraph CLI not found. Cannot re-index."
        }, indent=2)

    try:
        cmd = ["codegraph", "index"]
        if paths:
            cmd.extend(paths)
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"


@mcp.tool()
def agentic_architecture(modules: list[str]) -> str:
    """
    Checks for architectural violations between specific modules.
    Returns existing patterns and potential violations.
    """
    if not _is_codegraph_available():
        return json.dumps({
            "status": "mock",
            "message": "CodeGraph CLI not found. Using mock architecture check.",
            "violations": [
                {"type": "LayerSkip", "details": "Mock: Controller -> Repository detected"}
            ]
        }, indent=2)

    try:
        cmd = ["codegraph", "architecture"] + modules
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"


if __name__ == "__main__":
    mcp.run()
