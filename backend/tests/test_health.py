"""Smoke tests for /health and /ready endpoints."""

from unittest.mock import patch


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_ready_db_ok(client):
    """When DB is reachable the /ready endpoint returns 200."""
    resp = client.get("/ready")
    # In tests we use SQLite in-memory — should be fine
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ready"
    assert data["db"] == "ok"


def test_ready_db_fail(client):
    """When DB raises, /ready returns 503."""
    import github_mcp.api.routes.health as health_module
    with patch.object(health_module, "SessionLocal", side_effect=Exception("db down")):
        resp = client.get("/ready")
    assert resp.status_code == 503
