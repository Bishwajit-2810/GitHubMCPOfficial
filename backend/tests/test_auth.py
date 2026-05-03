"""Tests for auth endpoints: firebase-login, connect-github, context."""

from unittest.mock import patch, MagicMock

import pytest


# ── firebase-login ────────────────────────────────────────────────────────────

def test_firebase_login_success(client):
    fake_claims = {"uid": "firebase-uid-abc", "email": "user@example.com"}
    with patch("github_mcp.api.routes.auth_routes.verify_firebase_token", return_value=fake_claims):
        resp = client.post("/api/v1/auth/firebase-login", json={"id_token": "fake-firebase-token"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["token_type"] == "bearer"
    assert "access_token" in data
    assert data["firebase_uid"] == "firebase-uid-abc"
    assert isinstance(data["user_id"], int)


def test_firebase_login_invalid_token(client):
    with patch(
        "github_mcp.api.routes.auth_routes.verify_firebase_token",
        side_effect=Exception("bad token"),
    ):
        resp = client.post("/api/v1/auth/firebase-login", json={"id_token": "bad"})
    assert resp.status_code == 401


def test_firebase_login_upserts_existing_user(client):
    """Logging in twice with same uid should not create duplicate users."""
    fake_claims = {"uid": "existing-uid-999", "email": "existing@example.com"}
    with patch("github_mcp.api.routes.auth_routes.verify_firebase_token", return_value=fake_claims):
        r1 = client.post("/api/v1/auth/firebase-login", json={"id_token": "tok"})
        r2 = client.post("/api/v1/auth/firebase-login", json={"id_token": "tok"})
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["user_id"] == r2.json()["user_id"]


# ── connect-github ────────────────────────────────────────────────────────────

def test_connect_github_success(client, auth_headers):
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "access_token": "ghp_test123",
        "scope": "repo,read:org,project",
        "token_type": "bearer",
    }
    with patch("github_mcp.api.routes.auth_routes.httpx.post", return_value=mock_response):
        resp = client.post(
            "/api/v1/auth/connect-github",
            json={"code": "github-oauth-code"},
            headers=auth_headers,
        )
    assert resp.status_code == 200
    data = resp.json()
    assert data["connected"] is True
    assert "repo" in data["scopes"]


def test_connect_github_requires_auth(client):
    resp = client.post("/api/v1/auth/connect-github", json={"code": "code"})
    assert resp.status_code == 401


def test_connect_github_oauth_error(client, auth_headers):
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"error": "bad_verification_code", "error_description": "bad code"}
    with patch("github_mcp.api.routes.auth_routes.httpx.post", return_value=mock_response):
        resp = client.post(
            "/api/v1/auth/connect-github",
            json={"code": "bad-code"},
            headers=auth_headers,
        )
    assert resp.status_code == 401


# ── context ───────────────────────────────────────────────────────────────────

def test_get_context_empty(client, auth_headers):
    resp = client.get("/api/v1/auth/context", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["selected_owner"] is None
    assert data["selected_repo"] is None


def test_set_and_get_context(client, auth_headers):
    payload = {"selected_owner": "myorg", "selected_repo": "myrepo", "selected_project_number": 3}
    resp = client.post("/api/v1/auth/context", json=payload, headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["selected_owner"] == "myorg"

    get_resp = client.get("/api/v1/auth/context", headers=auth_headers)
    assert get_resp.json()["selected_repo"] == "myrepo"
    assert get_resp.json()["selected_project_number"] == 3


def test_context_requires_auth(client):
    resp = client.get("/api/v1/auth/context")
    assert resp.status_code == 401


# ── JWT auth edge cases ───────────────────────────────────────────────────────

def test_invalid_jwt_rejected(client):
    resp = client.get("/api/v1/auth/context", headers={"Authorization": "Bearer bad.token.here"})
    assert resp.status_code == 401


def test_missing_auth_header(client):
    resp = client.get("/api/v1/auth/context")
    assert resp.status_code == 401  # Optional header → 401 from get_current_user
