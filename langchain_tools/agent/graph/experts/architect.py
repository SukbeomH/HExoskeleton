from typing import Literal, Optional
from pathlib import Path
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.types import Command

from langchain_tools.agent.graph.state import AgentState
from langchain_tools.mcp.codanna_tool import CodannaMCPTool
from langchain_tools.mcp.shrimp_tool import ShrimpMCPTool

def architect_node(state: AgentState) -> Command[Literal["supervisor"]]:
    """
    Lead Architect Agent.

    Responsibilities:
    1. Read and understand INTENT.md.
    2. Analyze codebase using Codanna (Semantic Search).
    3. Register task in Shrimp Task Manager.
    4. Create detailed implementation plan (PLAN.md).
    """
    print("🏛️ [Architect] Starting Architectural Planning...")

    intent_path = state.get("intent_path")
    if not intent_path or not Path(intent_path).exists():
         return Command(
            update={"messages": [SystemMessage(content="Error: INTENT.md not found.")]},
            goto="supervisor"
        )

    with open(intent_path, "r") as f:
        intent_content = f.read()

    # 1. Analyze with Codanna
    print("   🔍 [Architect] Analyzing codebase with Codanna...")
    codanna = CodannaMCPTool()
    try:
        # Extract keywords for search (Mock: use first line of intent)
        query = intent_content.split('\n')[0].replace('#', '').strip()
        analysis_result = codanna.invoke({"query": query})
    except Exception as e:
        print(f"   ⚠️ Codanna analysis failed (or skipped): {e}")
        analysis_result = "Analysis unavailable (Tool error)."

    # 2. Register Task with Shrimp
    print("   🦐 [Architect] Registering task with Shrimp...")
    shrimp = ShrimpMCPTool()
    task_id = state.get("task_id")
    try:
        if not task_id:
            task_result = shrimp.invoke({
                "action": "create_task",
                "title": f"Implement: {query}",
                "description": f"Generated from Intent: {intent_path}"
            })
            if isinstance(task_result, dict) and "task_id" in task_result:
                task_id = task_result["task_id"]
                print(f"      -> Task Created: {task_id}")
            else:
                print(f"      -> Task Creation warning: {task_result}")
    except Exception as e:
        print(f"   ⚠️ Shrimp task creation failed (or skipped): {e}")
        # Continue without task_id if failed

    # 3. Generate Plan (LLM)
    print("   📝 [Architect] Drafting PLAN.md...")

    # Ideally use a real LLM here. For boilerplate, we'll try API, fallback to template.
    try:
        llm = ChatOpenAI(model="gpt-4o", temperature=0)
        prompt = f"""You are a Lead Software Architect.

User Intent:
{intent_content}

Code Analysis Context:
{analysis_result}

Create a detailed implementation plan in Markdown format (PLAN.md).
Include:
- Goal
- Files to Create/Modify
- Step-by-Step Implementation Guide
"""
        response = llm.invoke(prompt)
        plan_content = response.content
    except Exception as e:
        print(f"   ⚠️ LLM Generation failed: {e}. Using Template.")
        plan_content = f"""# Implementation Plan (Fallback)

## Goal
Based on: {intent_path}

## Proposed Changes
- [ ] Implement requested features
- [ ] Verify with tests

## Analysis
{analysis_result}
"""

    # 4. Write PLAN.md
    with open("PLAN.md", "w") as f:
        f.write(plan_content)

    print("   ✅ [Architect] PLAN.md created.")

    return Command(
        update={
            "messages": [SystemMessage(content=f"Plan created: PLAN.md (Task ID: {task_id})")],
            "plan_path": "PLAN.md",
            "task_id": task_id,
            "next_agent": "supervisor"
        },
        goto="supervisor"
    )
