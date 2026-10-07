import os
from collections.abc import Iterator

# Tests never touch PostgreSQL: point the app at an in-memory SQLite DB before it is imported.
os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"
os.environ["APP_ENV"] = "test"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base, get_db
from app.main import app

engine = create_engine(
    "sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
)
TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def _override_get_db() -> Iterator[Session]:
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override_get_db


@pytest.fixture(autouse=True)
def fresh_schema() -> Iterator[None]:
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def item(client: TestClient) -> dict:
    payload = {
        "sku": "KB-1001",
        "name": "Mechanical keyboard",
        "category": "Peripherals",
        "location": "A-01",
        "quantity": 10,
        "reorder_level": 3,
        "unit_price": 49.5,
    }
    response = client.post("/api/items", json=payload)
    assert response.status_code == 201
    return response.json()
