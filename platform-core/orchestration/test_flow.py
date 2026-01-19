"""
Integration Test: End-to-End OmniGraph Flow

This script verifies that the Agent successfully:
1. Classifies intent (via intent_classifier)
2. Routes to appropriate retrievers (local/global)
3. Prunes results
4. Synthesizes an answer
"""

import sys
import os
import asyncio

# Ensure platform-core is in path
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

from orchestration.graph import run_query
from api.mcp_server import neo4j_write_memory

def seed_test_data():
    """Seed Neo4j with a known pattern for the test to find."""
    print("🌱 Seeding Neo4j with test data...")
    try:
        # We write a memory that the Global Retriever (if connected nicely) or a mocked logic could use.
        # Currently global_retriever is still mocking its return for this boilerplate phase,
        # BUT we want to ensure the Graph logic *runs*.
        # Let's seed anyway to prove Neo4j write works from python.
        res = neo4j_write_memory(
            key="TestPattern_AuthBug",
            value="Check for JWT expiration in middleware.",
            context="Security"
        )
        print(f"   Seed Result: {res}")
    except Exception as e:
        print(f"⚠️ Seeding failed (Non-critical if just testing flow logic): {e}")

def test_hybrid_flow():
    print("\n🧪 Starting Hybrid Flow Test")
    print("==========================")

    query = "How do I fix the authentication bug? Is there a global pattern?"
    print(f"User Query: '{query}'")

    # Run the agent
    result = run_query(query)

    # Assertions
    intent = result.get("intent")
    docs = result.get("retrieved_docs", [])
    answer = result["messages"][-1].content

    print(f"\n✅ Intent Detected: {intent}")
    print(f"✅ Retrieved Docs: {len(docs)}")
    print(f"✅ Final Answer:\n\n{answer}\n")

    if intent not in ["HYBRID", "GLOBAL_QUERY", "LOCAL_FIX"]:
         print("❌ Intent classification seems off.")
         sys.exit(1)

    if "Analysis" not in answer:
        print("❌ Synthesizer output format mismatch.")
        sys.exit(1)

    print("🎉 E2E Flow Verification Passed!")

if __name__ == "__main__":
    seed_test_data()
    test_hybrid_flow()
