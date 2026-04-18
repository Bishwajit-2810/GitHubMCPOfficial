"""Smoke tests for /health and /ready endpoints."""


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
    from api_server import app
    from github_mcp.api.db import get_db_dep

    class BrokenSession:
        def execute(self, *_args, **_kwargs):
            raise Exception("db down")

    def broken_db_dep():
        yield BrokenSession()

    app.dependency_overrides[get_db_dep] = broken_db_dep
    resp = client.get("/ready")
    app.dependency_overrides.pop(get_db_dep, None)

    assert resp.status_code == 503
