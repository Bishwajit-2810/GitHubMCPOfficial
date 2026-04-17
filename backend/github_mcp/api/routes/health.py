"""Health and readiness endpoints."""

from fastapi import APIRouter
from sqlalchemy import text
from loguru import logger

from ..db import SessionLocal

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/ready")
def ready():
    """Check DB connectivity for readiness probe."""
    db_ok = False
    db = None
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db_ok = True
    except Exception as e:
        logger.warning(f"readiness | db check failed: {e}")
    finally:
        if db is not None:
            db.close()

    if not db_ok:
        from fastapi import HTTPException
        raise HTTPException(status_code=503, detail="Database not ready")

    return {"status": "ready", "db": "ok"}
