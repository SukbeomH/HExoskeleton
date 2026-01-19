from typing import Annotated, TypedDict, List, Optional
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    """
    Represents the state of the OmniGraph agent.
    """
    # History of conversation messages (managed by LangGraph)
    messages: Annotated[List, add_messages]

    # Context: The file currently being analyzed or modified
    current_file: Optional[str]

    # RAG: Documents retrieved from Local/Global indexes
    retrieved_docs: List[str]

    # Thinking: Classified intent (e.g., 'LOCAL_FIX', 'GLOBAL_QUERY')
    intent: Optional[str]

    # Planning: Specific context needed (e.g., ["local_impact", "global_pattern"])
    context_needs: List[str]
