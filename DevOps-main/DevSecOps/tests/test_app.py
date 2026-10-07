import pytest

from app.app import PIPELINE_STAGES, app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_home(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"<html" in response.data


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"


def test_security_headers(client):
    response = client.get("/health")
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"


def test_status(client):
    data = client.get("/api/status").get_json()
    assert data["status"] == "running"
    assert "python_version" in data
    assert "uptime" in data


def test_greet(client):
    data = client.get("/api/greet/Tanish").get_json()
    assert "Tanish" in data["message"]


def test_add_numbers(client):
    response = client.post("/api/add", json={"number1": 10, "number2": 20})
    assert response.status_code == 200
    assert response.get_json()["result"] == 30


def test_add_numbers_missing_fields(client):
    assert client.post("/api/add", json={"number1": 5}).status_code == 400


def test_add_numbers_no_body(client):
    assert client.post("/api/add").status_code == 400


def test_calculator_multiply(client):
    response = client.post("/api/calculate", json={"a": 4, "b": 5, "operation": "multiply"})
    assert response.status_code == 200
    assert response.get_json()["result"] == 20


def test_calculator_divide_by_zero(client):
    response = client.post("/api/calculate", json={"a": 10, "b": 0, "operation": "divide"})
    assert response.status_code == 400


def test_calculator_unknown_operation(client):
    response = client.post("/api/calculate", json={"a": 1, "b": 2, "operation": "sqrt"})
    assert response.status_code == 400


def test_calculator_huge_exponent_rejected(client):
    response = client.post("/api/calculate", json={"a": 10, "b": 100000, "operation": "power"})
    assert response.status_code == 400


def test_pipeline_always_passes_with_zero_fail_chance(client):
    data = client.post("/api/pipeline/run", json={"fail_chance": 0}).get_json()
    assert data["overall_status"] == "passed"
    assert len(data["stages"]) == len(PIPELINE_STAGES)


def test_pipeline_fails_and_skips_rest_with_full_fail_chance(client):
    data = client.post("/api/pipeline/run", json={"fail_chance": 1}).get_json()
    assert data["overall_status"] == "failed"
    assert data["stages"][0]["status"] == "failed"
    assert all(s["status"] == "skipped" for s in data["stages"][1:])


def test_unknown_route_returns_json_404(client):
    response = client.get("/does-not-exist")
    assert response.status_code == 404
    assert response.get_json()["code"] == 404
