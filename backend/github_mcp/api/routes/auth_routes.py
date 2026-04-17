"""Auth endpoints: Firebase login (Google + email/password), GitHub OAuth connect, user context."""

import os
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from loguru import logger

from ..auth import create_token
from ..crypto import encrypt_token
from ..db import get_db_dep
from ..dependencies import get_current_user
from ..exceptions import AuthError, AppError
from ..firebase_auth import verify_firebase_token
from ..models import AuditLog, OAuthConnection, User, UserContext

router = APIRouter(prefix="/auth", tags=["auth"])

_GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
_REQUIRED_SCOPES = {"repo", "read:org", "project"}


# ── Request / Response models ────────────────────────────────────────────────

class FirebaseLoginRequest(BaseModel):
    id_token: str


class FirebaseLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    firebase_uid: str


class GitHubConnectRequest(BaseModel):
    code: str


class GitHubConnectResponse(BaseModel):
    connected: bool
    scopes: list[str]


class ContextResponse(BaseModel):
    selected_owner: str | None
    selected_repo: str | None
    selected_project_number: int | None


class ContextUpdateRequest(BaseModel):
    selected_owner: str | None = None
    selected_repo: str | None = None
    selected_project_number: int | None = None


# ── Helpers ──────────────────────────────────────────────────────────────────

def _upsert_user(db: Session, firebase_uid: str, email: str | None) -> User:
    user = db.query(User).filter_by(firebase_uid=firebase_uid).first()
    if user:
        if email and user.email != email:
            user.email = email
    else:
        user = User(firebase_uid=firebase_uid, email=email, auth_provider="firebase")
        db.add(user)
        db.flush()
    return user


def _audit(db: Session, user_id: int, action: str, resource: str | None = None):
    db.add(AuditLog(user_id=user_id, action=action, resource=resource))


# ── Routes ───────────────────────────────────────────────────────────────────

@router.post("/firebase-login", response_model=FirebaseLoginResponse)
def firebase_login(body: FirebaseLoginRequest, db: Session = Depends(get_db_dep)):
    """Verify Firebase ID token, upsert user, return backend JWT."""
    try:
        claims = verify_firebase_token(body.id_token)
    except AuthError:
        raise
    except Exception as e:
        raise AuthError(f"Firebase token verification failed: {e}")
    firebase_uid = claims["uid"]
    email = claims.get("email")

    user = _upsert_user(db, firebase_uid, email)
    _audit(db, user.id, "firebase_login")
    db.commit()

    token = create_token(user.id, firebase_uid)
    logger.info(f"firebase_login | user_id={user.id} uid={firebase_uid}")
    return FirebaseLoginResponse(
        access_token=token,
        user_id=user.id,
        firebase_uid=firebase_uid,
    )


@router.post("/connect-github", response_model=GitHubConnectResponse)
def connect_github(
    body: GitHubConnectRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
):
    """Exchange GitHub OAuth code for an access token and store it encrypted."""
    client_id = os.environ.get("GITHUB_CLIENT_ID", "")
    client_secret = os.environ.get("GITHUB_CLIENT_SECRET", "")
    redirect_uri = os.environ.get("GITHUB_OAUTH_REDIRECT_URI", "")

    if not client_id or not client_secret:
        raise AppError("CONFIG_ERROR", "GitHub OAuth not configured on server", status_code=500)

    resp = httpx.post(
        _GITHUB_TOKEN_URL,
        headers={"Accept": "application/json"},
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": body.code,
            "redirect_uri": redirect_uri,
        },
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()

    if "error" in data:
        raise AuthError(f"GitHub OAuth error: {data.get('error_description', data['error'])}")

    access_token = data.get("access_token", "")
    if not access_token:
        raise AuthError("GitHub did not return an access token. Check client_id/secret and redirect_uri.")

    scope_str = data.get("scope", "")
    scopes = set(s.strip() for s in scope_str.split(",") if s.strip())

    missing = _REQUIRED_SCOPES - scopes
    if missing:
        logger.warning(f"connect_github | user_id={user.id} missing scopes: {missing}")

    encrypted = encrypt_token(access_token)

    conn = db.query(OAuthConnection).filter_by(user_id=user.id, provider="github").first()
    if conn:
        conn.access_token_encrypted = encrypted
        conn.scopes = ",".join(scopes)
        conn.updated_at = datetime.now(timezone.utc)
    else:
        conn = OAuthConnection(
            user_id=user.id,
            provider="github",
            access_token_encrypted=encrypted,
            scopes=",".join(scopes),
        )
        db.add(conn)

    _audit(db, user.id, "connect_github", resource="github")
    db.commit()

    logger.info(f"connect_github | user_id={user.id} scopes={scopes}")
    return GitHubConnectResponse(connected=True, scopes=sorted(scopes))


@router.get("/context", response_model=ContextResponse)
def get_context(
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
):
    ctx = db.query(UserContext).filter_by(user_id=user.id).first()
    if not ctx:
        return ContextResponse(selected_owner=None, selected_repo=None, selected_project_number=None)
    return ContextResponse(
        selected_owner=ctx.selected_owner,
        selected_repo=ctx.selected_repo,
        selected_project_number=ctx.selected_project_number,
    )


@router.post("/context", response_model=ContextResponse)
def set_context(
    body: ContextUpdateRequest,
    db: Session = Depends(get_db_dep),
    user: User = Depends(get_current_user),
):
    ctx = db.query(UserContext).filter_by(user_id=user.id).first()
    if ctx:
        if body.selected_owner is not None:
            ctx.selected_owner = body.selected_owner
        if body.selected_repo is not None:
            ctx.selected_repo = body.selected_repo
        if body.selected_project_number is not None:
            ctx.selected_project_number = body.selected_project_number
    else:
        ctx = UserContext(
            user_id=user.id,
            selected_owner=body.selected_owner,
            selected_repo=body.selected_repo,
            selected_project_number=body.selected_project_number,
        )
        db.add(ctx)

    _audit(db, user.id, "set_context")
    db.commit()
    logger.info(f"set_context | user_id={user.id} owner={ctx.selected_owner} repo={ctx.selected_repo}")
    return ContextResponse(
        selected_owner=ctx.selected_owner,
        selected_repo=ctx.selected_repo,
        selected_project_number=ctx.selected_project_number,
    )
