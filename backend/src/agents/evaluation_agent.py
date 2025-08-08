from llama_index.core.agent.workflow import FunctionAgent
from llama_index.core.base.llms.base import BaseLLM
from src.agents.prompts import EVALUATION_PROMPT
from src.config.config import settings
from src.schemas.enums import AgentNames


def get_evaluation_agent(llm: BaseLLM):
    return FunctionAgent(
        name=AgentNames.EVALUATION_AGENT.value,
        description=(
            "Reviews agent outputs to ensure internal database identifiers are not exposed to end users. "
            "Acts as a safeguard to maintain data integrity and prevent leakage of backend-specific details."
        ),
        llm=llm,
        system_prompt=EVALUATION_PROMPT,
        tools=[],
        verbose=settings.VERBOSE,
        allow_parallel_tool_calls=False,
    )
