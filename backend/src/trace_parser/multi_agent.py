import json

from pandas import DataFrame
from src.logging import logger
from src.trace_parser.base import BaseParser
from src.trace_parser.enums import NodeLabel
from src.utils.utils import extract_json_blocks, print_pretty_with_embedded_json


class MultiAgentParser(BaseParser):

    AGENT_LABELS: dict[str, str] = {
        "MultiAgentFlow.planning": NodeLabel.PLANNING_AGENT,
        "MultiAgentFlow.inventory_analysis": NodeLabel.INVENTORY_AGENT,
        "MultiAgentFlow.personalize_product": NodeLabel.PRODUCT_PERSONALIZATION_AGENT,
        "MultiAgentFlow.review": NodeLabel.REVIEW_AGENT,
        "MultiAgentFlow.evaluate_output": NodeLabel.EVALUATION_AGENT,
        "MultiAgentFlow.presentation": NodeLabel.PRESENTATION_AGENT,
    }

    def __init__(self, spans: DataFrame, search_trace_parser: BaseParser):
        self.search_trace_parser = search_trace_parser
        super().__init__(spans)

    def parse(self):
        """
        Parses trace data into a graph structure for visualization.
        Returns:
            dict: A dictionary with:
                - "nodes": List of extracted spans with metadata for visualization.
                - "edges": List of edges representing execution flow between nodes.
                - "user_query_agent_flow": Whether user query agent flow exists.
        """
        current_level = 0
        self._parse_search_trace()
        user_query_agent_flow = bool(self.nodes)
        if self.nodes:
            self._id_counter = self.nodes[-1].id
            current_level = self.nodes[-1].level

        df = self.spans
        workflow_run_rows = self._get_workflow_run_rows(df)
        for _, row in workflow_run_rows.iterrows():
            parent_agent_name = self._get_parent_agent_name(df, row)
            agent_init_row = self._get_agent_init_row(df, row)
            if parent_agent_name not in self.AGENT_LABELS:
                continue
            try:
                input_msg = self._extract_input(agent_init_row)
                output_msg = self._extract_output(row)
                reasoning, output_msg = self._extract_reasoning(output_msg)
            except Exception as e:
                logger.exception(e)
                continue

            self._add_node(
                self.AGENT_LABELS.get(parent_agent_name),
                input_msg,
                output_msg,
                reasoning,
                row["start_time"],
                row["end_time"],
                (row["end_time"] - row["start_time"]).total_seconds(),
                current_level,
                self._get_node_status(row.get("status_message", "")),
            )
            self.agent_already_parsed.append(self.AGENT_LABELS.get(parent_agent_name))

        current_level, parallel_agents_level = self._assign_level_to_agents()
        self._add_missing_parallel_agents_nodes(parallel_agents_level)
        self._add_workflow_complete_node(current_level, user_query_agent_flow)
        self._reorder_parallel_nodes()
        self._generate_edges()

        return {
            "nodes": [node.to_dict() for node in self.nodes],
            "edges": [edge.to_dict() for edge in self.edges],
            "user_query_agent_flow": user_query_agent_flow,
        }

    def _parse_search_trace(self):
        self.search_trace_parser.parse(add_tool_placeholder=False, generate_edges=False)
        self.nodes = self.search_trace_parser.nodes

    def _get_workflow_run_rows(self, df):
        return df[
            (df["name"] == "FunctionAgent.run")
            & (df["attributes.output.value"].notnull())
            & (df["attributes.input.value"].notnull())
        ]

    def _get_agent_init_row(self, df, parent_node):
        """
        Extracts the agent initialization rows based on the workflow run row.
        This node contains the input of the agent.
        """
        return df[
            (df["name"] == "FunctionAgent.init_run")
            & (df["parent_id"] == parent_node["context.span_id"])
        ]

    def _get_parent_agent_name(self, df, row):
        parent_agent_id = row["parent_id"]
        if parent_agent_id in df["context.span_id"].values:
            return df.loc[df["context.span_id"] == parent_agent_id, "name"].values[0]
        return None

    def _extract_input(self, row):
        inputs = self._safe_json_load(row["attributes.output.value"].item())
        input_msg = (
            inputs.get("input", [])[0].get("blocks", [])[0].get("text")
            if inputs
            else ""
        )
        input_msg = print_pretty_with_embedded_json(input_msg)
        return input_msg

    def _extract_output(self, row):
        outputs = json.loads(row["attributes.output.value"])
        output_msg = outputs.get("response", {}).get("blocks", [{}])[0].get("text", "")
        output_msg = print_pretty_with_embedded_json(output_msg)
        json_block = extract_json_blocks(output_msg)
        if json_block:
            output_msg = json_block[0]
        return output_msg

    def _extract_reasoning(self, output_msg):
        reasoning = []
        try:
            parsed_output = json.loads(output_msg)
            if isinstance(parsed_output, dict) and "reasoning" in parsed_output:
                reasoning = parsed_output.pop("reasoning")
                output_msg = json.dumps(
                    parsed_output,
                    indent=4,
                    ensure_ascii=False,
                )
        except Exception:
            pass
        return reasoning, output_msg

    def _add_workflow_complete_node(
        self,
        current_level: int,
        user_query_agent_flow: bool = False,
    ) -> list[dict]:

        wf_spans = [
            span_id
            for span_id, span_name in self.spans["name"].items()
            if (
                span_name.startswith("MultiAgentFlow.run")
                or span_name.startswith("FunctionAgent.run.")
            )
            and self.spans["parent_id"].get(span_id) is None
        ]

        if user_query_agent_flow:
            wf_spans = [
                self.spans["parent_id"][span_id]
                for span_id, span_name in self.spans["name"].items()
                if span_name == "MultiAgentFlow.planning"
            ]

        if wf_spans:
            wf_span_id = wf_spans[0]
            wf_start = self.spans["start_time"][wf_span_id]
            wf_end = self.spans["end_time"][wf_span_id]
            total_time = wf_end - wf_start
            wf_inp = self.spans["attributes.input.value"].get(wf_span_id, "")
            wf_out = self.spans["attributes.output.value"].get(wf_span_id, "")
            wf_inp = print_pretty_with_embedded_json(wf_inp)
            wf_out = print_pretty_with_embedded_json(wf_out)

            self._add_node(
                label=NodeLabel.WORKFLOW_COMPLETE,
                input=wf_inp,
                output=wf_out,
                reasoning=[],
                start_time=wf_start,
                end_time=wf_end,
                time=total_time,
                level=current_level,
            )
        return self.nodes
