"""FastAPI dependency helpers for auth and DB."""

from typing import Optional

from fastapi import Depends, Header
from sqlalchemy.orm import Session

from .auth import decode_token
from .db import get_db_dep
from .exceptions import AuthError, ForbiddenError
from .models import User, OAuthConnection


def get_current_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db_dep),
) -> User:
    """Extract and verify the backend JWT, returning the User ORM object."""
    if not authorization:
        raise AuthError("Authorization header required")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise AuthError("Authorization header must be 'Bearer <token>'")

    payload = decode_token(token)
    user_id = int(payload["sub"])
    user = db.get(User, user_id)
    if not user:
        raise AuthError("User not found")
    return user


def require_github_connection(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db_dep),
) -> OAuthConnection:
    """Ensure the user has a connected GitHub account with valid scopes."""
    conn = (
        db.query(OAuthConnection)
        .filter_by(user_id=user.id, provider="github")
        .first()
    )
    if not conn:
        raise ForbiddenError(
            "GitHub not connected. Call POST /api/v1/auth/connect-github first.",
            code="GITHUB_NOT_CONNECTED",
        )
    return conn


def require_repo_read(
    conn: OAuthConnection = Depends(require_github_connection),
) -> OAuthConnection:
    scopes = set((conn.scopes or "").split(","))
    if "repo" not in scopes and "public_repo" not in scopes:
        raise ForbiddenError("repo:read scope required", code="SCOPE_MISSING")
    return conn


def require_repo_write(
    conn: OAuthConnection = Depends(require_github_connection),
) -> OAuthConnection:
    scopes = set((conn.scopes or "").split(","))
    if "repo" not in scopes:
        raise ForbiddenError("repo (write) scope required", code="SCOPE_MISSING")
    return conn


def require_project_scope(
    conn: OAuthConnection = Depends(require_github_connection),
) -> OAuthConnection:
    scopes = set((conn.scopes or "").split(","))
    if "project" not in scopes:
        raise ForbiddenError("project scope required", code="SCOPE_MISSING")
    return conn
