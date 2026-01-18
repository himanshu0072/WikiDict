# Performance Optimizations

## Overview
This document outlines the performance optimizations implemented to reduce API response times from ~1.5s to sub-second.

## Current Performance Issues

Based on testing with 5 sample queries:
- **Queries 1-4**: 0.97s - 1.16s (acceptable but could be better)
- **Query 5**: 60.9s (CRITICAL - indicates timeout/retry issues)

## Implemented Optimizations

### 1. S3 Client Connection Pooling

**Problem**: Creating new S3 client on every request causes connection overhead.

**Solution**:
- Added `botocore.Config` with connection pooling
- Reuse module-level S3 client instance
- Configuration:
  ```python
  config = Config(
      retries={'max_attempts': 3, 'mode': 'adaptive'},
      connect_timeout=5,
      read_timeout=30,
      max_pool_connections=50
  )
  ```

**Impact**: Reduces connection establishment time for subsequent requests.

**File**: [src/utils/utils.py:11-29](../src/utils/utils.py#L11-L29)

### 2. LRU Cache for S3 Reads

**Problem**: Repeated queries for the same word fetch from S3 every time.

**Solution**:
- Added `@lru_cache(maxsize=1000)` decorator to `read_meaning_from_s3`
- Caches up to 1000 most recently used word meanings
- Cache key: (offset, length, file_key)

**Impact**: Instant response for cached words (0ms S3 latency).

**File**: [src/utils/utils.py:42](../src/utils/utils.py#L42)

### 3. Configured Timeouts

**Problem**: Default AWS SDK timeouts are too long (60s observed).

**Solution**:
- Connect timeout: 5s
- Read timeout: 30s
- Adaptive retry mode with max 3 attempts

**Impact**: Faster failure detection and retry logic.

## Recommended Additional Optimizations

### 4. Response Compression (TODO)

Add gzip middleware to compress large meaning responses:

```python
# In main.py
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)
```

**Expected Impact**: ~70% reduction in response size for text data.

### 5. Add Request Timing Middleware (TODO)

Track performance metrics per request:

```python
@app.middleware("http")
async def add_timing_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response
```

### 6. Database/Redis Cache Layer (Future)

For production, consider:
- Redis cache for hot words (top 10k queries)
- TTL: 24 hours
- Cache warming on startup

### 7. CDN + S3 Transfer Acceleration (Future)

- Enable S3 Transfer Acceleration for faster global access
- Use CloudFront CDN for static dictionary data
- Expected: 2-5x faster S3 reads globally

## Testing Commands

Test with sample queries:
```bash
curl -w "\nTime: %{time_total}s\n" 'http://localhost:8000/api/v1/search?word=a%20nearly%20billion'
curl -w "\nTime: %{time_total}s\n" 'http://localhost:8000/api/v1/search?word=A%20of%20where'
curl -w "\nTime: %{time_total}s\n" 'http://localhost:8000/api/v1/search?word=A%20well%20recently%20stuff%20memory%20create'
curl -w "\nTime: %{time_total}s\n" 'http://localhost:8000/api/v1/search?word=a-protect'
curl -w "\nTime: %{time_total}s\n" 'http://localhost:8000/api/v1/search?word=Roberthaven%20North%20Shannonbury'
```

## Expected Results After Optimization

- **First request**: 0.5-1.0s (S3 fetch + processing)
- **Cached requests**: 0.01-0.05s (cache hit)
- **No timeouts**: All requests complete within 5s worst case

## Monitoring

Track these metrics in production:
- P50, P95, P99 response times
- Cache hit rate
- S3 error rate
- Timeout frequency
