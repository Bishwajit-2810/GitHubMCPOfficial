"""FastAPI BFF — runs on port 8091, wraps MCP tools with Firebase auth.

Start: python api_server.py
Or:    uvicorn api_server:app --host 0.0.0.0 --port 8091 --reload
"""

import os
import sys

from dotenv import load_dotenv

load_dotenv()

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from github_mcp.api.exceptions import (
    AppError,
    app_error_handler,
    generic_error_handler,
    http_error_handler,
)
from github_mcp.api.routes.health import router as health_router
from github_mcp.api.routes.auth_routes import router as auth_router
from github_mcp.api.routes.tool_routes import router as tool_router

# ── Logging ───────────────────────────────────────────────────────────────────
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> — <level>{message}</level>",
    level=os.environ.get("LOG_LEVEL", "INFO"),
    colorize=True,
)

# ── Rate limiter ──────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("FastAPI BFF starting on port 8091")
    logger.info("Docs: http://0.0.0.0:8091/docs")
    yield


# ── App factory ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="GitHub MCP BFF",
    version="2.0.0",
    description="FastAPI backend-for-frontend wrapping GitHub MCP tools with Firebase auth.",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# Rate limiting state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS ──────────────────────────────────────────────────────────────────────
_origins = os.environ.get("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in _origins],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Exception handlers ────────────────────────────────────────────────────────
app.add_exception_handler(AppError, app_error_handler)
app.add_exception_handler(HTTPException, http_error_handler)
app.add_exception_handler(Exception, generic_error_handler)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(health_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(tool_router, prefix="/api/v1")


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    import uvicorn

    parser = argparse.ArgumentParser(description="GitHub MCP FastAPI BFF")
    parser.add_argument("--port", type=int, default=int(os.environ.get("API_PORT", 8091)))
    parser.add_argument("--host", default=os.environ.get("API_HOST", "0.0.0.0"))
    parser.add_argument("--reload", action="store_true", default=False)
    args = parser.parse_args()

    logger.info(f"Starting BFF → http://{args.host}:{args.port}")
    uvicorn.run("api_server:app", host=args.host, port=args.port, reload=args.reload)
