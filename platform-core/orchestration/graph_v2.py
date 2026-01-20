"""
OmniGraph LangGraph Orchestration (v1.2)

Hybrid RAG Agent with Local (CodeGraph) + Global (Neo4j) thinking.
Uses LangGraph Command pattern for simplified routing control.

Key v1.2 Updates:
- Command pattern replaces complex conditional edges
- TypedDict state (v1.0+ requirement)
- Human-in-the-Loop via interrupt()
- Integrated MCP client via langchain-mcp-adapters
"""

from typing import Literal
from langgraph.graph import StateGraph, START, END
from langgraph.checkpoint.memory import MemorySaver
from langgraph.types import Command, interrupt
from langchain_core.messages import HumanMessage, AIMessage

from .state import AgentState


# ============================================================================
# NODE DEFINITIONS (Using Command Pattern)
# ============================================================================

def intent_classifier(state: AgentState) -> Command[Literal["local_retriever", "global_retriever", "both_retrievers"]]:
    """
    Classify user intent and route to appropriate retriever.

    Uses Command pattern instead of separate routing function.
    This simplifies the graph by co-locating routing logic with the node.
    """
    last_message = state["messages"][-1].content.lower()

    # Keywords indicating global knowledge search
    global_keywords = ["전사", "history", "과거", "다른 프로젝트", "패턴", "best practice"]
    local_keywords = ["이 파일", "이 함수", "현재", "여기", "수정", "고쳐"]

    needs_global = any(kw in last_message for kw in global_keywords)
    needs_local = any(kw in last_message for kw in local_keywords)

    # Determine intent and update state
    if needs_global and needs_local:
        intent = "HYBRID"
        next_node = "both_retrievers"
    elif needs_global:
        intent = "GLOBAL_QUERY"
        next_node = "global_retriever"
    else:
        intent = "LOCAL_FIX"
        next_node = "local_retriever"

    # Command allows both state update AND routing in one return
    return Command(
        goto=next_node,
        update={"intent": intent, "context_needs": [next_node]}
    )


def local_retriever(state: AgentState) -> Command[Literal["pruner"]]:
    """
    Retrieve context from local CodeGraph.
    Fast thinking - immediate local context.
    """
    # In real implementation, this would call MCP tools
    # Example: result = await codegraph_search(state["current_file"])

    docs = [
        f"[LOCAL] Function dependencies for: {state.get('current_file', 'unknown')}",
        "[LOCAL] No circular dependencies detected",
    ]

    return Command(
        goto="pruner",
        update={"retrieved_docs": state.get("retrieved_docs", []) + docs}
    )


def global_retriever(state: AgentState) -> Command[Literal["pruner"]]:
    """
    Retrieve context from global Neo4j knowledge graph.
    Slow thinking - cross-project patterns and history.

    Includes Human-in-the-Loop for write operations.
    """
    last_message = state["messages"][-1].content

    # Safety gate: Require approval for DB modifications
    if any(kw in last_message.upper() for kw in ["UPDATE", "DELETE", "CREATE", "MERGE"]):
        # This will pause execution and wait for human approval
        interrupt("⚠️ Global DB 변경 승인이 필요합니다. 계속하시겠습니까?")

    # In real implementation, this would call Neo4j MCP tools
    docs = [
        "[GLOBAL] Similar pattern found in 3 other projects",
        "[GLOBAL] Historical issue: Memory leak resolved with connection pooling",
    ]

    return Command(
        goto="pruner",
        update={"retrieved_docs": state.get("retrieved_docs", []) + docs}
    )


def both_retrievers(state: AgentState) -> Command[Literal["pruner"]]:
    """
    Fan-out to both local and global retrievers, then merge results.
    Used for hybrid queries that need both contexts.
    """
    # Local context
    local_docs = [
        f"[LOCAL] Dependencies for: {state.get('current_file', 'unknown')}",
    ]

    # Global context
    global_docs = [
        "[GLOBAL] Cross-project patterns retrieved",
    ]

    return Command(
        goto="pruner",
        update={"retrieved_docs": local_docs + global_docs}
    )


def pruner(state: AgentState) -> Command[Literal["synthesizer"]]:
    """
    Prune retrieved documents to prevent context overflow.

    Context Safeguard: Limits token usage by filtering low-relevance docs.
    """
    docs = state.get("retrieved_docs", [])

    # Simple pruning: keep most relevant (in real impl, use similarity scores)
    MAX_DOCS = 5
    pruned_docs = docs[:MAX_DOCS] if len(docs) > MAX_DOCS else docs

    return Command(
        goto="synthesizer",
        update={"retrieved_docs": pruned_docs}
    )


def synthesizer(state: AgentState) -> dict:
    """
    Synthesize final response from retrieved context.
    Terminal node - returns state update without Command.
    """
    intent = state.get("intent", "UNKNOWN")
    docs = state.get("retrieved_docs", [])

    # Build response
    context_summary = "\n".join(f"  - {doc}" for doc in docs)
    response = f"""Based on {intent} analysis:

Retrieved Context:
{context_summary}

[AI Response would be generated here using LLM with the above context]
"""

    return {
        "messages": state["messages"] + [AIMessage(content=response)]
    }


# ============================================================================
# GRAPH FACTORY
# ============================================================================

def create_omnigraph_agent(
    enable_checkpointing: bool = True,
    enable_human_in_loop: bool = True
) -> StateGraph:
    """
    Factory function to create the OmniGraph agent graph.

    Args:
        enable_checkpointing: Enable state persistence across invocations
        enable_human_in_loop: Enable interrupt() for sensitive operations

    Returns:
        Compiled LangGraph application
    """
    # Initialize Graph with typed state
    workflow = StateGraph(AgentState)

    # Add Nodes
    workflow.add_node("intent_classifier", intent_classifier)
    workflow.add_node("local_retriever", local_retriever)
    workflow.add_node("global_retriever", global_retriever)
    workflow.add_node("both_retrievers", both_retrievers)
    workflow.add_node("pruner", pruner)
    workflow.add_node("synthesizer", synthesizer)

    # Define Edges
    # With Command pattern, we only need to define entry point
    # Routing is handled by Command returns in each node
    workflow.add_edge(START, "intent_classifier")
    workflow.add_edge("synthesizer", END)

    # Compile with options
    compile_kwargs = {}

    if enable_checkpointing:
        compile_kwargs["checkpointer"] = MemorySaver()

    if enable_human_in_loop:
        # interrupt_before allows pausing before specific nodes
        compile_kwargs["interrupt_before"] = ["global_retriever"]

    return workflow.compile(**compile_kwargs)


# Default compiled app
app = create_omnigraph_agent(enable_checkpointing=False, enable_human_in_loop=False)


def run_query(query: str, thread_id: str = "default", current_file: str = None) -> dict:
    """
    Convenience function to run a query through the agent.

    Args:
        query: User's question or request
        thread_id: Session identifier for state persistence
        current_file: Optional file context for local analysis

    Returns:
        Final agent state with response
    """
    initial_state = {
        "messages": [HumanMessage(content=query)],
        "current_file": current_file,
        "retrieved_docs": [],
        "intent": None,
        "context_needs": []
    }

    config = {"configurable": {"thread_id": thread_id}}

    return app.invoke(initial_state, config)


if __name__ == "__main__":
    print("OmniGraph Agent Graph (v1.2 - Command Pattern)")
    print("=" * 50)

    # Test local query
    print("\n[Test 1] Local Query:")
    result = run_query(
        "이 함수를 수정하고 싶어요",
        current_file="src/utils.py"
    )
    print(f"  Intent: {result.get('intent')}")
    print(f"  Docs: {len(result.get('retrieved_docs', []))}")

    # Test global query
    print("\n[Test 2] Global Query:")
    result = run_query("전사에서 비슷한 패턴을 구현한 적 있나요?")
    print(f"  Intent: {result.get('intent')}")
    print(f"  Docs: {len(result.get('retrieved_docs', []))}")

    # Test hybrid query
    print("\n[Test 3] Hybrid Query:")
    result = run_query("이 함수의 history와 현재 의존성을 알려주세요")
    print(f"  Intent: {result.get('intent')}")
    print(f"  Docs: {len(result.get('retrieved_docs', []))}")
