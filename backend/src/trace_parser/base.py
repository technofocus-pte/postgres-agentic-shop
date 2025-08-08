from collections import defaultdict

from pandas import DataFrame
from src.trace_parser.dataclasses import Edge, Node, NodeData
from src.trace_parser.enums import NodeLabel, NodeStatus


class BaseParser:
    """
    Base class for parsers
    """

    PARALLEL_AGENT_LABELS = [
        NodeLabel.PRODUCT_PERSONALIZATION_AGENT,
        NodeLabel.REVIEW_AGENT,
        NodeLabel.INVENTORY_AGENT,
    ]

    def __init__(self, spans: DataFrame):
        self.spans = spans
        self.nodes: list[Node] = []
        self.edges: list[Edge] = []
        self.agent_already_parsed = []
        self._id_counter = 0

    def parse(self):
        raise NotImplementedError("Method Not Implemented")

    def _generate_new_node_id(self) -> int:
        self._id_counter += 1
        return self._id_counter

    def _get_current_node_id(self) -> int:
        return self._id_counter

    def _get_node_status(self, status_message: str) -> NodeStatus:
        return (
            NodeStatus.triggered
            if "WorkflowTimeoutError" not in status_message
            else NodeStatus.not_triggered
        )

    def _add_node(
        self,
        label: NodeLabel,
        input: str,
        output: str,
        reasoning: list[str],
        start_time: str,
        end_time: str,
        time: str,
        level: int,
        status: NodeStatus = NodeStatus.triggered,
    ):
        node = Node(
            id=self._generate_new_node_id(),
            data=NodeData(
                label=label,
                input=input,
                output=output,
                reasoning=reasoning,
                start_time=start_time,
                end_time=end_time,
                time=time,
            ),
            level=level,
            status=status,
        )
        self.nodes.append(node)

    def _add_placeholder_node(
        self,
        label: NodeLabel,
        level: int,
        use_new_id: bool = True,
    ) -> Node:
        node_id = (
            self._generate_new_node_id() if use_new_id else self._get_current_node_id()
        )
        node = Node(
            id=node_id,
            data=NodeData(label=label),
            level=level,
            status=NodeStatus.not_triggered,
        )
        self.nodes.append(node)

    def _add_missing_parallel_agents_nodes(self, parallel_agent_level: int):
        if not self.nodes:
            return None

        last_node = self.nodes.pop()
        new_nodes_count = 0
        for agent in self.PARALLEL_AGENT_LABELS:
            if agent in self.agent_already_parsed:
                continue
            self._add_placeholder_node(
                label=agent,
                level=parallel_agent_level,
                use_new_id=(False if new_nodes_count == 0 else True),
            )
            new_nodes_count += 1

        last_node.id = (
            self._generate_new_node_id()
            if new_nodes_count > 0
            else self._get_current_node_id()
        )
        self.nodes.append(last_node)

    def _assign_level_to_agents(self):
        label_to_nodes = defaultdict(list)
        for n in self.nodes:
            label_to_nodes[n.data.label].append(n)

        level_map = {}
        current_level = 1

        self._assign_level_for_label(
            label_to_nodes,
            NodeLabel.USER_QUERY_AGENT,
            level_map,
            lambda: current_level,
        )
        current_level += len(label_to_nodes.get(NodeLabel.USER_QUERY_AGENT, []))

        any_assigned = False
        for label in [
            NodeLabel.SEARCH_PRODUCTS,
            NodeLabel.QUERY_REVIEWS_WITH_SENTIMENTS,
            NodeLabel.QUERY_ABOUT_PRODUCT,
        ]:
            nodes = label_to_nodes.get(label, [])
            if nodes:
                level_map[nodes[0].id] = current_level
                any_assigned = True
        if any_assigned:
            current_level += 1

        self._assign_level_for_label(
            label_to_nodes,
            NodeLabel.PLANNING_AGENT,
            level_map,
            lambda: current_level,
        )
        current_level += len(label_to_nodes.get(NodeLabel.PLANNING_AGENT, []))

        for label in self.PARALLEL_AGENT_LABELS:
            nodes = label_to_nodes.get(label, [])
            if nodes:
                level_map[nodes[0].id] = current_level
        parallel_agents_level = current_level
        current_level += 1

        already_assigned = set(level_map.keys())
        for n in self.nodes:
            if n.id not in already_assigned:
                level_map[n.id] = current_level
                current_level += 1

        for node in self.nodes:
            if node.id in level_map:
                node.level = level_map[node.id]
        return current_level, parallel_agents_level

    def _assign_level_for_label(self, label_to_nodes, label, level_map, get_level):
        for n in label_to_nodes.get(label, []):
            level_map[n.id] = get_level()

    def _reorder_parallel_nodes(self) -> list[Node]:
        desired_order = self.PARALLEL_AGENT_LABELS
        label_to_index = {}
        label_to_node = {}
        for i, node in enumerate(self.nodes):
            label = node.data.label
            if label in desired_order and label not in label_to_index:
                label_to_index[label] = i
                label_to_node[label] = node

        if not all(label in label_to_index for label in desired_order):
            return self.nodes

        result = []
        used_indices = set(label_to_index.values())
        min_idx = min(label_to_index.values())
        result.extend(self.nodes[:min_idx])
        for label in desired_order:
            result.append(label_to_node[label])

        for i, node in enumerate(
            self.nodes[min_idx + len(desired_order) :],  # noqa: E203
            start=min_idx + len(desired_order),
        ):
            if i not in used_indices:
                result.append(node)

        self.nodes = result

    def _generate_edges(self):
        nodes_by_id = {node.id: node for node in self.nodes}
        nodes_by_label = defaultdict(list)
        for node in self.nodes:
            label = node.data.label
            nodes_by_label[label].append(node.id)

        planning_agent = nodes_by_label.get(NodeLabel.PLANNING_AGENT, [])[:1]
        inventory_agent = nodes_by_label.get(NodeLabel.INVENTORY_AGENT, [])[:1]
        personalization_agent = nodes_by_label.get(
            NodeLabel.PRODUCT_PERSONALIZATION_AGENT,
            [],
        )[:1]
        review_agents = nodes_by_label.get(NodeLabel.REVIEW_AGENT, [])
        evaluation_agents = nodes_by_label.get(NodeLabel.EVALUATION_AGENT, [])
        presentation_agents = nodes_by_label.get(NodeLabel.PRESENTATION_AGENT, [])
        workflow_complete = nodes_by_label.get(NodeLabel.WORKFLOW_COMPLETE, [])

        command_routing_agent = nodes_by_label.get(NodeLabel.USER_QUERY_AGENT, [])[:1]
        personalization_command_tool = nodes_by_label.get(
            NodeLabel.QUERY_ABOUT_PRODUCT,
            [],
        )
        search_with_sentiment_tool = nodes_by_label.get(
            NodeLabel.QUERY_REVIEWS_WITH_SENTIMENTS,
            [],
        )
        search_tool = nodes_by_label.get(NodeLabel.SEARCH_PRODUCTS, [])

        if command_routing_agent:
            command_id = command_routing_agent[0]
            for target_id in (
                search_with_sentiment_tool + search_tool + personalization_command_tool
            ):
                self.edges.append(Edge(source=command_id, target=target_id))

        for source_id in personalization_command_tool:
            if nodes_by_id[source_id].status == NodeStatus.triggered:
                for planning_id in planning_agent:
                    self.edges.append(Edge(source=source_id, target=planning_id))

        if planning_agent:
            planning_id = planning_agent[0]
            for target_id in (
                inventory_agent + personalization_agent + review_agents[:1]
            ):
                self.edges.append(Edge(source=planning_id, target=target_id))

        if review_agents and evaluation_agents:
            sorted_reviews = sorted(review_agents, key=int)
            sorted_evals = sorted(evaluation_agents, key=int)
            self.edges.append(Edge(source=sorted_reviews[0], target=sorted_evals[0]))

            last_eval = sorted_evals[0]
            for i in range(1, min(len(sorted_reviews), len(sorted_evals))):
                next_review = sorted_reviews[i]
                next_eval = sorted_evals[i]
                self.edges.append(Edge(source=last_eval, target=next_review))
                self.edges.append(Edge(source=next_review, target=next_eval))
                last_eval = next_eval

            for present_id in presentation_agents:
                self.edges.append(Edge(source=last_eval, target=present_id))

        elif review_agents and presentation_agents:
            for review_id in review_agents[:1]:
                for present_id in presentation_agents:
                    self.edges.append(Edge(source=review_id, target=present_id))

        for agent_id in inventory_agent + personalization_agent:
            for present_id in presentation_agents:
                self.edges.append(Edge(source=agent_id, target=present_id))

        for present_id in presentation_agents:
            for wf_id in workflow_complete:
                self.edges.append(Edge(source=present_id, target=wf_id))

        unique_edges = {edge.id: edge for edge in self.edges}.values()
        self.edges = sorted(
            unique_edges,
            key=lambda edge: (int(edge.source), int(edge.target)),
        )
