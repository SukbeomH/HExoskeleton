import os
import sys
from dotenv import load_dotenv

# Load env from .env file
load_dotenv()

from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage
from langgraph.prebuilt import create_react_agent
from tools import get_tools

def get_llm():
    """Initialize LLM based on environment variables."""
    openai_key = os.getenv("OPENAI_API_KEY")
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")

    if openai_key:
        print("🤖 Using OpenAI (GPT-4o)")
        return ChatOpenAI(model="gpt-4o", temperature=0)
    elif anthropic_key:
        print("🤖 Using Anthropic (Claude 3.5 Sonnet)")
        return ChatAnthropic(model="claude-3-5-sonnet-20240620", temperature=0)
    else:
        print("❌ No API Key found. Please set OPENAI_API_KEY or ANTHROPIC_API_KEY in .env")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python agent.py \"Your task description\"")
        sys.exit(1)

    task = sys.argv[1]
    print(f"🚀 Starting Agent Task: {task}")

    # Initialize
    model = get_llm()
    tools = get_tools()

    # Create Agent
    graph = create_react_agent(model, tools)

    # Run
    print("⏳ Thinking...")
    try:
        events = graph.stream(
            {"messages": [HumanMessage(content=task)]},
            stream_mode="values"
        )

        for event in events:
            if "messages" in event:
                last_msg = event["messages"][-1]
                # Simple Logging
                if last_msg.type == "ai":
                    # Check if it has tool calls
                    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
                        for tc in last_msg.tool_calls:
                            print(f"🛠️  Calling Tool: {tc['name']}")
                    else:
                        print(f"💡 Agent: {last_msg.content}")
                elif last_msg.type == "tool":
                    print(f"✅ Tool Output: {last_msg.content[:200]}...") # Truncate long output

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("Tip: Check if Docker is running and MCP containers are accessible.")

if __name__ == "__main__":
    main()
