"""
Exception Handlers for FastAPI Application

Handles all exceptions and converts them to standard ErrorResponse format.
"""

import traceback
from datetime import datetime, timezone
from typing import Union, Optional
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from .errors import AppException, ErrorResponse, ErrorDetail
from src.config import app_settings

def generate_error_type_url(error_type: str, base_url: str = app_settings.base_url) -> str:
    """Generate a URI reference for the error type."""
    return f"{base_url}/errors/{error_type}"


def create_error_response(
    request: Request,
    status_code: int,
    title: str,
    detail: str,
    error_type: str,
    errors: Optional[list[ErrorDetail]] = None
) -> ErrorResponse:
    """Create a standardized error response."""
    # Get request ID from request state (set by middleware) or headers
    request_id = getattr(request.state, "request_id", None) or request.headers.get("X-Request-ID")

    return ErrorResponse(
        type=generate_error_type_url(error_type),
        title=title,
        status=status_code,
        detail=detail,
        instance=str(request.url.path),
        errors=errors,
        request_id=request_id,
        timestamp=datetime.now(timezone.utc).isoformat()
    )


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """
    Handle custom AppException and its subclasses.

    Converts AppException to standard ErrorResponse format.
    """
    errors = None
    if exc.errors:
        errors = [
            ErrorDetail(
                loc=error.get("loc", []),
                msg=error.get("msg", ""),
                type=error.get("type", "value_error")
            )
            for error in exc.errors
        ]

    error_response = create_error_response(
        request=request,
        status_code=exc.status_code,
        title=exc.title,
        detail=exc.detail,
        error_type=exc.error_type,
        errors=errors
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.model_dump(exclude_none=True)
    )


async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError
) -> JSONResponse:
    """
    Handle Pydantic validation errors (422 Unprocessable Entity).

    Converts FastAPI validation errors to standard ErrorResponse format.
    """
    errors = [
        ErrorDetail(
            loc=[str(loc) for loc in error["loc"]],
            msg=error["msg"],
            type=error["type"]
        )
        for error in exc.errors()
    ]

    error_response = create_error_response(
        request=request,
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        title="Validation Error",
        detail="Request validation failed. Please check your input.",
        error_type="validation_error",
        errors=errors
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=error_response.model_dump(exclude_none=True)
    )


async def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException
) -> JSONResponse:
    """
    Handle standard HTTP exceptions (from FastAPI/Starlette).

    Converts HTTPException to standard ErrorResponse format.
    """
    # Map status codes to error types
    error_type_map = {
        400: "bad_request",
        401: "unauthorized",
        403: "forbidden",
        404: "not_found",
        405: "method_not_allowed",
        409: "conflict",
        422: "validation_error",
        429: "rate_limit_exceeded",
        500: "internal_error",
        502: "bad_gateway",
        503: "service_unavailable",
        504: "gateway_timeout",
    }

    title_map = {
        400: "Bad Request",
        401: "Unauthorized",
        403: "Forbidden",
        404: "Not Found",
        405: "Method Not Allowed",
        409: "Conflict",
        422: "Unprocessable Entity",
        429: "Too Many Requests",
        500: "Internal Server Error",
        502: "Bad Gateway",
        503: "Service Unavailable",
        504: "Gateway Timeout",
    }

    error_type = error_type_map.get(exc.status_code, f"error_{exc.status_code}")
    title = title_map.get(exc.status_code, "Error")

    error_response = create_error_response(
        request=request,
        status_code=exc.status_code,
        title=title,
        detail=str(exc.detail),
        error_type=error_type
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.model_dump(exclude_none=True)
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Handle all unhandled exceptions (500 Internal Server Error).

    This is a catch-all handler for any unexpected exceptions.
    """
    # Log the full traceback for debugging
    print(f"Unhandled exception: {exc}")
    print(traceback.format_exc())

    # Don't expose internal error details to clients in production
    detail = "An unexpected error occurred. Please try again later."

    # In development, you might want to include more details
    # Uncomment the line below for development:
    # detail = f"Internal error: {str(exc)}"

    error_response = create_error_response(
        request=request,
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        title="Internal Server Error",
        detail=detail,
        error_type="internal_error"
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_response.model_dump(exclude_none=True)
    )
