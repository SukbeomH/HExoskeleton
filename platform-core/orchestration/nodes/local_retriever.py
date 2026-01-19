from ..state import AgentState

# Simulate Context Window Limit
CODEGRAPH_CONTEXT_WINDOW = 4000  # tokens

def local_retriever(state: AgentState) -> dict:
    """
    Fast Retrieval: CodeGraph MCP
    Includes Overflow Protection.
    """
    print("⚡️ [Local Retriever] querying CodeGraph...")

    # Mock documents that might exceed limit
    raw_docs = [
        f"Local Context (Mock): Found reference in {state.get('current_file', 'unknown')}",
        "Local Context (Mock): Huge function body..." * 100
    ]

    # Overflow Protection Logic
    total_tokens = sum(len(d.split()) for d in raw_docs) # Rough approximation

    processed_docs = []
    current_tokens = 0

    for doc in raw_docs:
        tokens = len(doc.split())
        if current_tokens + tokens > CODEGRAPH_CONTEXT_WINDOW:
            print(f"⚠️ [Overflow Protection] Truncating local docs. Limit: {CODEGRAPH_CONTEXT_WINDOW}")
            break
        processed_docs.append(doc)
        current_tokens += tokens

    return {
        "retrieved_docs": processed_docs
    }
