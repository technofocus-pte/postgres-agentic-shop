import json

from pandas import DataFrame
from src.schemas.enums import AgentNames
from src.trace_parser.base import BaseParser
from src.trace_parser.enums import NodeLabel, NodeStatus


class SearchTraceParser(BaseParser):
    def __init__(self, spans: DataFrame, **kwargs):
        super().__init__(spans, **kwargs)

    def parse(
        self,
        add_tool_placeholder: bool = True,
        generate_edges: bool = True,
    ) -> dict:
        tools_to_label_mapping = self._get_tools_to_label_mapping()
        tools_not_called = list(tools_to_label_mapping.values())
        current_level = 0

        df = self.spans

        user_query_info = self._extract_user_query_agent_info(df)
        if user_query_info:
            self._add_user_query_agent_node(user_query_info, current_level)
            current_level += 1

        self._add_tool_nodes(
            df,
            tools_to_label_mapping,
            tools_not_called,
            current_level,
        )
        current_level += len(tools_to_label_mapping) - len(tools_not_called)

        if add_tool_placeholder:
            self._add_tool_placeholders(tools_not_called, current_level)
            current_level += len(tools_not_called)

        self._assign_level_to_agents()
        if generate_edges:
            self._generate_edges()

        return {
            "nodes": [node.to_dict() for node in self.nodes],
            "edges": [edge.to_dict() for edge in self.edges],
        }

    def _get_tools_to_label_mapping(self):
        return {
            "query_reviews_with_sentiment": NodeLabel.QUERY_REVIEWS_WITH_SENTIMENTS,
            "search_products": NodeLabel.SEARCH_PRODUCTS,
            "query_about_product": NodeLabel.QUERY_ABOUT_PRODUCT,
        }

    def _extract_user_query_agent_info(self, df):
        workflow_run_rows = df[
            (df["name"] == "Workflow.run") & (df["parent_id"].isnull())
        ]
        for _, row in workflow_run_rows.iterrows():
            output_json = self._safe_json_load(row.get("attributes.output.value"))
            if not output_json:
                continue
            if (
                output_json.get("current_agent_name", "")
                != AgentNames.USER_QUERY_AGENT.value
            ):
                continue
            input_json = self._safe_json_load(row.get("attributes.input.value"))
            user_msg = (
                input_json.get("kwargs", {}).get("user_msg", "") if input_json else ""
            )
            tool_calls = output_json.get("tool_calls", [])
            tool_used = tool_calls[0].get("tool_name", "") if tool_calls else ""
            exec_time, start_time, end_time = self._get_user_query_agent_execution_time(
                df,
            )
            if user_msg and tool_used and exec_time is not None:
                return {
                    "input": user_msg,
                    "tool_used": tool_used,
                    "execution_time": exec_time,
                    "start_time": start_time,
                    "end_time": end_time,
                }
        return None

    def _get_user_query_agent_execution_time(self, df):
        agent_step_rows = df[df["name"] == "AgentWorkflow.run_agent_step"]
        for _, row in agent_step_rows.iterrows():
            start_time = row["start_time"]
            end_time = row["end_time"]
            exec_time = (end_time - start_time).total_seconds()
            output_json = self._safe_json_load(row.get("attributes.output.value"))
            if (
                output_json
                and output_json.get("current_agent_name", "")
                == AgentNames.USER_QUERY_AGENT.value
            ):
                return exec_time, start_time, end_time
        return None, None, None

    def _add_user_query_agent_node(self, info, level):
        self._add_node(
            label=NodeLabel.USER_QUERY_AGENT,
            input=info["input"],
            output=info["tool_used"],
            reasoning=[],
            start_time=info["start_time"],
            end_time=info["end_time"],
            time=info["execution_time"],
            level=level,
            status=NodeStatus.triggered,
        )

    def _add_tool_nodes(
        self,
        df,
        tools_to_label_mapping,
        tools_not_called,
        start_level,
    ):
        tool_rows = df[df["name"] == "FunctionTool.acall"]
        level = start_level
        for _, row in tool_rows.iterrows():
            output_json = self._safe_json_load(row.get("attributes.output.value"))
            if not output_json:
                continue
            tool_called = output_json.get("tool_name", "")
            if tool_called not in tools_to_label_mapping:
                continue
            input_json = self._safe_json_load(row.get("attributes.input.value"))
            input_args = input_json.get("kwargs", {}) if input_json else {}
            input_args_str = json.dumps(input_args, indent=4, ensure_ascii=False)
            start_time = row["start_time"]
            end_time = row["end_time"]
            duration = (end_time - start_time).total_seconds()
            self._add_node(
                label=tools_to_label_mapping[tool_called],
                input=input_args_str,
                output=None,
                reasoning=[],
                start_time=start_time,
                end_time=end_time,
                time=duration,
                level=level,
                status=NodeStatus.triggered,
            )
            level += 1
            if tools_to_label_mapping[tool_called] in tools_not_called:
                tools_not_called.remove(tools_to_label_mapping[tool_called])

    def _add_tool_placeholders(self, tools_not_called, start_level):
        level = start_level
        for tool in tools_not_called:
            self._add_placeholder_node(label=tool, level=level)
            level += 1

    def _safe_json_load(self, val):
        if not val:
            return {}
        try:
            return json.loads(val)
        except Exception:
            return {}
