from typing import TypedDict, Annotated, List, Optional
from langchain_core.messages import BaseMessage, AnyMessage
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    """
    Agentic MoE를 위한 Shared State 정의.
    Context Offloading 전략에 따라 무거운 데이터는 외부 참조로 저장합니다.
    """
    # 대화 내역 (Stateless Handoff를 위해 각 단계마다 초기화되거나 필요한 것만 유지)
    messages: Annotated[List[AnyMessage], add_messages]

    # --- Context Offloading (Pass-by-Reference) ---

    # 현재 작업 ID (Shrimp Task Manager)
    task_id: Optional[str]

    # Intent Crystal 경로 (불변)
    intent_path: Optional[str]

    # 현재 계획/명세서 경로
    plan_path: Optional[str]

    # 변경된 파일 목록 (검증 대상)
    changed_files: List[str]

    # --- Routing Control ---

    # 다음 실행할 전문가 이름
    next_agent: Optional[str]

    # 에러 발생 시 재시도 횟수
    retry_count: int
