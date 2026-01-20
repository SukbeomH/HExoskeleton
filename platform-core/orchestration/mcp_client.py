"""
OmniGraph MCP Client (v1.2)

Uses langchain-mcp-adapters for standard MCP integration.
"Don't Reinvent the Wheel" - Uses official MultiServerMCPClient instead of custom implementation.

References:
- https://github.com/langchain-ai/langchain-mcp-adapters
"""

from typing import Dict, Any, List, Optional
from langchain_core.tools import BaseTool

# Note: Install with `pip install langchain-mcp-adapters`
try:
    from langchain_mcp_adapters.client import MultiServerMCPClient
except ImportError:
    raise ImportError(
        "langchain-mcp-adapters not found. Install with: pip install langchain-mcp-adapters"
    )


class MCPToolManager:
    """
    Manages MCP tool connections using the standard langchain-mcp-adapters library.

    This class eliminates the need for custom MCP client implementations by leveraging
    the official LangChain adapter, which handles:
    - Multi-server connections
    - Error handling and retries
    - Tool schema conversion to LangChain format
    """

    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        Initialize the MCP Tool Manager.

        Args:
            config: Optional custom configuration. If not provided, uses default config.
        """
        self.config = config or self._default_config()
        self._client: Optional[MultiServerMCPClient] = None
        self._tools: List[BaseTool] = []

    @staticmethod
    def _default_config() -> Dict[str, Any]:
        """
        Default MCP server configuration for OmniGraph.

        Servers:
        - local-codegraph: Local AST analysis via CodeGraph binary
        - global-neo4j: Global knowledge graph via mcp-neo4j-cypher
        """
        return {
            "local-codegraph": {
                "command": "codegraph",
                "args": ["start", "stdio"],
                "transport": "stdio",
                "env": {
                    "CODEGRAPH_CONTEXT_WINDOW": "8000",  # Token limit
                }
            },
            "global-neo4j": {
                "url": "http://localhost:8000/mcp",
                "transport": "sse",
                # Uses official mcp-neo4j-cypher server image
            }
        }

    async def initialize(self) -> None:
        """
        Initialize the MCP client and establish connections.

        This is a lazy initialization - call this before using tools.
        """
        if self._client is not None:
            return

        self._client = MultiServerMCPClient(self.config)
        self._tools = await self._client.get_tools()

    async def get_tools(self) -> List[BaseTool]:
        """
        Get all available MCP tools as LangChain Tools.

        Returns:
            List of LangChain BaseTool instances ready to use with agents.
        """
        if not self._tools:
            await self.initialize()
        return self._tools

    async def get_tools_by_server(self, server_name: str) -> List[BaseTool]:
        """
        Get tools from a specific MCP server.

        Args:
            server_name: Name of the server (e.g., "local-codegraph", "global-neo4j")

        Returns:
            List of tools from the specified server.
        """
        all_tools = await self.get_tools()
        # Filter by server namespace (tools are typically prefixed with server name)
        return [t for t in all_tools if t.name.startswith(server_name)]

    def get_local_tools(self) -> List[BaseTool]:
        """Get only local (CodeGraph) tools - for fast thinking."""
        return [t for t in self._tools if "codegraph" in t.name.lower()]

    def get_global_tools(self) -> List[BaseTool]:
        """Get only global (Neo4j) tools - for slow thinking."""
        return [t for t in self._tools if "neo4j" in t.name.lower()]

    async def close(self) -> None:
        """Close all MCP connections gracefully."""
        if self._client:
            await self._client.close()
            self._client = None
            self._tools = []


# Convenience function for quick tool loading
async def load_mcp_tools(config: Optional[Dict[str, Any]] = None) -> List[BaseTool]:
    """
    Quick function to load all MCP tools.

    Usage:
        tools = await load_mcp_tools()
        agent = create_react_agent(llm, tools, prompt)

    Args:
        config: Optional custom MCP server configuration

    Returns:
        List of LangChain tools from all configured MCP servers
    """
    manager = MCPToolManager(config)
    return await manager.get_tools()


# Example configuration for different environments
DEVELOPMENT_CONFIG = {
    "local-codegraph": {
        "command": "codegraph",
        "args": ["start", "stdio"],
        "transport": "stdio"
    },
    # Development uses local Neo4j container
    "global-neo4j": {
        "url": "http://localhost:8000/mcp",
        "transport": "sse"
    }
}

PRODUCTION_CONFIG = {
    "local-codegraph": {
        "command": "codegraph",
        "args": ["start", "stdio"],
        "transport": "stdio"
    },
    # Production uses external Neo4j cluster
    "global-neo4j": {
        "url": "http://neo4j-mcp.internal:8000/mcp",
        "transport": "sse"
    }
}
