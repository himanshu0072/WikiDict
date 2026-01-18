"""
SM-WikiDict FastAPI Server
"""

import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.gzip import GZipMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException
from src.controller import health_router, search_router
from src.config import app_settings
from src.config.load_indexes import get_index_loader
from src.errors import (
    AppException,
    app_exception_handler,
    validation_exception_handler,
    http_exception_handler,
    generic_exception_handler,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager for startup and shutdown events."""
    # Startup: Load index from S3
    try:
        loader = get_index_loader()
        print(f"✓ Server ready with {len(loader.indexes):,} entries loaded")
    except Exception as e:
        print(f"✗ Failed to load index: {e}")
        raise
    yield
    # Shutdown: cleanup if needed
    print("Server shutting down")


app = FastAPI(
    title=app_settings.service_name,
    description=app_settings.description,
    version=app_settings.version,
    lifespan=lifespan,
)

app.router.prefix = app_settings.api_prefix

# Add gzip compression for responses larger than 0.5KB
app.add_middleware(GZipMiddleware, minimum_size=500)

# Add timing middleware for performance monitoring
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    """Add X-Process-Time header to track request processing time."""
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = f"{process_time:.4f}"
    return response

# Register exception handlers
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(StarletteHTTPException, http_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

# Register routers
app.include_router(health_router)
app.include_router(search_router)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=app_settings.host,
        port=app_settings.port,
        reload=app_settings.debug
    )
