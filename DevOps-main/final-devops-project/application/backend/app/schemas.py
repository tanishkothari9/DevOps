from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

SKU_PATTERN = r"^[A-Z0-9][A-Z0-9-]{1,39}$"


class ItemCreate(BaseModel):
    sku: str = Field(pattern=SKU_PATTERN, description="Upper-case SKU, e.g. KB-1042")
    name: str = Field(min_length=1, max_length=200)
    category: str = Field(default="General", min_length=1, max_length=60)
    location: str = Field(default="Unassigned", min_length=1, max_length=60)
    quantity: int = Field(default=0, ge=0)
    reorder_level: int = Field(default=5, ge=0)
    unit_price: float = Field(default=0, ge=0)


class ItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: str | None = Field(default=None, min_length=1, max_length=60)
    location: str | None = Field(default=None, min_length=1, max_length=60)
    reorder_level: int | None = Field(default=None, ge=0)
    unit_price: float | None = Field(default=None, ge=0)


class ItemOut(ItemCreate):
    id: int
    low_stock: bool
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StockAdjust(BaseModel):
    delta: int = Field(description="Positive = goods received, negative = goods shipped")
    reason: str = Field(default="adjustment", min_length=1, max_length=120)


class MovementOut(BaseModel):
    id: int
    item_id: int
    delta: int
    reason: str
    quantity_after: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StatsOut(BaseModel):
    total_skus: int
    total_units: int
    inventory_value: float
    low_stock: int
    out_of_stock: int
    categories: dict[str, int]


class InfoOut(BaseModel):
    service: str
    version: str
    environment: str
