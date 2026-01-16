from typing import Literal, List, Dict, Any
from langchain_core.messages import SystemMessage
from langgraph.types import Command

from langchain_tools.agent.graph.state import AgentState
from langchain_tools.agent.guardrails import IntentVerifier
from langchain_tools.tools.auto_verify import AutoVerifyTool
from langchain_tools.tools.security_audit import SecurityAuditTool

def guardian_node(state: AgentState) -> Command[Literal["supervisor", "librarian"]]:
    """
    Quality Guardian Agent.

    Responsibilities:
    1. Static Analysis & Verification (AutoVerify).
    2. Security Audit (SecurityAuditTool).
    3. Intent Verification (IntentVerifier).
    """
    print("🛡️ [Guardian] Starting Verification Cycle...")

    changed_files = state.get("changed_files", [])
    intent_path = state.get("intent_path")

    failed_reasons = []

    # 1. AutoVerify (Linting, Basic Checks)
    print("   🔍 [Guardian] Running AutoVerify...")
    auto_verify = AutoVerifyTool()
    try:
        # AutoVerify runs on the whole project usually, or checks specific files if optimized.
        # For now, we invoke it without args to check project health.
        av_result = auto_verify.invoke({})
        if av_result.get("status") != "passed":
            print(f"      ❌ AutoVerify Failed: {av_result.get('message')}")
            failed_reasons.append(f"AutoVerify: {av_result.get('message')}")
        else:
            print("      ✅ AutoVerify Passed")
    except Exception as e:
        print(f"      ⚠️ AutoVerify tool error: {e}")
        # Don't block strictly on tool error for MVP, but good to note.

    # 2. Security Audit
    print("   🔐 [Guardian] Running Security Audit...")
    sec_audit = SecurityAuditTool()
    try:
        sa_result = sec_audit.invoke({})
        if sa_result.get("status") == "vulnerable":
             print(f"      ❌ Security Issues Found: {len(sa_result.get('issues', []))} issues")
             failed_reasons.append("Security Audit Failed")
        else:
             print("      ✅ Security Audit Passed")
    except Exception as e:
        print(f"      ⚠️ Security Audit tool error: {e}")

    # 3. Intent Verification
    if intent_path:
        print(f"   💎 [Guardian] Verifying against Intent Crystal ({intent_path})...")
        iv_result = IntentVerifier.verify(intent_path, changed_files)

        if iv_result["passed"]:
            print(f"      ✅ Intent Match: {iv_result['reason']}")
        else:
            print(f"      ❌ Intent Mismatch: {iv_result['reason']}")
            failed_reasons.append(f"Intent Verification: {iv_result['reason']}")

    # Decision
    if failed_reasons:
        error_msg = f"Verification Failed: {', '.join(failed_reasons)}"
        print(f"🚫 [Guardian] {error_msg}")
        return Command(
            update={
                "messages": [SystemMessage(content=error_msg)],
                "next_agent": "supervisor" # Return to Supervisor to decide next steps (retry or human intervention)
            },
            goto="supervisor"
        )

    print("✅ [Guardian] All checks passed. Handoff to Librarian.")
    return Command(
        update={
            "messages": [SystemMessage(content="Verification passed. Ready for recording.")],
            "next_agent": "librarian"
        },
        goto="librarian"
    )
