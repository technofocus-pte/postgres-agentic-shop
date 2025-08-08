import { NodeTypes, Node } from '@xyflow/react';
import OutputNode from 'components/nodes/output-node/output-node';
import TimerNode from 'components/nodes/timer-node/timer-node';

type AgentNodeData = {
  label: string;
  labelWithCounter?: string;
  input: string | null;
  output: string | null;
  reasoning: string[] | null;
  start_time: string | null;
  end_time: string | null;
  time: number | null;
};
export type AgenticFlowDiagramData = {
  nodes: {
    id: string;
    data: AgentNodeData;
    level: string | null;
    status: string;
    show_in_flow_graph?: boolean;
  }[];
  edges: {
    id: string;
    source: string;
    target: string;
  }[];
  user_query_agent_flow: boolean;
};

export type AgenticNodeItem = AgenticFlowDiagramData['nodes'][number];
// Define custom node interface with level property
export interface CustomNode extends Node {
  level?: number;
  data: {
    [key: string]: unknown;
  };
}

// Define custom node types
export const nodeTypes: NodeTypes = {
  timerNode: TimerNode,
  outputNode: OutputNode,
};

export interface FlowDiagramProps {
  data?: AgenticFlowDiagramData;
  traceId?: string;
}
