from dataclasses import dataclass, field
from typing import Any, Optional

from src.trace_parser.enums import NodeLabel, NodeStatus


@dataclass
class Edge:
    """
    Class representing an edge in the trace
    """

    source: str
    target: str
    id: Optional[str] = ""

    def __post_init__(self):
        self.id = f"{self.source} - {self.target}"

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": str(self.id),
            "source": str(self.source),
            "target": str(self.target),
        }


@dataclass
class NodeData:
    label: NodeLabel = None
    input: Optional[str] = None
    output: Optional[str] = None
    reasoning: list[str] = field(default_factory=list)
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    time: Optional[float] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "label": self.label.value,
            "input": self.input,
            "output": self.output,
            "reasoning": self.reasoning,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "time": self.time,
        }


@dataclass
class Node:
    """
    Class representing a node in the trace
    """

    id: int
    data: NodeData
    level: int
    status: NodeStatus

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": str(self.id),
            "data": self.data.to_dict(),
            "level": str(self.level),
            "status": self.status.value,
        }
