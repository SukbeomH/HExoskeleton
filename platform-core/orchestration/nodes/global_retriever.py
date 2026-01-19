from ..state import AgentState

def global_retriever(state: AgentState) -> dict:
    """
    Slow Retrieval: Neo4j Knowledge Graph
    """
    print("🌍 [Global Retriever] querying Neo4j...")

    # Mocking result
    found_docs = [
        "Global Context (Mock): Similar pattern found in 'UserAuth' module."
    ]

    return {
        "retrieved_docs": found_docs
    }
