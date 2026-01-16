from typing import List
from langchain_core.messages import BaseMessage, SystemMessage, HumanMessage, AIMessage

class ContextCompressor:
    """
    컨텍스트 윈도우 최적화를 위한 메시지 압축기.
    "Write, Select, Compress, Isolate" 전략 중 'Compress'를 담당.
    """

    TOKEN_THRESHOLD = 50  # 테스트용으로 매우 낮게 설정 (실제는 4000~8000 등)

    @staticmethod
    def compress_messages(messages: List[BaseMessage]) -> List[BaseMessage]:
        """
        메시지 리스트가 임계값을 초과하면 요약합니다.
        (Mock Logic: 오래된 메시지를 하나의 요약 메시지로 대체)
        """
        # 아주 단순한 길이 체크 (실제는 토큰 계산 필요)
        total_len = sum(len(m.content) for m in messages)

        if total_len < ContextCompressor.TOKEN_THRESHOLD:
            return messages

        print(f"📉 [Compressor] Context length ({total_len}) exceeds threshold. Compressing...")

        # 최신 2개 메시지는 유지 (Recency Bias 활용)
        if len(messages) <= 2:
            return messages

        recent_msgs = messages[-2:]
        older_msgs = messages[:-2]

        # 오래된 메시지들을 하나로 요약 (Mock)
        summary = f"Previous conversation summary: User requested {older_msgs[0].content}..."
        print(f"📉 [Compressor] Compressed {len(older_msgs)} messages into summary.")

        return [SystemMessage(content=summary)] + recent_msgs
