import re
from typing import Optional, Dict, Any

class InputGuard:
    """
    사용자 입력에 대한 전처리 및 검증을 담당하는 가드레일.
    - PII (개인정보) 마스킹 (Mock)
    - Prompt Injection 탐지 (Mock)
    """

    @staticmethod
    def sanitize(input_text: str) -> str:
        """
        입력 텍스트를 정화합니다 (PII 마스킹 등).
        """
        # 간단한 이메일 마스킹 예시
        email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        sanitized = re.sub(email_pattern, '[EMAIL_REDACTED]', input_text)

        # 실제로는 LangChain PII 도구나 Presidio를 연동
        return sanitized

    @staticmethod
    def validate(input_text: str) -> bool:
        """
        입력이 안전한지 검증합니다 (Prompt Injection 등).
        """
        # 아주 단순한 차단 키워드 예시
        blacklist = ["ignore previous instructions", "system prompt"]
        for keyword in blacklist:
            if keyword in input_text.lower():
                return False
        return True

class IntentVerifier:
    """
    초기 의도(Intent)와 최종 결과물 간의 정합성을 검증하는 가드레일.
    """

    @staticmethod
    def capture_intent(user_request: str) -> str:
        """
        사용자 요청으로부터 의도 정의서(Crystal) 내용을 생성합니다.
        (실제로는 LLM 호출 필요)
        """
        return f"""# Intent Crystal

## Goal
{user_request}

## Success Criteria
- Implementation matches goal
- Security best practices followed
- Tests passed
"""

    @staticmethod
    def verify(intent_path: str, changed_files: list[str]) -> Dict[str, Any]:
        """
        Intent Crystal과 변경된 파일들을 비교 검증합니다.
        """
        try:
            with open(intent_path, "r") as f:
                intent_content = f.read()

            # TODO: 실제로는 LLM을 사용하여 intent_content와 file codes를 비교해야 함.
            # 지금은 파일이 존재하고 intent가 읽히면 통과로 가정하되,
            # 특정 키워드가 없는지 등을 체크하여 Mocking할 수 있음.

            return {
                "passed": True,
                "reason": "Intent matches implementation (Mock check passed).",
                "score": 100
            }
        except FileNotFoundError:
            return {
                "passed": False,
                "reason": "Intent file not found.",
                "score": 0
            }
        except Exception as e:
             return {
                "passed": False,
                "reason": f"Verification error: {str(e)}",
                "score": 0
            }
