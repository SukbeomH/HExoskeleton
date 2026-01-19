"""
OmniGraph LangGraph Orchestration (Updated)

Hybrid RAG Agent with Local (CodeGraph) + Global (Neo4j) thinking.
Includes Pruning step.
"""

from langgraph.graph import StateGraph, START, END
from langgraph.checkpoint.memory import MemorySaver

from .state import AgentState
from .nodes.intent_classifier import intent_classifier, route_intent
from .nodes.local_retriever import local_retriever
from .nodes.global_retriever import global_retriever
from .nodes.pruner import pruner  # New Node
from .nodes.synthesizer import synthesizer

def create_omnigraph_agent(enable_checkpointing: bool = True):
    """
    Factory function to create the OmniGraph agent graph.
    """
    # Initialize Graph
    workflow = StateGraph(AgentState)

    # Add Nodes
    workflow.add_node("intent_classifier", intent_classifier)
    workflow.add_node("local_retriever", local_retriever)
    workflow.add_node("global_retriever", global_retriever)
    workflow.add_node("pruner", pruner)  # Add Pruner
    workflow.add_node("synthesizer", synthesizer)

    # Define Edges
    workflow.add_edge(START, "intent_classifier")

    # Conditional Routing based on intent
    workflow.add_conditional_edges(
        "intent_classifier",
        route_intent,
        {
            "local_retriever": "local_retriever",
            "global_retriever": "global_retriever",
        }
    )

    # Connect retrievers to Pruner (instead of Synthesizer directly)
    workflow.add_edge("local_retriever", "pruner")
    workflow.add_edge("global_retriever", "pruner")

    # Connect Pruner to Synthesizer
    workflow.add_edge("pruner", "synthesizer")

    # End after synthesis
    workflow.add_edge("synthesizer", END)

    # Compile with optional checkpointing
    if enable_checkpointing:
        checkpointer = MemorySaver()
        app = workflow.compile(checkpointer=checkpointer)
    else:
        app = workflow.compile()

    return app

# Default compiled app
app = create_omnigraph_agent(enable_checkpointing=False)

def run_query(query: str, thread_id: str = "default") -> dict:
    """
    Convenience function to run a query through the agent.
    """
    from langchain_core.messages import HumanMessage

    initial_state = {
        "messages": [HumanMessage(content=query)],
        "current_file": None,
        "retrieved_docs": [],
        "intent": None,
        "context_needs": []
    }

    config = {"configurable": {"thread_id": thread_id}}

    result = app.invoke(initial_state, config)
    return result

if __name__ == "__main__":
    print("OmniGraph Agent Graph (Updated with Pruner)")
    print("=" * 40)

    # Test run
    result = run_query("How do I fix the authentication bug?")

    print(f"Intent: {result.get('intent')}")
    print(f"Retrieved Docs: {len(result.get('retrieved_docs', []))}")
    print(f"Final Message: {result['messages'][-1].content[:200]}...")
