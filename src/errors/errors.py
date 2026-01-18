"""
Standard Error Response Models and Exception Handlers

Following RFC 7807 (Problem Details for HTTP APIs) and OpenAPI standards.
"""

from typing import Any, Dict, Optional
from fastapi import status
from pydantic import BaseModel, Field


class ErrorDetail(BaseModel):
    """Individual error detail for validation errors."""
    loc: list[str | int] = Field(..., description="Location of the error (field path)")
    msg: str = Field(..., description="Error message")
    type: str = Field(..., description="Error type")


class ErrorResponse(BaseModel):
    """
    Standard error response following RFC 7807.

    This format is consistent with OpenAPI standards and provides
    detailed error information to clients.
    """
    type: str = Field(
        ...,
        description="A URI reference that identifies the problem type",
        example="https://api.example.com/errors/not-found"
    )
    title: str = Field(
        ...,
        description="A short, human-readable summary of the problem",
        example="Resource Not Found"
    )
    status: int = Field(
        ...,
        description="The HTTP status code",
        example=404
    )
    detail: str = Field(
        ...,
        description="A human-readable explanation specific to this occurrence",
        example="The requested word 'xyz' was not found in the dictionary"
    )
    instance: Optional[str] = Field(
        None,
        description="A URI reference that identifies the specific occurrence",
        example="/api/v1/search?word=xyz"
    )
    errors: Optional[list[ErrorDetail]] = Field(
        None,
        description="Additional validation errors (for 422 responses)"
    )
    request_id: Optional[str] = Field(
        None,
        description="Unique request identifier for tracking"
    )
    timestamp: Optional[str] = Field(
        None,
        description="ISO 8601 timestamp of when the error occurred"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "type": "https://api.example.com/errors/not-found",
                "title": "Resource Not Found",
                "status": 404,
                "detail": "The requested word was not found in the dictionary",
                "instance": "/api/v1/search?word=xyz",
                "request_id": "req_123456789",
                "timestamp": "2024-01-18T10:30:00Z"
            }
        }


class AppException(Exception):
    """
    Base application exception that can be converted to ErrorResponse.

    All custom exceptions should inherit from this class.
    """
    def __init__(
        self,
        status_code: int,
        title: str,
        detail: str,
        error_type: Optional[str] = None,
        errors: Optional[list[Dict[str, Any]]] = None
    ):
        self.status_code = status_code
        self.title = title
        self.detail = detail
        self.error_type = error_type or f"error_{status_code}"
        self.errors = errors
        super().__init__(detail)


# Common HTTP Exception Classes

class BadRequestException(AppException):
    """400 Bad Request - Client sent invalid request."""
    def __init__(self, detail: str, errors: Optional[list[Dict[str, Any]]] = None):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            title="Bad Request",
            detail=detail,
            error_type="bad_request",
            errors=errors
        )


class UnauthorizedException(AppException):
    """401 Unauthorized - Authentication required."""
    def __init__(self, detail: str = "Authentication required"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            title="Unauthorized",
            detail=detail,
            error_type="unauthorized"
        )


class ForbiddenException(AppException):
    """403 Forbidden - Client doesn't have permission."""
    def __init__(self, detail: str = "Access forbidden"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            title="Forbidden",
            detail=detail,
            error_type="forbidden"
        )


class NotFoundException(AppException):
    """404 Not Found - Resource doesn't exist."""
    def __init__(self, detail: str, resource: Optional[str] = None):
        detail_msg = detail if not resource else f"{resource} not found: {detail}"
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            title="Not Found",
            detail=detail_msg,
            error_type="not_found"
        )


class ConflictException(AppException):
    """409 Conflict - Request conflicts with current state."""
    def __init__(self, detail: str):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            title="Conflict",
            detail=detail,
            error_type="conflict"
        )


class ValidationException(AppException):
    """422 Unprocessable Entity - Validation failed."""
    def __init__(self, detail: str, errors: list[Dict[str, Any]]):
        super().__init__(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            title="Validation Error",
            detail=detail,
            error_type="validation_error",
            errors=errors
        )


class TooManyRequestsException(AppException):
    """429 Too Many Requests - Rate limit exceeded."""
    def __init__(self, detail: str = "Rate limit exceeded", retry_after: Optional[int] = None):
        detail_msg = detail
        if retry_after:
            detail_msg += f". Retry after {retry_after} seconds"
        super().__init__(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            title="Too Many Requests",
            detail=detail_msg,
            error_type="rate_limit_exceeded"
        )


class InternalServerException(AppException):
    """500 Internal Server Error - Unexpected server error."""
    def __init__(self, detail: str = "An unexpected error occurred"):
        super().__init__(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            title="Internal Server Error",
            detail=detail,
            error_type="internal_error"
        )


class ServiceUnavailableException(AppException):
    """503 Service Unavailable - Service temporarily unavailable."""
    def __init__(self, detail: str = "Service temporarily unavailable"):
        super().__init__(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            title="Service Unavailable",
            detail=detail,
            error_type="service_unavailable"
        )
