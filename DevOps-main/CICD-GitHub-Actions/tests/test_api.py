import pytest

from app.main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_index_lists_operations(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["operations"] == ["add", "divide", "multiply", "subtract"]


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


@pytest.mark.parametrize(
    "operation, expected",
    [("add", 15), ("subtract", 5), ("multiply", 50), ("divide", 2)],
)
def test_operations(client, operation, expected):
    response = client.get(f"/api/{operation}?a=10&b=5")
    assert response.status_code == 200
    assert response.get_json()["result"] == expected


def test_divide_by_zero_returns_400(client):
    response = client.get("/api/divide?a=1&b=0")
    assert response.status_code == 400
    assert "divide by zero" in response.get_json()["error"]


def test_missing_params_returns_400(client):
    assert client.get("/api/add?a=1").status_code == 400


def test_non_numeric_returns_400(client):
    assert client.get("/api/add?a=one&b=2").status_code == 400


def test_unknown_operation_returns_404(client):
    assert client.get("/api/power?a=2&b=3").status_code == 404
