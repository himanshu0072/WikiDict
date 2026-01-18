# Standard Error Response System

This module provides a standardized error response format following **RFC 7807 (Problem Details for HTTP APIs)** and OpenAPI standards.

## Error Response Format

All errors follow this consistent JSON structure:

```json
{
  "type": "https://api.example.com/errors/not_found",
  "title": "Not Found",
  "status": 404,
  "detail": "Word 'xyz' not found in dictionary",
  "instance": "/api/v1/search?word=xyz",
  "request_id": "req_123456789",
  "timestamp": "2024-01-18T10:30:00Z",
  "errors": [
    {
      "loc": ["query", "word"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

## Available Exception Classes

### 1. BadRequestException (400)
Use when the client sends invalid or malformed data.

```python
from src.errors import BadRequestException

@router.post("/search")
async def search(data: dict):
    if not data.get("word"):
        raise BadRequestException(detail="Word parameter is required")
```

### 2. UnauthorizedException (401)
Use when authentication is required but not provided.

```python
from src.errors import UnauthorizedException

@router.get("/protected")
async def protected_endpoint(token: str):
    if not token:
        raise UnauthorizedException(detail="Please provide authentication token")
```

### 3. ForbiddenException (403)
Use when user is authenticated but doesn't have permission.

```python
from src.errors import ForbiddenException

@router.delete("/admin")
async def admin_action(user: User):
    if not user.is_admin:
        raise ForbiddenException(detail="Admin access required")
```

### 4. NotFoundException (404)
Use when a requested resource doesn't exist.

```python
from src.errors import NotFoundException

@router.get("/word/{word_id}")
async def get_word(word_id: str):
    word = db.get_word(word_id)
    if not word:
        raise NotFoundException(
            detail=f"Word with ID '{word_id}' not found",
            resource="Word"
        )
```

### 5. ConflictException (409)
Use when the request conflicts with the current state.

```python
from src.errors import ConflictException

@router.post("/users")
async def create_user(email: str):
    if user_exists(email):
        raise ConflictException(detail=f"User with email '{email}' already exists")
```

### 6. ValidationException (422)
Use for complex validation errors with multiple fields.

```python
from src.errors import ValidationException

@router.post("/submit")
async def submit_data(data: dict):
    errors = validate_data(data)
    if errors:
        raise ValidationException(
            detail="Data validation failed",
            errors=[
                {"loc": ["body", "email"], "msg": "invalid email", "type": "value_error"},
                {"loc": ["body", "age"], "msg": "must be >= 18", "type": "value_error"}
            ]
        )
```

### 7. TooManyRequestsException (429)
Use when rate limiting is exceeded.

```python
from src.errors import TooManyRequestsException

@router.get("/api")
async def api_endpoint():
    if rate_limit_exceeded():
        raise TooManyRequestsException(
            detail="Rate limit exceeded",
            retry_after=60
        )
```

### 8. InternalServerException (500)
Use for unexpected server errors (use sparingly).

```python
from src.errors import InternalServerException

@router.get("/data")
async def get_data():
    try:
        return process_data()
    except CriticalError as e:
        raise InternalServerException(detail="Failed to process data")
```

### 9. ServiceUnavailableException (503)
Use when the service is temporarily down.

```python
from src.errors import ServiceUnavailableException

@router.get("/status")
async def check_status():
    if not db.is_healthy():
        raise ServiceUnavailableException(detail="Database temporarily unavailable")
```

## Using with Response Models

Document your API responses in the OpenAPI spec:

```python
from src.errors import ErrorResponse

@router.get(
    "/search",
    response_model=SearchResponse,
    responses={
        200: {"description": "Success", "model": SearchResponse},
        400: {"description": "Bad Request", "model": ErrorResponse},
        404: {"description": "Not Found", "model": ErrorResponse},
        500: {"description": "Internal Error", "model": ErrorResponse},
    }
)
async def search(word: str):
    # Your logic here
    pass
```

## Custom Exception

Create custom exceptions by extending `AppException`:

```python
from src.errors import AppException
from fastapi import status

class CustomException(AppException):
    def __init__(self, detail: str):
        super().__init__(
            status_code=status.HTTP_418_IM_A_TEAPOT,
            title="I'm a teapot",
            detail=detail,
            error_type="teapot_error"
        )

# Usage
raise CustomException(detail="This is a teapot, not a coffee maker")
```

## Exception Handlers

All exceptions are automatically caught and converted to the standard format by these handlers:

1. **app_exception_handler**: Handles all `AppException` subclasses
2. **validation_exception_handler**: Handles Pydantic validation errors (422)
3. **http_exception_handler**: Handles standard FastAPI HTTPException
4. **generic_exception_handler**: Catches any unhandled exceptions (500)

These are registered in `main.py` and work automatically.

## Testing Error Responses

Example error responses:

**404 Not Found:**
```bash
GET /api/v1/search?word=nonexistent

Response (404):
{
  "type": "https://api.example.com/errors/not_found",
  "title": "Not Found",
  "status": 404,
  "detail": "Word 'nonexistent' not found in dictionary",
  "instance": "/api/v1/search",
  "timestamp": "2024-01-18T10:30:00Z"
}
```

**422 Validation Error:**
```bash
GET /api/v1/search

Response (422):
{
  "type": "https://api.example.com/errors/validation_error",
  "title": "Validation Error",
  "status": 422,
  "detail": "Request validation failed. Please check your input.",
  "instance": "/api/v1/search",
  "timestamp": "2024-01-18T10:30:00Z",
  "errors": [
    {
      "loc": ["query", "word"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

## Best Practices

1. **Use specific exceptions**: Choose the most appropriate exception class for the situation
2. **Provide clear messages**: Write helpful error messages that guide users
3. **Include context**: Use the `resource` parameter in NotFoundException
4. **Don't expose internals**: Never include stack traces or sensitive data in production
5. **Log errors**: Always log 500 errors for debugging
6. **Test error cases**: Write tests for error scenarios
7. **Document errors**: Include error responses in OpenAPI documentation

## Error Type URLs

Error types follow this pattern:
```
https://api.example.com/errors/{error_type}
```

You can customize the base URL in `handlers.py`:
```python
generate_error_type_url(error_type, base_url="https://yourdomain.com")
```
