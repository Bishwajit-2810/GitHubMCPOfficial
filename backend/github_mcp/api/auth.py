"""JWT creation and verification for the backend session token."""

import os
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from loguru import logger

from .exceptions import AuthError

_SECRET = os.environ.get("JWT_SECRET", "change-me-in-production")
_ALGORITHM = os.environ.get("JWT_ALGORITHM", "HS256")
_EXPIRATION = int(os.environ.get("JWT_EXPIRATION", "3600"))


def create_token(user_id: int, firebase_uid: str) -> str:
    """Create a signed backend JWT for the given user."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "uid": firebase_uid,
        "iat": now,
        "exp": now + timedelta(seconds=_EXPIRATION),
    }
    token = jwt.encode(payload, _SECRET, algorithm=_ALGORITHM)
    logger.debug(f"create_token | user_id={user_id}")
    return token


def decode_token(token: str) -> dict:
    """Decode and verify a backend JWT. Raises AuthError on failure."""
    try:
        payload = jwt.decode(token, _SECRET, algorithms=[_ALGORITHM])
        return payload
    except JWTError as e:
        logger.warning(f"decode_token | invalid token: {e}")
        raise AuthError("Invalid or expired token")
