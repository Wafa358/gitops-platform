from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_create_get_delete_task():
    r = client.post("/tasks", json={"title": "Write the README"})
    assert r.status_code == 201
    task = r.json()
    assert task["title"] == "Write the README"
    assert task["done"] is False

    r = client.get(f"/tasks/{task['id']}")
    assert r.status_code == 200

    r = client.delete(f"/tasks/{task['id']}")
    assert r.status_code == 204

    r = client.get(f"/tasks/{task['id']}")
    assert r.status_code == 404


def test_metrics_exposed():
    client.get("/health")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "http_requests_total" in r.text
