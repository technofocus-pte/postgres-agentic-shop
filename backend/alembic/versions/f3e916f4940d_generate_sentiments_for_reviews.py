"""Generate sentiments for reviews

Revision ID: f3e916f4940d
Revises: 9b49601586d0
Create Date: 2025-05-08 22:28:01.270278

"""

import logging
import time
from typing import Sequence, Union

from alembic import op
from sqlalchemy import text
from src.config.config import settings

# revision identifiers, used by Alembic.
revision: str = "f3e916f4940d"  # pragma: allowlist secret
down_revision: Union[str, None] = "cc30da9b96c1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

logger = logging.getLogger()


def _configure_azure_ai():
    """
    Configures Azure AI settings in the database.
    """
    try:
        logger.info("Configuring Azure AI extension and settings.")
        op.execute("CREATE EXTENSION IF NOT EXISTS azure_ai;")

        settings_queries = [
            f"SELECT azure_ai.set_setting('azure_openai.subscription_key',\
            '{settings.AZURE_OPENAI_API_KEY}');",
            f"SELECT azure_ai.set_setting('azure_openai.endpoint', '{settings.AZURE_OPENAI_ENDPOINT}');",
        ]

        for query in settings_queries:
            op.execute(query)

        logger.info("Azure AI configuration completed successfully.")
    except Exception as e:
        logger.info(f"Failed to configure Azure AI: {e}")
        raise


def batch_update_sentiments():
    conn = op.get_bind()
    offset = 0
    batch_number = 1

    while True:
        review_ids = conn.execute(
            text(
                f"""
                SELECT id FROM product_reviews
                WHERE feature_id IS NOT NULL
                ORDER BY id
                LIMIT {settings.MIGRATION_BATCH_SIZE}
                OFFSET {offset}
            """,
            ),
        ).fetchall()

        if not review_ids:
            logger.info("All reviews processed.")
            break

        # Convert review IDs to a comma-separated string for the SQL query
        id_list = [str(row[0]) for row in review_ids]
        id_list_str = ",".join(id_list)

        op.execute(
            f"""
            WITH sentiment_extraction AS (
                SELECT
                    r.id AS review_id,
                    azure_ai.extract(
                        'Review: ' || r.review || ' Feature: ' || f.feature_name,
                        ARRAY['sentiment - sentiment about the feature as in positive, negative, or neutral'],
                        model => '{settings.LLM_MODEL}'
                    ) ->> 'sentiment' AS extracted_sentiment
                FROM product_reviews r
                JOIN features f ON f.id = r.feature_id
                WHERE r.id IN ({id_list_str})
            )
            UPDATE product_reviews
            SET sentiment = se.extracted_sentiment
            FROM sentiment_extraction se
            WHERE product_reviews.id = se.review_id;
            """,
        )

        logger.info(
            f"Processed batch #{batch_number} — Reviews {offset + 1} to {offset + len(review_ids)}",
        )
        offset += settings.MIGRATION_BATCH_SIZE
        batch_number += 1
        time.sleep(settings.MIGRATION_SLEEP_SECONDS)


def batch_extract_features_from_reviews():
    """
    Following query extracts the feature being talked about in the review
    Extract function only returns one value. The data is already present in the CSV, since it
    takes a bit of time. Following query is for reference
    """

    conn = op.get_bind()
    offset = 0
    batch_number = 1

    while True:
        review_ids = conn.execute(
            text(
                f"""
                SELECT id FROM product_reviews
                ORDER BY id
                LIMIT {settings.MIGRATION_BATCH_SIZE}
                OFFSET {offset}
                """,
            ),
        ).fetchall()

        if not review_ids:
            logger.info("All reviews processed for feature extraction.")
            break

        id_list = [str(row[0]) for row in review_ids]
        id_list_str = ",".join(id_list)

        op.execute(
            f"""
            WITH features_per_review AS (
                SELECT
                    r.id AS review_id,
                    r.review,
                    'productFeature: string - A feature of a product. Features should be from: ' ||
                    STRING_AGG(fx.feature_name, ', ' ORDER BY fx.feature_name) || ' or NULL' AS feature_schema,
                    ARRAY_AGG(fx.id) AS feature_ids,
                    ARRAY_AGG(fx.feature_name) AS feature_names
                FROM product_reviews r
                JOIN product_features pf ON pf.product_id = r.product_id
                JOIN features fx ON fx.id = pf.feature_id
                WHERE r.id IN ({id_list_str})
                GROUP BY r.id, r.review
            ),
            extracted_features AS (
                SELECT
                    f.review_id,
                    LOWER((azure_ai.extract(f.review, ARRAY[f.feature_schema],
                    '{settings.LLM_MODEL}'))::JSONB->>'productFeature') AS extracted_feature
                FROM features_per_review f
            )
            UPDATE product_reviews
            SET feature_id = (
                SELECT fx.id
                FROM features fx
                WHERE LOWER(fx.feature_name) = ef.extracted_feature
                LIMIT 1
            )
            FROM extracted_features ef
            WHERE product_reviews.id = ef.review_id
            AND ef.extracted_feature IS NOT NULL
            AND ef.extracted_feature != 'null';
            """,
        )

        logger.info(
            f"Processed batch #{batch_number} for feature extraction — Reviews {offset + 1} to {offset + len(review_ids)}",
        )
        offset += settings.MIGRATION_BATCH_SIZE
        batch_number += 1
        time.sleep(settings.MIGRATION_SLEEP_SECONDS)


def upgrade() -> None:

    _configure_azure_ai()

    if settings.USE_AZURE_AI_FOR_REVIEWS:

        logger.info("Extracting features from reviews...")
        batch_extract_features_from_reviews()

        logger.info("Generating sentiments in batches...")
        batch_update_sentiments()


def downgrade() -> None:
    pass
