# SM-WikiDict Docker Image
FROM python:3.11-slim

WORKDIR /app

# Copy requirements first (for better caching)
COPY requirement.txt .
RUN pip install --no-cache-dir -r requirement.txt

# Copy application code
COPY main.py .
COPY src/ ./src/

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]