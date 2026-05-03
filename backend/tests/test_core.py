"""Tests for core helpers: crypto, auth JWT, and github_api helpers."""

import os
import pytest
from jose import jwt


def test_encrypt_decrypt_roundtrip():
    from github_mcp.api.crypto import encrypt_token, decrypt_token

    original = "ghp_secret_token_abc123"
    cipher = encrypt_token(original)
    assert cipher != original
    assert decrypt_token(cipher) == original


def test_decrypt_tampered_raises():
    from github_mcp.api.crypto import decrypt_token

    with pytest.raises(ValueError, match="decryption failed"):
        decrypt_token("not-valid-ciphertext")


def test_create_and_decode_token():
    from github_mcp.api.auth import create_token, decode_token

    token = create_token(user_id=42, firebase_uid="uid-abc")
    payload = decode_token(token)
    assert payload["sub"] == "42"
    assert payload["uid"] == "uid-abc"


def test_decode_invalid_token_raises():
    from github_mcp.api.auth import decode_token
    from github_mcp.api.exceptions import AuthError

    with pytest.raises(AuthError):
        decode_token("invalid.jwt.token")


def test_decode_wrong_secret_raises():
    from github_mcp.api.exceptions import AuthError
    from github_mcp.api.auth import decode_token

    bad_token = jwt.encode({"sub": "1", "uid": "x"}, "wrong-secret", algorithm="HS256")
    with pytest.raises(AuthError):
        decode_token(bad_token)


def test_headers_require_token(monkeypatch):
    """_headers raises if GITHUB_TOKEN is empty."""
    import github_mcp.core.github_api as api_module

    original = api_module.GITHUB_TOKEN
    monkeypatch.setattr(api_module, "GITHUB_TOKEN", "")
    with pytest.raises(RuntimeError, match="GITHUB_TOKEN"):
        api_module._headers()
    monkeypatch.setattr(api_module, "GITHUB_TOKEN", original)


def test_headers_with_explicit_token():
    from github_mcp.core.github_api import _headers

    h = _headers(token="explicit-token")
    assert h["Authorization"] == "Bearer explicit-token"


def test_raise_for_status_on_4xx():
    from github_mcp.core.github_api import _raise_for_status
    from unittest.mock import MagicMock

    mock_resp = MagicMock()
    mock_resp.status_code = 404
    mock_resp.json.return_value = {"message": "Not Found"}
    with pytest.raises(RuntimeError, match="GitHub API error 404"):
        _raise_for_status(mock_resp)


def test_raise_for_status_ok():
    from github_mcp.core.github_api import _raise_for_status
    from unittest.mock import MagicMock

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    _raise_for_status(mock_resp)  # should not raise
