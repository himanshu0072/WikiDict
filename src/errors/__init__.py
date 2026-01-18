"""
Error handling module for standardized API error responses.
"""

from .errors import (
    ErrorResponse,
    ErrorDetail,
    AppException,
    BadRequestException,
    UnauthorizedException,
    ForbiddenException,
    NotFoundException,
    ConflictException,
    ValidationException,
    TooManyRequestsException,
    InternalServerException,
    ServiceUnavailableException,
)

from .handlers import (
    app_exception_handler,
    validation_exception_handler,
    http_exception_handler,
    generic_exception_handler,
)

__all__ = [
    # Error models
    "ErrorResponse",
    "ErrorDetail",
    # Base exception
    "AppException",
    # Specific exceptions
    "BadRequestException",
    "UnauthorizedException",
    "ForbiddenException",
    "NotFoundException",
    "ConflictException",
    "ValidationException",
    "TooManyRequestsException",
    "InternalServerException",
    "ServiceUnavailableException",
    # Handlers
    "app_exception_handler",
    "validation_exception_handler",
    "http_exception_handler",
    "generic_exception_handler",
]
