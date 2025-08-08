from llama_index.core.agent.workflow import FunctionAgent
from src.agents.prompts import PLANNING_AGENT_PROMPT
from src.config.config import settings
from src.schemas.enums import AgentNames


def get_planning_agent(llm):
    return FunctionAgent(
        name=AgentNames.PLANNING_AGENT.value,
        description=(
            "Evaluates the user profile and query to decide which specialized agents should be activated for personalizing"
            " the product detail page."
        ),
        llm=llm,
        system_prompt=PLANNING_AGENT_PROMPT,
        tools=[],
        allow_parallel_tool_calls=False,
        verbose=settings.VERBOSE,
    )
