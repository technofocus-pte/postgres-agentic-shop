import asyncio

import phoenix as px
from fastapi import HTTPException
from llama_index.core.vector_stores.types import MetadataFilter, MetadataFilters
from pandas import DataFrame
from phoenix.trace.dsl import SpanQuery
from src.config.config import settings
from src.config.memory import get_mem0_memory
from src.models.products import StatusEnum
from src.services.agent_workflow import MultiAgentWorkflowService
from src.utils.utils import set_personalization_status


def get_phoenix_client():
    return px.Client(endpoint=settings.PHOENIX_CLIENT_ENDPOINT)


def filter_trace_data(df: DataFrame):
    desired_cols = [
        "name",
        "span_kind",
        "parent_id",
        "start_time",
        "end_time",
        "context.trace_id",
        "context.span_id",
        "attributes.output.value",
        "attributes.input.value",
        "status_code",
        "status_message",
    ]
    # Only keep columns that actually exist to avoid KeyError in production
    existing_cols = [c for c in desired_cols if c in df.columns]
    if existing_cols:
        df = df[existing_cols]

    df = df.sort_values(by="start_time", ascending=True)
    return df


def _format_tuple_for_where(names: list[str]) -> str:
    if not names:
        return "()"
    if len(names) == 1:
        return f"('{names[0]}',)"
    return "(" + ",".join(f"'{n}'" for n in names) + ")"


def _find_missing_agents_from_df(
    df,
    required_agent_names: list[str],
    query_agent_spans: list[str] = None,
    is_search_trace: bool = False,
) -> list[str]:
    """
    Determine which required agents are missing from the dataframe.

    Additionally, require that at least one query-agent tool is present
    ONLY when all required agents are missing. If required agents are all
    present (or partially present), we don't enforce tool presence.
    """
    missing: set[str] = set()

    # If no data, treat everything as missing; also if 'name' column missing, we can't evaluate spans
    if df is None or df.empty or ("name" not in df.columns):
        missing.update(required_agent_names)
        return list(missing)

    if not is_search_trace:
        for agent_name in required_agent_names:
            if df[df["name"] == agent_name].empty:
                missing.add(agent_name)
    else:
        # For search traces: required agents are not expected.
        # Enforce: at least one query-agent span must be present.
        if query_agent_spans:
            tools_present = df["name"].isin(query_agent_spans).any()
            if not tools_present:
                missing.update(query_agent_spans)

    return list(missing)


def get_trace_dataframe(trace_id: str, is_search_trace: bool = False):
    """
    Single-fetch version: query Phoenix once (server-side filtering via .where/.select)
    and verify completeness. If incomplete, return HTTP 202 with Retry-After and details.
    """
    client = get_phoenix_client()
    required_agent_names = [
        "MultiAgentFlow.planning",
        "MultiAgentFlow.presentation",
        "MultiAgentFlow._done",
    ]
    query_agent_spans = ["FunctionAgent.run", "FunctionAgent._done"]
    tuple_literal = _format_tuple_for_where(required_agent_names)

    # Group name predicates together so status filter applies to all
    name_predicates = (
        f"name in {tuple_literal} "
        f"or 'MultiAgentFlow' in name "
        f"or name == 'FunctionAgent.run' "
        f"or name == 'FunctionAgent.init_run' "
        f"or name == 'FunctionAgent.run_agent_step' "
        f"or name == 'FunctionTool.acall' "
        f"or name == 'FunctionAgent._done'"
    )
    where_clause = (
        f"trace_id == '{trace_id}' and "
        f"({name_predicates}) "
        f"and status_code == 'OK'"
    )

    query = SpanQuery().where(where_clause)
    df = client.query_spans(query, project_name=settings.PHOENIX_PROJECT_NAME)
    if df.empty or df is None:
        raise HTTPException(status_code=404, detail="Trace not found")

    missing_agents = _find_missing_agents_from_df(
        df, required_agent_names, query_agent_spans, is_search_trace
    )

    if missing_agents:
        raise HTTPException(
            status_code=404,
            detail={
                "message": "Trace incomplete: some agents are missing or not OK. Retry later.",
                "trace_id": trace_id,
                "missing_or_not_ok_agents": missing_agents,
            },
        )
    return filter_trace_data(df)


def build_metadata_filters(product_id: int):
    return MetadataFilters(filters=[MetadataFilter(key="product_id", value=product_id)])


async def wait_for_personalization_ready(personalized_section, db, timeout=60):
    start_time = asyncio.get_running_loop().time()
    while personalized_section and personalized_section.status is StatusEnum.running:
        if asyncio.get_running_loop().time() - start_time > timeout:
            return None
        await db.refresh(personalized_section)
        await asyncio.sleep(2)
    return personalized_section


async def run_personalization_workflow(request, product_id, db, fault_correction):
    filters = build_metadata_filters(product_id)
    workflow_service = MultiAgentWorkflowService(
        user_id=request.state.user_id,
        product_id=product_id,
        llm=request.app.state.llm,
        embed_model=request.app.state.embed_model,
        vector_store_products_embeddings=request.app.state.vector_store_products_embeddings,
        vector_store_reviews_embeddings=request.app.state.vector_store_reviews_embeddings,
        filters=filters,
        memory=get_mem0_memory(),
        fault_correction=fault_correction,
    )
    await set_personalization_status(
        db,
        request.state.user_id,
        product_id,
        StatusEnum.running,
    )
    response, trace_id = await workflow_service.run_workflow()
    return await workflow_service.save_workflow_response(response, trace_id)
