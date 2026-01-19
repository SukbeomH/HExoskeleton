"""
MCP Server for Neo4j Integration (Real)

Standardized Tool Suite:
- cypher-tool: Schema-based query execution
- memory-tool: Long-term memory storage
"""

from mcp.server.fastmcp import FastMCP
from typing import Optional, Dict, Any, List
from neo4j import GraphDatabase
import json
import os

# Initialize FastMCP server
mcp = FastMCP("Global Neo4j Hub")

# Neo4j Driver Connection
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "omnigraph")

def get_driver():
    return GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

# --- Tool 1: Neo4j Cypher ---

@mcp.tool()
def neo4j_cypher_query(query: str, parameters: Optional[Dict[str, Any]] = None) -> str:
    """
    Executes a Cypher query against the Neo4j database.
    Equivalent to 'mcp-neo4j-cypher'.
    """
    try:
        with get_driver() as driver:
            result = driver.execute_query(
                query,
                parameters or {},
                database_="neo4j"
            )
            # result.records, result.summary, result.keys
            data = [record.data() for record in result.records]
            return json.dumps(data, default=str, indent=2)

    except Exception as e:
        return json.dumps({"error": str(e)}, indent=2)

# --- Tool 2: Neo4j Memory ---

@mcp.tool()
def neo4j_write_memory(key: str, value: str, context: Optional[str] = None) -> str:
    """
    Stores a long-term memory item in the Graph.
    Equivalent to 'mcp-neo4j-memory' [WRITE].
    Schema: (:Memory {key: $key, value: $value, context: $context, updated_at: datetime()})
    """
    cypher = """
    MERGE (m:Memory {key: $key})
    SET m.value = $value,
        m.context = $context,
        m.updated_at = datetime()
    RETURN m
    """
    try:
        with get_driver() as driver:
            result = driver.execute_query(
                cypher,
                {"key": key, "value": value, "context": context},
                database_="neo4j"
            )
            return json.dumps({"status": "success", "key": key}, indent=2)

    except Exception as e:
        return json.dumps({"error": str(e)}, indent=2)

@mcp.tool()
def neo4j_read_memory(key_pattern: str) -> str:
    """
    Retrieves long-term memory items matching a pattern.
    Equivalent to 'mcp-neo4j-memory' [READ].
    """
    cypher = """
    MATCH (m:Memory)
    WHERE m.key CONTAINS $pattern
    RETURN m.key as key, m.value as value, m.context as context
    LIMIT 5
    """
    try:
        with get_driver() as driver:
            result = driver.execute_query(
                cypher,
                {"pattern": key_pattern},
                database_="neo4j"
            )
            data = [record.data() for record in result.records]
            return json.dumps(data, indent=2)

    except Exception as e:
        return json.dumps({"error": str(e)}, indent=2)

if __name__ == "__main__":
    mcp.run()
