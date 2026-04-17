"""Smoke tests for tool routes with permission gates."""

from unittest.mock import AsyncMock, MagicMock, patch


# ── list-files ────────────────────────────────────────────────────────────────

def test_list_files_requires_auth(client):
    resp = client.post("/api/v1/tools/list-files", json={"owner": "o", "repo": "r"})
    assert resp.status_code == 401


def test_list_files_requires_github_connection(client, auth_headers):
    """No GitHub connection → 403."""
    resp = client.post("/api/v1/tools/list-files", json={"owner": "o", "repo": "r"}, headers=auth_headers)
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "GITHUB_NOT_CONNECTED"


def test_list_files_success(client, auth_headers, github_connection):
    mock_items = [
        {"name": "README.md", "type": "file", "size": 100, "sha": "abc", "html_url": "http://x"}
    ]
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = mock_items

    async def fake_get(*args, **kwargs):
        return mock_resp

    with patch("httpx.AsyncClient") as mock_client_cls:
        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = fake_get
        mock_client_cls.return_value = mock_client

        resp = client.post(
            "/api/v1/tools/list-files",
            json={"owner": "test-owner", "repo": "test-repo", "path": ""},
            headers=auth_headers,
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["count"] == 1
    assert data["items"][0]["name"] == "README.md"


# ── create-branch ─────────────────────────────────────────────────────────────

def test_create_branch_requires_write_scope(client, auth_headers):
    """No GitHub connection → 403."""
    resp = client.post(
        "/api/v1/tools/create-branch",
        json={"branch": "feature/x"},
        headers=auth_headers,
    )
    assert resp.status_code == 403


# ── create-pull-request ────────────────────────────────────────────────────────

def test_create_pr_requires_auth(client):
    resp = client.post(
        "/api/v1/tools/create-pull-request",
        json={"title": "PR", "head": "feature"},
    )
    assert resp.status_code == 401


# ── create-task ───────────────────────────────────────────────────────────────

def test_create_task_requires_project_scope(client, auth_headers):
    resp = client.post(
        "/api/v1/tools/create-task",
        json={"title": "My task"},
        headers=auth_headers,
    )
    assert resp.status_code == 403


# ── list-tasks ────────────────────────────────────────────────────────────────

def test_list_tasks_requires_project_scope(client, auth_headers):
    resp = client.post("/api/v1/tools/list-tasks", json={}, headers=auth_headers)
    assert resp.status_code == 403


# ── update-task-status ────────────────────────────────────────────────────────

def test_update_task_status_invalid_item_id(client, auth_headers, github_connection):
    resp = client.post(
        "/api/v1/tools/update-task-status",
        json={"item_id": "INVALID_ID", "status": "Done"},
        headers=auth_headers,
    )
    assert resp.status_code in (403, 422)


# ── ask-codebase ──────────────────────────────────────────────────────────────

def test_ask_codebase_requires_auth(client):
    resp = client.post("/api/v1/tools/ask-codebase", json={"question": "hello"})
    assert resp.status_code == 401


def test_ask_codebase_no_groq_key(client, auth_headers):
    import os
    original = os.environ.pop("GROQ_API_KEY", None)
    try:
        resp = client.post("/api/v1/tools/ask-codebase", json={"question": "hello"}, headers=auth_headers)
        assert resp.status_code == 500
        assert resp.json()["error"]["code"] == "CONFIG_ERROR"
    finally:
        if original:
            os.environ["GROQ_API_KEY"] = original


# ── assign-task ───────────────────────────────────────────────────────────────

def test_assign_task_requires_auth(client):
    resp = client.post(
        "/api/v1/tools/assign-task",
        json={"issue_number": 1, "assignees": ["alice"]},
    )
    assert resp.status_code == 401
