from ..state import AgentState

def pruner(state: AgentState) -> dict:
    """
    Context Pruning Node.
    Filters retrieved documents based on relevance to the Intent.
    """
    print("✂️ [Pruner] filtering context...")

    docs = state.get("retrieved_docs", [])
    intent = state.get("intent", "UNKNOWN")

    pruned_docs = []

    # Mock Pruning Logic
    for doc in docs:
        if intent == "GLOBAL_QUERY" and "Local" in doc:
            # If intent is purely global, maybe prune local mocks (just example logic)
            # In reality, we use LLM to rate relevance
            pass

        # Simple rule: Remove duplicates or empty
        if doc and doc not in pruned_docs:
            pruned_docs.append(doc)

    # Simulate removal
    if len(docs) > len(pruned_docs):
        print(f"✂️ Pruned {len(docs) - len(pruned_docs)} documents.")

    return {
        "retrieved_docs": pruned_docs
    }
