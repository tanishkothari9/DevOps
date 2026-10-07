"""create items and stock_movements tables

Revision ID: 0001_create_inventory
"""
import sqlalchemy as sa
from alembic import op

revision = "0001_create_inventory"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sku", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False, server_default="General"),
        sa.Column("location", sa.String(length=60), nullable=False, server_default="Unassigned"),
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reorder_level", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("unit_price", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("quantity >= 0", name="ck_items_quantity_non_negative"),
    )
    op.create_index("ix_items_sku", "items", ["sku"], unique=True)

    op.create_table(
        "stock_movements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("item_id", sa.Integer(), sa.ForeignKey("items.id", ondelete="CASCADE"), nullable=False),
        sa.Column("delta", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=120), nullable=False, server_default="adjustment"),
        sa.Column("quantity_after", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_stock_movements_item_id", "stock_movements", ["item_id"])


def downgrade() -> None:
    op.drop_index("ix_stock_movements_item_id", table_name="stock_movements")
    op.drop_table("stock_movements")
    op.drop_index("ix_items_sku", table_name="items")
    op.drop_table("items")
