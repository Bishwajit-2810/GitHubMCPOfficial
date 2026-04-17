"""Custom exceptions and error envelope for the FastAPI BFF."""

from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse
from loguru import logger


class AppError(HTTPException):
    def __init__(self, code: str, message: str, details: dict | None = None, status_code: int = 400):
        self.code = code
        self.details = details or {}
        super().__init__(status_code=status_code, detail=message)


class AuthError(AppError):
    def __init__(self, message: str = "Unauthorized", code: str = "AUTH_ERROR"):
        super().__init__(code=code, message=message, status_code=401)


class ForbiddenError(AppError):
    def __init__(self, message: str = "Forbidden", code: str = "FORBIDDEN"):
        super().__init__(code=code, message=message, status_code=403)


class NotFoundError(AppError):
    def __init__(self, message: str = "Not found", code: str = "NOT_FOUND"):
        super().__init__(code=code, message=message, status_code=404)


class ConflictError(AppError):
    def __init__(self, message: str = "Conflict", code: str = "CONFLICT"):
        super().__init__(code=code, message=message, status_code=409)


def _error_envelope(code: str, message: str, details: dict | None = None) -> dict:
    return {"error": {"code": code, "message": message, "details": details or {}}}


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    logger.warning(f"AppError [{exc.code}] {exc.detail} | path={request.url.path}")
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_envelope(exc.code, str(exc.detail), exc.details),
    )


async def generic_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception(f"Unhandled error | path={request.url.path}")
    return JSONResponse(
        status_code=500,
        content=_error_envelope("INTERNAL_ERROR", "An unexpected error occurred"),
    )


async def http_error_handler(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_envelope("HTTP_ERROR", str(exc.detail)),
    )
