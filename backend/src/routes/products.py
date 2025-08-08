from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request
from src.config.config import settings
from src.database import DBSession
from src.models.products import StatusEnum
from src.repository import (
    PersonalizedProductRepository,
    ProductRepository,
    ReviewRepository,
)
from src.routes.utils import (
    get_trace_dataframe,
    run_personalization_workflow,
    wait_for_personalization_ready,
)
from src.schemas.personalization import (
    PersonalizationRequest,
    PersonalizationResponseSchema,
)
from src.schemas.products import (
    PaginatedProductsResponseSchema,
    ProductDetailsResponseSchema,
    ProductResponseSchema,
)
from src.schemas.reviews import PaginatedReviewResponseSchema, ReviewResponseSchema
from src.trace_parser import MultiAgentParser, SearchTraceParser

router = APIRouter(
    prefix="/products",
    tags=["products"],
    responses={404: {"description": "Not found"}},
)


@router.get("/{product_id}", response_model=ProductDetailsResponseSchema)
async def get_product_details(
    product_id: int,
    db: DBSession,
):
    product = await ProductRepository(db).get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return ProductDetailsResponseSchema.model_validate(product)


@router.get("/", response_model=PaginatedProductsResponseSchema)
async def get_products(
    db: DBSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(settings.PAGE_SIZE, ge=1),
):
    total, products = await ProductRepository(db).get_paginated(page, page_size)
    return PaginatedProductsResponseSchema(
        page=page,
        page_size=page_size,
        total=total,
        products=[
            ProductResponseSchema.model_validate(product) for product in products
        ],
    )


@router.get("/{product_id}/reviews")
async def get_product_reviews(
    product_id: int,
    db: DBSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(settings.PAGE_SIZE, ge=1),
):
    page_size = 500  # Set to 500 for demo purpose.
    total, reviews = await ReviewRepository(db).get_paginated_by_product(
        product_id,
        page,
        page_size,
    )
    return PaginatedReviewResponseSchema(
        page=page,
        page_size=page_size,
        total=total,
        reviews=[ReviewResponseSchema.model_validate(review) for review in reviews],
    )


@router.get("/search/debug")
async def get_search_debug_logs(trace_id: Optional[str] = Query(None)):
    df = get_trace_dataframe(trace_id)
    return SearchTraceParser(df).parse()


@router.post(
    "/{product_id}/personalizations",
    response_model=PersonalizationResponseSchema,
)
async def generate_personalized_content(
    request: Request,
    product_id: int,
    personalization_request: PersonalizationRequest,
    db: DBSession,
):
    personalized_section = None
    fault_correction = personalization_request.fault_correction

    try:
        personalized_section = await PersonalizedProductRepository(db).get_by_id(
            id=(product_id, request.state.user_id),
        )
        if (
            personalized_section.status is StatusEnum.failed
            and personalized_section.status is not StatusEnum.running
        ):
            personalized_section = None
    except HTTPException:
        pass

    if fault_correction:
        personalized_section = None

    personalized_section = await wait_for_personalization_ready(
        personalized_section,
        db,
    )
    if not personalized_section:
        personalized_section = await run_personalization_workflow(
            request,
            product_id,
            db,
            fault_correction,
        )
    return personalized_section


@router.get(
    "/{product_id}/personalizations",
    response_model=PersonalizationResponseSchema,
)
async def get_personalized_content(
    product_id: int,
    request: Request,
    db: DBSession,
):
    personalization = await PersonalizedProductRepository(db).get_by_id(
        id=(product_id, request.state.user_id),
    )
    return personalization


@router.get("/{product_id}/debug")
async def get_debug_logs(
    request: Request,
    product_id: int,
    db: DBSession,
):
    personalization = await PersonalizedProductRepository(db).get_by_id(
        id=(product_id, request.state.user_id),
    )
    df = get_trace_dataframe(personalization.phoenix_trace_id)
    search_trace_parser = SearchTraceParser(df)
    return MultiAgentParser(df, search_trace_parser).parse()
