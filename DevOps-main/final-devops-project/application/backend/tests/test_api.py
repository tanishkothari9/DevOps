from fastapi.testclient import TestClient


def test_health_is_up(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}


def test_ready_checks_database(client: TestClient) -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "READY"}


def test_info_reports_environment(client: TestClient) -> None:
    body = client.get("/api/info").json()
    assert body["service"] == "StockPilot API"
    assert body["environment"] == "test"


def test_create_and_get_item(client: TestClient, item: dict) -> None:
    assert item["sku"] == "KB-1001"
    assert item["low_stock"] is False
    response = client.get(f"/api/items/{item['id']}")
    assert response.status_code == 200
    assert response.json()["name"] == "Mechanical keyboard"


def test_duplicate_sku_is_rejected(client: TestClient, item: dict) -> None:
    response = client.post("/api/items", json={"sku": item["sku"], "name": "Duplicate"})
    assert response.status_code == 409


def test_invalid_payload_is_rejected(client: TestClient) -> None:
    response = client.post("/api/items", json={"sku": "bad sku", "name": "", "quantity": -1})
    assert response.status_code == 422


def test_list_items_with_filters(client: TestClient, item: dict) -> None:
    client.post("/api/items", json={"sku": "CB-2001", "name": "USB-C cable", "category": "Cables", "quantity": 2})
    assert len(client.get("/api/items").json()) == 2
    assert [i["sku"] for i in client.get("/api/items", params={"category": "Cables"}).json()] == ["CB-2001"]
    assert [i["sku"] for i in client.get("/api/items", params={"low_stock": True}).json()] == ["CB-2001"]
    assert [i["sku"] for i in client.get("/api/items", params={"q": "keyboard"}).json()] == ["KB-1001"]


def test_update_item(client: TestClient, item: dict) -> None:
    response = client.put(f"/api/items/{item['id']}", json={"reorder_level": 20, "location": "B-07"})
    assert response.status_code == 200
    body = response.json()
    assert body["location"] == "B-07"
    assert body["low_stock"] is True


def test_adjust_stock_records_movement(client: TestClient, item: dict) -> None:
    response = client.post(f"/api/items/{item['id']}/adjust", json={"delta": -4, "reason": "order #42"})
    assert response.status_code == 200
    assert response.json()["quantity"] == 6
    movements = client.get(f"/api/items/{item['id']}/movements").json()
    assert movements[0]["delta"] == -4
    assert movements[0]["quantity_after"] == 6


def test_adjust_stock_cannot_go_negative(client: TestClient, item: dict) -> None:
    response = client.post(f"/api/items/{item['id']}/adjust", json={"delta": -11})
    assert response.status_code == 400
    assert client.get(f"/api/items/{item['id']}").json()["quantity"] == 10


def test_stats(client: TestClient, item: dict) -> None:
    client.post("/api/items", json={"sku": "CB-2001", "name": "USB-C cable", "category": "Cables", "quantity": 0})
    stats = client.get("/api/stats").json()
    assert stats["total_skus"] == 2
    assert stats["total_units"] == 10
    assert stats["inventory_value"] == 495.0
    assert stats["out_of_stock"] == 1
    assert stats["categories"] == {"Peripherals": 1, "Cables": 1}


def test_delete_item(client: TestClient, item: dict) -> None:
    assert client.delete(f"/api/items/{item['id']}").status_code == 204
    assert client.get(f"/api/items/{item['id']}").status_code == 404


def test_metrics_endpoint_exposes_prometheus_format(client: TestClient) -> None:
    client.get("/health")
    body = client.get("/metrics").text
    assert "http_requests_total" in body
    assert "stockpilot_stock_movements_total" in body
