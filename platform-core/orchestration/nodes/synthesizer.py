from ..state import AgentState
from langchain_core.messages import AIMessage

def synthesizer(state: AgentState) -> dict:
    """
    Combines context and generates final answer.
    """
    print("🧠 [Synthesizer] generating response...")

    docs = state.get("retrieved_docs", [])
    intent = state.get("intent", "UNKNOWN")

    # Simple Synthesis
    context_block = "\n- ".join(docs)
    answer = f"""
### Analysis (Intent: {intent})

Based on the hybrid context retrieved:

{context_block}

### Recommendation
Proceed with the implementation ensuring strict adherence to the defined patterns.
"""

    return {
        "messages": [AIMessage(content=answer)]
    }
