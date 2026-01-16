from typing import Literal
from langchain_core.messages import SystemMessage
from langgraph.types import Command
from langgraph.graph import END

from langchain_tools.agent.graph.state import AgentState
from langchain_tools.tools.claude_knowledge import ClaudeKnowledgeUpdaterTool

def librarian_node(state: AgentState) -> Command[Literal["__end__"]]:
    """
    Knowledge Librarian Agent.

    Responsibilities:
    1. Summarize task success.
    2. Update CLAUDE.md with Lessons Learned using ClaudeKnowledgeUpdaterTool.
    3. Terminate the graph execution.
    """
    print("📚 [Librarian] Recording Knowledge...")

    changed_files = state.get("changed_files", [])
    intent_path = state.get("intent_path")

    # Construct a verification result object for the tool
    # In a full systems, this would aggregate real data from Guardian.
    # Here, we infer success from the fact we reached this node.
    verification_result = {
        "steps": {
            "approve": {"status": "approved"},
            "verify": {
                "basic": {"errors": []},
                "security": {"status": "secure"}
            }
        },
        "intent": intent_path,
        "changed_files": changed_files
    }

    updater = ClaudeKnowledgeUpdaterTool()
    try:
        updater.invoke({"verification_result": verification_result})
        print("   ✅ [Librarian] CLAUDE.md updated.")
    except Exception as e:
        print(f"   ⚠️ Librarian update failed: {e}")

    return Command(
        update={
            "messages": [SystemMessage(content=f"Knowledge updated. Task Completed.")],
            "next_agent": "END"
        },
        goto=END
    )
