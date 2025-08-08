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
    df = df[
        [
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
    ]
    df = df[
        df["name"].apply(
            lambda x: x == "Workflow.run"
            or x == "AgentWorkflow.run_agent_step"
            or x == "FunctionTool.acall"
            or x.startswith("MultiAgentFlow"),
        )
    ]
    df = df.sort_values(by="start_time", ascending=True)
    return df


def get_trace_dataframe(trace_id: str):
    client = get_phoenix_client()
    query = SpanQuery().where(f"trace_id == '{trace_id}'")
    df = client.query_spans(query, project_name=settings.PHOENIX_PROJECT_NAME)
    if df.empty or df is None:
        raise HTTPException(status_code=404, detail="Trace not found")
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
