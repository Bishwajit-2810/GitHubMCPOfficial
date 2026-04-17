"""Firebase Admin SDK initialisation and ID-token verification."""

import os

from loguru import logger

from .exceptions import AuthError

_app = None


def _get_firebase_app():
    """Lazily initialise the Firebase Admin app (singleton)."""
    global _app
    if _app is not None:
        return _app

    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        raise RuntimeError("firebase-admin is not installed. Run: uv add firebase-admin")

    if firebase_admin._apps:
        _app = firebase_admin.get_app()
        return _app

    sa_path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "")
    project_id = os.environ.get("FIREBASE_PROJECT_ID", "")

    if sa_path and os.path.exists(sa_path):
        cred = credentials.Certificate(sa_path)
        logger.info(f"firebase | initialising with service account: {sa_path}")
    elif project_id:
        cred = credentials.ApplicationDefault()
        logger.info(f"firebase | initialising with application default credentials, project={project_id}")
    else:
        raise RuntimeError(
            "Firebase not configured. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_PROJECT_ID."
        )

    _app = firebase_admin.initialize_app(cred)
    return _app


def verify_firebase_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return the decoded claims dict.

    Returns keys: uid, email, name, picture (when present).
    Raises AuthError on invalid/expired tokens.
    """
    try:
        from firebase_admin import auth
        _get_firebase_app()
        claims = auth.verify_id_token(id_token)
        logger.debug(f"firebase | verified token uid={claims.get('uid')}")
        return claims
    except Exception as e:
        logger.warning(f"firebase | token verification failed: {e}")
        raise AuthError(f"Firebase token invalid: {e}")
