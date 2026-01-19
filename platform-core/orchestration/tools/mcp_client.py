from langchain_mcp_adapters.client import MultiServerMCPClient

async def load_tools():
    """
    Connects to Local and Global MCP servers and returns usable Tools.
    """
    client = MultiServerMCPClient({
        "local-codegraph": {
            "transport": "stdio",
            "command": "python",
            "args": ["mcp/server.py"] # Assuming running from project root or adjusted path
        },
        "global-neo4j": {
            "transport": "sse",
            "url": "http://localhost:8000/mcp"
        }
    })

    # Verify connections
    # await client.initialize()

    return await client.get_tools()
