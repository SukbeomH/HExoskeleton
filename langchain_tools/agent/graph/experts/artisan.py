from typing import Literal, Optional, List
from pathlib import Path
from langchain_core.messages import SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.types import Command

from langchain_tools.agent.graph.state import AgentState
from langchain_tools.mcp.serena_tool import SerenaMCPTool

def artisan_node(state: AgentState) -> Command[Literal["supervisor", "guardian"]]:
    """
    Code Artisan Agent.

    Responsibilities:
    1. Read PLAN.md.
    2. Implement changes using native I/O (for new files) or Serena (for edits).
    3. Update state with changed_files list.
    """
    print("🔨 [Artisan] Starting Implementation...")

    plan_path = state.get("plan_path")
    if not plan_path or not Path(plan_path).exists():
         return Command(
            update={"messages": [SystemMessage(content="Error: PLAN.md not found.")]},
            goto="supervisor"
        )

    with open(plan_path, "r") as f:
        plan_content = f.read()

    # Mock Implementation Logic:
    # In a real scenario, we would parse PLAN.md items and execute them one by one.
    # Here, we will simulate creating the file mentioned in the Supervisor verification step (e.g. src/main.py)
    # or infer from INTENT.

    changed_files = []

    # 1. Analyze PLAN to decide what to do
    # For Mock/Demo purpose, we assume we need to create/update 'src/main.py' or whatever is in the plan.
    # Let's try to extract filenames from PLAN.md (naive implementation)
    # Or just default to a dummy file if none found.

    target_file = "src/main.py"

    # Create directory if needed
    Path("src").mkdir(exist_ok=True)

    print(f"   ⚙️ [Artisan] Implementing features in {target_file}...")

    # Check if file exists to decide between Create (I/O) or Edit (Serena)
    file_exists = Path(target_file).exists()

    if file_exists:
        # Try to use Serena for "Refactoring" or "Editing"
        print("   💅 [Artisan] Using Serena to edit existing code...")
        serena = SerenaMCPTool()
        try:
            # Mock: Try to search for a symbol 'main' and edit it, or just append.
            # Since we don't know the symbol, this is tricky without LLM parsing.
            # We'll stick to a simple strategy: If we can identify a class/def, use Serena.
            # Otherwise fallback to overwrite/append.

            # For this MVP, let's assume we overwrite/update via I/O for stability,
            # but call Serena just to show we can.

            # Check if 'main' function exists
            search_res = serena.invoke({"action": "search_symbol", "symbol": "main"})
            if search_res.get("status") == "success" and search_res.get("result"):
                print("      -> Symbol 'main' found. Editing...")
                # serena.invoke({"action": "edit_symbol", "symbol": "main", "new_content": "..."})
            else:
                print("      -> Symbol 'main' not found.")
        except Exception as e:
             print(f"   ⚠️ Serena tool failed: {e}")

    # 2. Generate Code (LLM)
    # Mock generation
    code_content = f"""# Implemented based on {plan_path}
def main():
    print("Hello from Agentic MoE!")
    # Feature: Login (Mock)
    print("Login Page Loaded")

if __name__ == "__main__":
    main()
"""

    # 3. Apply Changes (Native I/O for reliability in MVP)
    with open(target_file, "w") as f:
        f.write(code_content)

    changed_files.append(target_file)
    print(f"   ✅ [Artisan] File updated: {target_file}")

    return Command(
        update={
            "messages": [SystemMessage(content=f"Code implemented: {', '.join(changed_files)}")],
            "changed_files": changed_files,
            "next_agent": "guardian"
        },
        goto="guardian"
    )
