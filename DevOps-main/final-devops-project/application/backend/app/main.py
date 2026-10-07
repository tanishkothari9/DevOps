import logging

from fastapi import Depends, FastAPI, HTTPException, Query, status
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import Item, StockMovement
from .schemas import InfoOut, ItemCreate, ItemOut, ItemUpdate, MovementOut, StatsOut, StockAdjust

logging.basicConfig(
    level=settings.log_level.upper(),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","msg":"%(message)s"}',
)
log = logging.getLogger("stockpilot")

STOCK_MOVEMENTS = Counter(
    "stockpilot_stock_movements_total",
    "Stock adjustments applied, by direction",
    ["direction"],
)

app = FastAPI(title=settings.app_name, version=settings.app_version)
Instrumentator(excluded_handlers=["/metrics"]).instrument(app).expose(app, endpoint="/metrics")


def _get_item_or_404(db: Session, item_id: int) -> Item:
    item = db.get(Item, item_id)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@app.get("/")
def root() -> dict[str, str]:
    return {"service": settings.app_name, "version": settings.app_version, "docs": "/docs"}


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness: the process is up and able to answer HTTP."""
    return {"status": "UP"}


@app.get("/ready")
def ready(db: Session = Depends(get_db)) -> dict[str, str]:
    """Readiness: the database is reachable, so the pod may receive traffic."""
    db.execute(select(func.count(Item.id)))
    return {"status": "READY"}


@app.get("/api/info", response_model=InfoOut)
def info() -> InfoOut:
    return InfoOut(service=settings.app_name, version=settings.app_version, environment=settings.app_env)


@app.get("/api/items", response_model=list[ItemOut])
def list_items(
    q: str | None = Query(default=None, max_length=100),
    category: str | None = Query(default=None, max_length=60),
    low_stock: bool = False,
    db: Session = Depends(get_db),
) -> list[Item]:
    stmt = select(Item).order_by(Item.name)
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(or_(Item.name.ilike(pattern), Item.sku.ilike(pattern)))
    if category:
        stmt = stmt.where(Item.category == category)
    if low_stock:
        stmt = stmt.where(Item.quantity <= Item.reorder_level)
    return list(db.scalars(stmt))


@app.get("/api/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)) -> StatsOut:
    items = list(db.scalars(select(Item)))
    categories: dict[str, int] = {}
    for item in items:
        categories[item.category] = categories.get(item.category, 0) + 1
    return StatsOut(
        total_skus=len(items),
        total_units=sum(i.quantity for i in items),
        inventory_value=round(sum(i.quantity * float(i.unit_price) for i in items), 2),
        low_stock=sum(1 for i in items if i.low_stock),
        out_of_stock=sum(1 for i in items if i.quantity == 0),
        categories=categories,
    )


@app.get("/api/items/{item_id}", response_model=ItemOut)
def get_item(item_id: int, db: Session = Depends(get_db)) -> Item:
    return _get_item_or_404(db, item_id)


@app.post("/api/items", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
def create_item(payload: ItemCreate, db: Session = Depends(get_db)) -> Item:
    item = Item(**payload.model_dump())
    db.add(item)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"SKU {payload.sku} already exists") from exc
    db.refresh(item)
    log.info("item created sku=%s qty=%s", item.sku, item.quantity)
    return item


@app.put("/api/items/{item_id}", response_model=ItemOut)
def update_item(item_id: int, payload: ItemUpdate, db: Session = Depends(get_db)) -> Item:
    item = _get_item_or_404(db, item_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    return item


@app.delete("/api/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    item = _get_item_or_404(db, item_id)
    db.delete(item)
    db.commit()
    log.info("item deleted id=%s", item_id)


@app.post("/api/items/{item_id}/adjust", response_model=ItemOut)
def adjust_stock(item_id: int, payload: StockAdjust, db: Session = Depends(get_db)) -> Item:
    if payload.delta == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="delta must not be zero")
    item = _get_item_or_404(db, item_id)
    new_quantity = item.quantity + payload.delta
    if new_quantity < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient stock: {item.quantity} on hand, tried to remove {-payload.delta}",
        )
    item.quantity = new_quantity
    db.add(StockMovement(item=item, delta=payload.delta, reason=payload.reason, quantity_after=new_quantity))
    db.commit()
    db.refresh(item)
    STOCK_MOVEMENTS.labels(direction="in" if payload.delta > 0 else "out").inc()
    log.info("stock adjusted sku=%s delta=%s qty=%s", item.sku, payload.delta, item.quantity)
    return item


@app.get("/api/items/{item_id}/movements", response_model=list[MovementOut])
def list_movements(item_id: int, db: Session = Depends(get_db)) -> list[StockMovement]:
    return list(_get_item_or_404(db, item_id).movements)
