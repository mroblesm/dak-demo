# ==============================================================================
# Step 5 (Alternative 5A): Cloud Run Container for FastAPI + React/ECharts App
# Enforces @skill:building-data-apps Cloud Run packaging standard (Port 8080)
# ==============================================================================
FROM python:3.11-slim

WORKDIR /app

# Ensure output is unbuffered and Python runs cleanly
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    DEMO_OFFLINE_FALLBACK=false \
    GCP_PROJECT_ID=your-gcp-project-id \
    GCP_REGION=us-central1 \
    DATA_AGENT_ID=clarity-retail-search-agent

# Install system dependencies (curl for container healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies from cached layer
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy application backend and frontend
COPY backend/ /app/backend/
COPY frontend/ /app/frontend/

# Security best practice: run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/api/health || exit 1

CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8080"]
