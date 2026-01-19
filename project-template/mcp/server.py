from mcp.server.fastmcp import FastMCP
import subprocess
import shutil
import json
from typing import Optional

# Initialize FastMCP server
mcp = FastMCP("Local CodeGraph")

def _is_codegraph_available() -> bool:
    """Check if codegraph CLI is installed."""
    return shutil.which("codegraph") is not None

def _mock_impact_analysis(file_paths: list[str]) -> dict:
    """Fallback mock implementation when codegraph is not available."""
    return {
        "status": "mock",
        "message": "CodeGraph CLI not found. Using mock data.",
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
        # Construct command
        cmd = ["codegraph", "impact"] + file_paths

        # Execute CodeGraph CLI
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
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
        # Construct command (hypothetical architecture command for CodeGraph)
        cmd = ["codegraph", "architecture"] + modules
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"
    except Exception as e:
        return f"Unexpected error: {str(e)}"

if __name__ == "__main__":
    mcp.run()
