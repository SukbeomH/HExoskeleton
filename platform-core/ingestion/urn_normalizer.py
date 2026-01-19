import json
from datetime import datetime
from typing import Optional, Dict, Any, List
import sys
import os

# Add shared-libs to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'shared-libs'))
from urn_manager import URNManager

def normalize_to_urn(path: str, project_id: str, symbol: str = "") -> str:
    """
    Normalizes a local file path to a Global URN.
    """
    return URNManager.create_local_urn(project_id, path, symbol)

def extract_metadata_from_codegraph(codegraph_dump: dict) -> List[Dict[str, Any]]:
    """
    Extracts node metadata from CodeGraph export.
    Returns list of entities ready for Neo4j ingestion.
    """
    entities = []

    for item in codegraph_dump.get("functions", []):
        entities.append({
            "type": "Function",
            "urn": normalize_to_urn(item["file"], codegraph_dump.get("project_id", "unknown"), item["name"]),
            "name": item["name"],
            "file": item["file"],
            "line_start": item.get("line_start"),
            "line_end": item.get("line_end"),
            "signature": item.get("signature", ""),
            "docstring": item.get("docstring", "")
        })

    return entities

def prepare_cypher_statements(entities: List[Dict[str, Any]]) -> List[str]:
    """
    Generates Cypher MERGE statements for Neo4j ingestion.
    """
    statements = []

    for entity in entities:
        if entity["type"] == "Function":
            stmt = f"""
MERGE (f:Function {{urn: '{entity["urn"]}'}})
SET f.name = '{entity["name"]}',
    f.file = '{entity["file"]}',
    f.signature = '{entity.get("signature", "")}',
    f.updated_at = datetime()
"""
            statements.append(stmt.strip())

    return statements

def ingest_to_neo4j(statements: List[str], neo4j_uri: str, auth: tuple) -> dict:
    """
    Executes Cypher statements against Neo4j.
    Returns ingestion summary.
    """
    # This would use neo4j driver in real implementation
    # from neo4j import GraphDatabase
    # driver = GraphDatabase.driver(neo4j_uri, auth=auth)

    return {
        "status": "mock",
        "message": "Neo4j driver not configured. Would execute statements:",
        "statement_count": len(statements),
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    # Example usage
    sample_dump = {
        "project_id": "omnigraph",
        "functions": [
            {"name": "main", "file": "src/app.py", "line_start": 10, "line_end": 25}
        ]
    }

    entities = extract_metadata_from_codegraph(sample_dump)
    statements = prepare_cypher_statements(entities)

    for stmt in statements:
        print(stmt)
