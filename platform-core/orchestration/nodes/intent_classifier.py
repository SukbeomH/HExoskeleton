from typing import Literal
from ..state import AgentState

def intent_classifier(state: AgentState) -> AgentState:
    """
    Analyzes the user's last message to determine intent.
    Decides if the request requires Local Context, Global Context, or Both.
    """
    last_message = state["messages"][-1].content

    # Mock logic (would be LLM call)
    if "repository" in last_message or "architecture" in last_message:
        intent = "GLOBAL_QUERY"
        needs = ["global_pattern"]
    elif "fix" in last_message or "bug" in last_message:
        intent = "LOCAL_FIX"
        needs = ["local_impact"]
    else:
        intent = "HYBRID"
        needs = ["global_pattern", "local_impact"]

    return {
        "intent": intent,
        "context_needs": needs
    }

def route_intent(state: AgentState):
    """
    Conditional edge router based on intent.
    """
    intent = state.get("intent")
    if intent == "GLOBAL_QUERY":
        return "global_retriever"
    elif intent == "LOCAL_FIX":
        return "local_retriever"
    else:
        return ["local_retriever", "global_retriever"]
