"""install postgress extensions

Revision ID: 7a35c0d9d159
Revises: f41ba96cab17
Create Date: 2025-08-18 23:33:18.523965

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import pgvector

# revision identifiers, used by Alembic.
revision: str = '7a35c0d9d159'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_diskann CASCADE;")
    op.execute("CREATE EXTENSION IF NOT EXISTS azure_ai CASCADE;")
    op.execute("CREATE EXTENSION IF NOT EXISTS age CASCADE;")


def downgrade() -> None:
    pass
