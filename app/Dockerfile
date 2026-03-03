# Multi-stage build: minimal final image for production
# Stage 1: install dependencies in a full Python image
FROM python:3.12-slim AS builder

WORKDIR /app

# Layer-cache: copy only the dependency manifest first
COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: distroless-equivalent slim runtime image
FROM python:3.12-slim

# Security: run as a non-root user
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/false --create-home appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup main.py .

USER appuser

ENV PATH="/home/appuser/.local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# OTLP endpoint — overridden by Kubernetes env injection or Downward API
ENV OTEL_SERVICE_NAME="api-service" \
    OTEL_EXPORTER_OTLP_ENDPOINT="http://alloy.logging.svc.cluster.local:4317"

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
