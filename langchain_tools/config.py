"""LangChain Tools 설정 모듈.

환경 변수를 통한 설정 관리를 제공합니다.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Literal, Dict


@dataclass
class AgentModelConfig:
    """개별 에이전트 모델 설정."""

    agent_name: str
    provider: Literal["openai", "anthropic", "google"]
    model_name: str
    temperature: float = 0.0
    max_tokens: int | None = None


@dataclass
class LangChainToolsConfig:
    """LangChain Tools 전역 설정.

    환경 변수:
        LANGCHAIN_MODEL: 전체 모델 문자열 (예: "openai:gpt-4o")
        LANGCHAIN_PROVIDER: LLM 제공자 (openai, anthropic, google)
        LANGCHAIN_MODEL_NAME: 모델 이름
        LANGCHAIN_TOOLS_LOG_LEVEL: 로그 레벨 (DEBUG, INFO, WARNING, ERROR)
        LANGCHAIN_TOOLS_TIMEOUT: 도구 실행 타임아웃 (초)
    """

    # 기본 LLM 설정 (레거시 호환성)
    provider: Literal["openai", "anthropic", "google"] = field(
        default_factory=lambda: os.getenv("LANGCHAIN_PROVIDER", "openai")  # type: ignore
    )
    model_name: str | None = field(
        default_factory=lambda: os.getenv("LANGCHAIN_MODEL_NAME")
    )
    full_model: str | None = field(
        default_factory=lambda: os.getenv("LANGCHAIN_MODEL")
    )

    # 도구 설정
    log_level: str = field(
        default_factory=lambda: os.getenv("LANGCHAIN_TOOLS_LOG_LEVEL", "INFO")
    )
    timeout: int = field(
        default_factory=lambda: int(os.getenv("LANGCHAIN_TOOLS_TIMEOUT", "120"))
    )

    # 검증 설정
    max_tool_retries: int = field(
        default_factory=lambda: int(os.getenv("LANGCHAIN_TOOLS_MAX_RETRIES", "2"))
    )

    # 에이전트별 모델 설정 (비용 최적화)
    agent_models: Dict[str, AgentModelConfig] = field(default_factory=lambda: {
        "architect": AgentModelConfig(
            agent_name="architect",
            provider="anthropic",
            model_name="claude-3-5-sonnet-20241022",  # Medium: 계획 수립
            temperature=0.1
        ),
        "artisan": AgentModelConfig(
            agent_name="artisan",
            provider="openai",
            model_name="gpt-4o",  # Medium: 코드 구현
            temperature=0.0
        ),
        "guardian": AgentModelConfig(
            agent_name="guardian",
            provider="openai",
            model_name="gpt-4o",  # Medium: 검증
            temperature=0.0
        ),
        "librarian": AgentModelConfig(
            agent_name="librarian",
            provider="google",
            model_name="gemini-2.0-flash-exp",  # Cheap: 문서화
            temperature=0.3
        ),
        "community_manager": AgentModelConfig(
            agent_name="community_manager",
            provider="google",
            model_name="gemini-2.0-flash-exp",  # Cheap: 이슈 트리아지
            temperature=0.2
        ),
        "supervisor": AgentModelConfig(
            agent_name="supervisor",
            provider="openai",
            model_name="gpt-4o-mini",  # Cheap: 라우팅
            temperature=0.0
        )
    })

    def get_model_string(self) -> str:
        """설정된 모델 문자열을 반환합니다 (레거시 호환성)."""
        if self.full_model:
            return self.full_model

        if self.model_name:
            return f"{self.provider}:{self.model_name}"

        # 제공자별 기본 모델
        default_models = {
            "openai": "gpt-4o",
            "anthropic": "claude-3-5-sonnet-20241022",
            "google": "gemini-2.0-flash-exp",
        }

        return f"{self.provider}:{default_models.get(self.provider, 'gpt-4o')}"

    def get_llm(self, agent_name: str):
        """에이전트별 설정된 LLM을 반환합니다.

        Args:
            agent_name: 에이전트 이름 (architect, artisan, guardian, librarian 등)

        Returns:
            설정된 LLM 인스턴스
        """
        agent_config = self.agent_models.get(agent_name)

        if not agent_config:
            # 폴백: 기본 모델 사용
            from langchain_openai import ChatOpenAI
            return ChatOpenAI(model="gpt-4o", temperature=0)

        # 프로바이더별 LLM 생성
        if agent_config.provider == "openai":
            from langchain_openai import ChatOpenAI
            return ChatOpenAI(
                model=agent_config.model_name,
                temperature=agent_config.temperature,
                max_tokens=agent_config.max_tokens
            )
        elif agent_config.provider == "anthropic":
            from langchain_anthropic import ChatAnthropic
            return ChatAnthropic(
                model=agent_config.model_name,
                temperature=agent_config.temperature,
                max_tokens=agent_config.max_tokens
            )
        elif agent_config.provider == "google":
            from langchain_google_genai import ChatGoogleGenerativeAI
            return ChatGoogleGenerativeAI(
                model=agent_config.model_name,
                temperature=agent_config.temperature,
                max_tokens=agent_config.max_tokens
            )
        else:
            # 예상치 못한 프로바이더
            from langchain_openai import ChatOpenAI
            return ChatOpenAI(model="gpt-4o", temperature=0)


# 전역 설정 인스턴스
config = LangChainToolsConfig()
