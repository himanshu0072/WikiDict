# Request ID Tracking

## Overview

Every HTTP request to the API is assigned a unique Request ID for tracking, debugging, and correlation across logs and systems.

---

## How It Works

### Request ID Generation

1. **Client provides ID (Optional)**
   ```bash
   curl -H "X-Request-ID: custom-id-123" \
        https://api.example.com/api/v1/search?word=test
   ```

2. **Server generates ID (Automatic)**
   - Format: `req_` + 16-character hex UUID
   - Example: `req_a1b2c3d4e5f6g7h8`

### Request ID Flow

```
Client Request
     │
     ├─ Has X-Request-ID header?
     │  ├─ YES → Use client-provided ID
     │  └─ NO  → Generate new UUID
     │
     ├─ Store in request.state.request_id
     │
     ├─ Process request
     │
     └─ Add X-Request-ID to response headers
```

---

## Usage

### 1. Success Responses

Request ID is included in both response **headers** and **body**:

**Request:**
```bash
curl -i "http://localhost:8000/api/v1/search?word=test"
```

**Response:**
```http
HTTP/1.1 200 OK
X-Request-ID: req_a1b2c3d4e5f6g7h8
X-Process-Time: 0.3145
Content-Type: application/json

{
  "status": "success",
  "data": {
    "word": "test",
    "meaning": "..."
  },
  "message": "Word found successfully",
  "request_id": "req_a1b2c3d4e5f6g7h8",
  "timestamp": "2026-01-18T10:30:00Z"
}
```

### 2. Error Responses

Request ID helps track errors across logs:

**Request:**
```bash
curl -i "http://localhost:8000/api/v1/search?word=nonexistent"
```

**Response:**
```http
HTTP/1.1 404 Not Found
X-Request-ID: req_b2c3d4e5f6g7h8i9
Content-Type: application/json

{
  "type": "http://localhost:8000/errors/not_found",
  "title": "Not Found",
  "status": 404,
  "detail": "Word not found: Word 'nonexistent' not found in dictionary",
  "instance": "/api/v1/search",
  "request_id": "req_b2c3d4e5f6g7h8i9",
  "timestamp": "2026-01-18T10:31:00Z"
}
```

### 3. Client-Provided Request ID

Useful for distributed tracing:

```bash
# Frontend generates ID
TRACE_ID="frontend-trace-$(uuidgen)"

# Include in API call
curl -H "X-Request-ID: $TRACE_ID" \
     "http://localhost:8000/api/v1/search?word=test"
```

Server will use `frontend-trace-xxx` as the request ID throughout the request lifecycle.

---

## Benefits

### 1. Debugging & Troubleshooting

**Scenario:** User reports error at 10:30 AM

```bash
# User provides request ID from error response
# You can search logs for that exact request
grep "req_a1b2c3d4e5f6g7h8" logs/app.log

# See full request lifecycle:
# [2026-01-18 10:30:15] req_a1b2c3d4e5f6g7h8 - GET /api/v1/search?word=test
# [2026-01-18 10:30:15] req_a1b2c3d4e5f6g7h8 - Cache miss
# [2026-01-18 10:30:15] req_a1b2c3d4e5f6g7h8 - S3 fetch started
# [2026-01-18 10:30:16] req_a1b2c3d4e5f6g7h8 - ERROR: S3 timeout
```

### 2. Distributed Tracing

**Multi-service architecture:**

```
Frontend (Web App)
    ├─ X-Request-ID: frontend-trace-123
    │
    ├─> Dictionary API (this service)
    │   ├─ Uses: frontend-trace-123
    │   └─> S3 API
    │       └─ Logs: frontend-trace-123
    │
    └─> Analytics Service
        └─ Uses: frontend-trace-123
```

All services use the same request ID, making it easy to trace requests across the entire system.

### 3. Rate Limiting & Monitoring

```python
# Track requests per user/client
SELECT client_id, COUNT(*)
FROM requests
WHERE date = '2026-01-18'
GROUP BY client_id;

# Find slow requests
SELECT request_id, duration
FROM requests
WHERE duration > 1.0
ORDER BY duration DESC;
```

### 4. Error Correlation

**Before (without request ID):**
```
User: "I got an error around 10:30"
Dev: "Which endpoint? What data? Can you reproduce?"
```

**After (with request ID):**
```
User: "Error with request ID: req_a1b2c3d4e5f6g7h8"
Dev: "Found it! S3 timeout. Fixed."
```

---

## Implementation Details

### Middleware Code

```python
@app.middleware("http")
async def add_request_id(request: Request, call_next):
    """Add unique request ID to each request."""
    # Check for client-provided ID
    request_id = request.headers.get("X-Request-ID")

    # Generate if not provided
    if not request_id:
        request_id = f"req_{uuid.uuid4().hex[:16]}"

    # Store in request state
    request.state.request_id = request_id

    # Process request
    response = await call_next(request)

    # Add to response
    response.headers["X-Request-ID"] = request_id

    return response
```

### Accessing Request ID

**In route handlers:**
```python
async def my_endpoint(request: Request):
    request_id = request.state.request_id
    logger.info(f"{request_id} - Processing request")
```

**In error handlers:**
```python
request_id = getattr(request.state, "request_id", None)
```

---

## Best Practices

### 1. Always Include in Error Reports

❌ **Bad:**
```json
{
  "error": "Something went wrong"
}
```

✅ **Good:**
```json
{
  "error": "Something went wrong",
  "request_id": "req_a1b2c3d4e5f6g7h8",
  "timestamp": "2026-01-18T10:30:00Z"
}
```

### 2. Use Consistent Format

✅ **Recommended formats:**
- Server-generated: `req_{16-char-hex}` (e.g., `req_a1b2c3d4e5f6g7h8`)
- Client-generated: `{service}-{uuid}` (e.g., `frontend-550e8400-e29b-41d4-a716-446655440000`)

### 3. Log Request ID in All Log Entries

```python
import logging

logger = logging.getLogger(__name__)

async def process_request(request: Request):
    request_id = request.state.request_id

    logger.info(f"{request_id} - Started processing")
    # ... processing ...
    logger.info(f"{request_id} - Completed in 0.3s")
```

### 4. Include in External API Calls

When calling other services, propagate the request ID:

```python
import httpx

async def fetch_external_data(request: Request):
    request_id = request.state.request_id

    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://external-api.com/data",
            headers={"X-Request-ID": request_id}
        )
```

---

## Monitoring & Analytics

### CloudWatch Insights Queries

**Find all requests for a specific ID:**
```
fields @timestamp, @message
| filter @message like /req_a1b2c3d4e5f6g7h8/
| sort @timestamp asc
```

**Find slow requests:**
```
fields request_id, duration
| filter duration > 1000
| sort duration desc
| limit 20
```

**Error rate by request ID pattern:**
```
fields request_id, status
| filter status >= 400
| stats count() by status
```

---

## Security Considerations

### 1. No Sensitive Data in Request ID

❌ **Never include:**
- User IDs
- API keys
- Personal information
- Session tokens

❌ **Bad:** `req_user123_session456`

✅ **Good:** `req_a1b2c3d4e5f6g7h8`

### 2. Validate Client-Provided IDs

```python
import re

def validate_request_id(request_id: str) -> bool:
    # Max length: 64 characters
    if len(request_id) > 64:
        return False

    # Allow alphanumeric, hyphens, underscores
    if not re.match(r'^[a-zA-Z0-9_-]+$', request_id):
        return False

    return True
```

### 3. Rate Limit by Request ID

Prevent abuse by tracking requests per ID:

```python
from collections import defaultdict
from datetime import datetime, timedelta

request_counts = defaultdict(list)

def check_rate_limit(request_id: str, max_requests: int = 100) -> bool:
    now = datetime.now()
    cutoff = now - timedelta(minutes=1)

    # Clean old requests
    request_counts[request_id] = [
        t for t in request_counts[request_id] if t > cutoff
    ]

    # Check limit
    if len(request_counts[request_id]) >= max_requests:
        return False

    # Record request
    request_counts[request_id].append(now)
    return True
```

---

## FAQ

**Q: Should I generate request IDs on the client or server?**

A: Both approaches work:
- **Client-generated:** Better for distributed tracing across multiple services
- **Server-generated:** Simpler, works without client cooperation

**Q: What if the client sends a duplicate request ID?**

A: The server will use it as-is. This is intentional for request retries and idempotency.

**Q: How long should I store request IDs in logs?**

A: Recommendation:
- Hot storage (searchable): 7-30 days
- Cold storage (archived): 90-365 days (compliance-dependent)

**Q: Can I use request IDs for idempotency?**

A: Yes! Common pattern:

```python
from functools import lru_cache

@lru_cache(maxsize=1000)
def is_duplicate_request(request_id: str) -> bool:
    # Check if already processed
    return db.exists(request_id)

async def create_resource(request: Request, data: dict):
    request_id = request.state.request_id

    if is_duplicate_request(request_id):
        return {"status": "already_processed"}

    # Process request
    result = await process(data)
    db.save(request_id, result)
    return result
```

---

## Summary

✅ **Request ID tracking provides:**
- Unique identifier for every request
- Easy debugging and troubleshooting
- Distributed tracing capabilities
- Error correlation across systems
- Audit trail for compliance

✅ **Implementation:**
- Automatic generation via middleware
- Optional client-provided IDs
- Included in all responses (success & error)
- Available throughout request lifecycle

✅ **Best for:**
- Production debugging
- Multi-service architectures
- Error tracking and monitoring
- Request deduplication
- Compliance and auditing
