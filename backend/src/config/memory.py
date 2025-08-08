from mem0 import AsyncMemory
from src.config.config import settings


def get_mem0_memory() -> AsyncMemory:
    return AsyncMemory(config=settings.get_mem0_memory_config())
