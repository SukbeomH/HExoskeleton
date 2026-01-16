from typing import Literal, Dict, Any, List
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command

from langchain_tools.agent.graph.state import AgentState
from langchain_tools.agent.guardrails import InputGuard, IntentVerifier
from langchain_tools.agent.context import ContextCompressor

# --- Mock Experts (Stubs for Phase 8.1) ---

from langchain_tools.agent.graph.experts.architect import architect_node
from langchain_tools.agent.graph.experts.artisan import artisan_node
from langchain_tools.agent.graph.experts.guardian import guardian_node



from langchain_tools.agent.graph.experts.librarian import librarian_node

# --- Supervisor (Router) ---

def supervisor_node(state: AgentState) -> Command[Literal["architect", "artisan", "guardian", "librarian", "__end__", "supervisor"]]:
    """
    Supervisor: Analyzes user input and routes to the appropriate expert.
    Uses state markers, Guardrails, and Context Optimization.
    """
    print("🤖 [Supervisor] Routing...")

    # --- Context Optimization (Start) ---
    # Check if context needs compression
    original_msgs = state.get("messages", [])
    compressed_msgs = ContextCompressor.compress_messages(original_msgs)

    if len(compressed_msgs) != len(original_msgs):
        # If compressed, we would ideally update state.
        # However, due to 'add_messages' reducer, simply returning update will append, causing infinite loop.
        # For Phase 8.1 Mock, we just log it and proceed.
        print("📉 [Supervisor] Context compressed (State update skipped to prevent append-loop).")
        # To truly overwrite, we need to use RemoveMessage or custom reducer, which is out of scope for now.


    # --- Input Guardrail ---
    if state["messages"]:
        last_user_msg = state["messages"][-1].content
        if not InputGuard.validate(last_user_msg):
            print("🚫 [Supervisor] Unsafe input detected by Guardrails.")
            return Command(goto=END)

    # Check termination
    last_msg = state["messages"][-1].content if state["messages"] else ""
    if "Knowledge updated" in last_msg:
         return Command(goto=END)

    # --- Intent Capture (Start) ---
    if not state.get("intent_path"):
        print("💎 [Supervisor] Capturing Initial Intent...")
        user_req = state["messages"][-1].content
        intent_content = IntentVerifier.capture_intent(user_req)

        with open("INTENT.md", "w") as f:
            f.write(intent_content)

        print("💎 [Supervisor] Created INTENT.md")
        return Command(
            update={"intent_path": "INTENT.md"},
            goto="architect"
        )

    # 1. State-based Routing (Priority)

    # If Plan exists but no code yet -> Artisan
    if state.get("plan_path") and not state.get("changed_files") and not "Code implemented" in last_msg:
        return Command(goto="artisan")

    # If Code exists -> Guardian (Handoff usually handles this, but as backup)
    if state.get("changed_files") and "Verification passed" not in last_msg:
         return Command(goto="guardian")

    # 2. Intent-based Routing (Initial)

    low_msg = last_msg.lower()
    if "plan" in low_msg or "design" in low_msg:
        if not state.get("plan_path"):
            return Command(goto="architect")

    elif "code" in low_msg or "implement" in low_msg:
        return Command(goto="artisan")

    elif "verify" in low_msg or "test" in low_msg:
        return Command(goto="guardian")

    elif "finish" in low_msg or "record" in low_msg:
        return Command(goto="librarian")

    return Command(goto=END)

# --- Graph Assembly ---

def create_agent_graph():
    workflow = StateGraph(AgentState)

    # Add Nodes
    workflow.add_node("supervisor", supervisor_node)
    workflow.add_node("architect", architect_node)
    workflow.add_node("artisan", artisan_node)
    workflow.add_node("guardian", guardian_node)
    workflow.add_node("librarian", librarian_node)

    # Add Edges
    workflow.add_edge(START, "supervisor")

    # Compile
    # Compile
    return workflow.compile()

# Expose the compiled graph for LangGraph Studio / Server
agent_graph = create_agent_graph()
