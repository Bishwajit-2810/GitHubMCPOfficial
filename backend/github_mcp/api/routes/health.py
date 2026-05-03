"""Health and readiness endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from loguru import logger

from ..db import get_db_dep

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/ready")
def ready(db: Session = Depends(get_db_dep)):
    """Check DB connectivity for readiness probe."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        logger.warning(f"readiness | db check failed: {e}")
        raise HTTPException(status_code=503, detail="Database not ready")

    return {"status": "ready", "db": "ok"}
