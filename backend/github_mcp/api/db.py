"""Database session and engine setup."""

import os
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from loguru import logger


class Base(DeclarativeBase):
    pass


def _get_engine():
    url = os.environ.get("POSTGRES_URL", "")
    if not url:
        raise RuntimeError("POSTGRES_URL is not set.")
    logger.debug(f"db | connecting to postgres")
    return create_engine(url, pool_pre_ping=True, pool_size=5, max_overflow=10)


engine = _get_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@contextmanager
def get_db():
    """Context manager yielding a SQLAlchemy session; rolls back on error."""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def get_db_dep():
    """FastAPI dependency that yields a db session."""
    with get_db() as db:
        yield db
