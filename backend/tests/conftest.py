"""Shared pytest fixtures for the FastAPI BFF test suite."""

import os
import pytest

# ── Env setup before any app imports ─────────────────────────────────────────
os.environ.setdefault("POSTGRES_URL", "postgresql://postgres:postgres@localhost:5434/ai_db")
os.environ.setdefault("JWT_SECRET", "test-secret-key-for-pytest")
os.environ.setdefault("JWT_ALGORITHM", "HS256")
os.environ.setdefault("JWT_EXPIRATION", "3600")
os.environ.setdefault("TOKEN_ENCRYPTION_KEY", "dGVzdC1rZXktZm9yLXB5dGVzdC10ZXN0LWtleS1mb3I=")  # 32-byte b64
os.environ.setdefault("GITHUB_TOKEN", "test-token")
os.environ.setdefault("GITHUB_OWNER", "test-owner")
os.environ.setdefault("GITHUB_REPO", "test-repo")
os.environ.setdefault("PROJECT_ID", "1")
os.environ.setdefault("GROQ_API_KEY", "test-groq-key")
os.environ.setdefault("GITHUB_CLIENT_ID", "test-client-id")
os.environ.setdefault("GITHUB_CLIENT_SECRET", "test-client-secret")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from github_mcp.api.db import Base, get_db_dep
from github_mcp.api.auth import create_token
from github_mcp.api.models import User, OAuthConnection, UserContext, AuditLog  # noqa: F401 — registers all models
from github_mcp.api.crypto import encrypt_token

# ── In-memory SQLite — StaticPool shares one connection so all sessions see same DB ──
TEST_DB_URL = "sqlite:///:memory:"
engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db():
    session = TestingSessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


@pytest.fixture
def client(db):
    """TestClient with DB dependency overridden to use in-memory SQLite."""
    from api_server import app

    def override_db():
        yield db

    app.dependency_overrides[get_db_dep] = override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db) -> User:
    """Create and return a test User in the DB with a unique firebase_uid."""
    import uuid
    uid = f"test-uid-{uuid.uuid4()}"
    user = User(firebase_uid=uid, email=f"{uid[:8]}@example.com", auth_provider="firebase")
    db.add(user)
    db.flush()
    return user


@pytest.fixture
def auth_token(test_user) -> str:
    """Backend JWT for the test user."""
    return create_token(test_user.id, test_user.firebase_uid)


@pytest.fixture
def auth_headers(auth_token) -> dict:
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def github_connection(db, test_user) -> OAuthConnection:
    """OAuthConnection with encrypted token and full scopes."""
    conn = OAuthConnection(
        user_id=test_user.id,
        provider="github",
        access_token_encrypted=encrypt_token("ghp_test_token"),
        scopes="repo,read:org,project",
    )
    db.add(conn)
    db.flush()
    return conn
