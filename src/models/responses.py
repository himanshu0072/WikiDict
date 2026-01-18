"""
Standard Response Models

Following industry best practices for API responses.
"""

from typing import Generic, TypeVar, Optional
from pydantic import BaseModel, Field
from datetime import datetime

# Generic type for data
T = TypeVar('T')


class SuccessResponse(BaseModel, Generic[T]):
    """
    Standard success response wrapper.

    Follows a combination of JSend and Google's JSON style guide.
    Accepts additional fields like result_count, pagination info, etc.
    """
    status: str = Field(default="success", description="Response status")
    data: T = Field(..., description="Response data")
    message: Optional[str] = Field(None, description="Optional success message")
    timestamp: Optional[datetime] = Field(None, description="Response timestamp")
    request_id: Optional[str] = Field(None, description="Request tracking ID")

    class Config:
        extra = "allow"  # Allow additional fields like result_count
        json_schema_extra = {
            "example": {
                "status": "success",
                "data": {
                    "word": "test",
                    "meaning": "example"
                },
                "message": "Word found successfully",
                "timestamp": "2024-01-18T10:30:00Z",
                "request_id": "req_123456789",
                "result_count": 10
            }
        }



class ListResponse(BaseModel, Generic[T]):
    """
    Standard response for list/collection endpoints.

    Includes pagination metadata.
    """
    status: str = Field(default="success", description="Response status")
    data: list[T] = Field(..., description="List of items")
    message: Optional[str] = Field(None, description="Optional message")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "success",
                "data": [
                    {"word": "test1", "meaning": "..."},
                    {"word": "test2", "meaning": "..."}
                ],
                "message": "Data fetched successfully"
            }
        }


class MessageResponse(BaseModel):
    """
    Simple message response for operations without data.

    Use for: DELETE, UPDATE operations, status checks, etc.
    """
    status: str = Field(default="success", description="Response status")
    message: str = Field(..., description="Response message")
    timestamp: Optional[datetime] = Field(None, description="Response timestamp")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "success",
                "message": "Resource deleted successfully",
                "timestamp": "2024-01-18T10:30:00Z"
            }
        }
