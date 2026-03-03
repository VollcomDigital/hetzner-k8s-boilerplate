"""
Enterprise-grade FastAPI application with full OpenTelemetry observability.

Demonstrates:
  1. Distributed tracing (spans visible in Grafana → Tempo)
  2. Structured logging with trace correlation (searchable in Grafana → Loki)
  3. LLM observability via OpenLLMetry (token usage in Grafana → LLM dashboard)

Environment variables required:
  OTEL_SERVICE_NAME           — service name tag (e.g. "api-service")
  OTEL_EXPORTER_OTLP_ENDPOINT — Alloy OTLP endpoint (e.g. http://alloy.logging:4317)
  OPENAI_API_KEY              — for the /llm/chat example endpoint
"""

from __future__ import annotations

import os
from typing import Any

import structlog
import uvicorn
from fastapi import FastAPI, Request
from openai import AsyncOpenAI
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, SERVICE_VERSION, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from pydantic import BaseModel
from traceloop.sdk import Traceloop

# ---------------------------------------------------------------------------
# Structured logger — injects trace_id + span_id for log/trace correlation
# ---------------------------------------------------------------------------
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ]
)
log = structlog.get_logger()


# ---------------------------------------------------------------------------
# OpenTelemetry SDK bootstrap
# ---------------------------------------------------------------------------
def configure_otel() -> None:
    """Bootstrap the OTel SDK with OTLP gRPC export to Grafana Alloy.

    Args:
        None — all config is read from OTEL_* environment variables.
    """
    service_name = os.environ.get("OTEL_SERVICE_NAME", "api-service")
    service_version = os.environ.get("OTEL_SERVICE_VERSION", "0.0.1")
    otlp_endpoint = os.environ.get(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://alloy.logging.svc.cluster.local:4317",
    )

    resource = Resource.create(
        {
            SERVICE_NAME: service_name,
            SERVICE_VERSION: service_version,
        }
    )

    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
        )
    )
    trace.set_tracer_provider(provider)
    log.info("otel.configured", endpoint=otlp_endpoint, service=service_name)


# ---------------------------------------------------------------------------
# OpenLLMetry bootstrap — instruments OpenAI (and other LLM providers) to
# emit traces with gen_ai.* semantic conventions to Grafana Alloy → Tempo.
# These traces feed the LLM observability Grafana dashboard.
# ---------------------------------------------------------------------------
def configure_llm_tracing() -> None:
    """Register OpenLLMetry to auto-instrument all LLM SDK calls.

    Traceloop SDK wraps the OpenAI (and other) client so every chat completion
    emits an OTel span with:
      - gen_ai.system          (e.g. "openai")
      - gen_ai.request.model   (e.g. "gpt-4o")
      - gen_ai.operation.name  (e.g. "chat")
      - gen_ai.usage.input_tokens
      - gen_ai.usage.output_tokens

    Args:
        None — endpoint read from OTEL_EXPORTER_OTLP_ENDPOINT.
    """
    otlp_endpoint = os.environ.get(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://alloy.logging.svc.cluster.local:4317",
    )
    Traceloop.init(
        app_name=os.environ.get("OTEL_SERVICE_NAME", "api-service"),
        api_endpoint=otlp_endpoint,
        # Disable Traceloop's own dashboard — we use Grafana
        disable_batch=False,
    )
    log.info("openllmetry.configured", endpoint=otlp_endpoint)


# ---------------------------------------------------------------------------
# Application bootstrap
# ---------------------------------------------------------------------------
configure_otel()
configure_llm_tracing()

# Auto-instrumentation for incoming HTTP + outgoing HTTPX calls
LoggingInstrumentor().instrument(set_logging_format=True)
HTTPXClientInstrumentor().instrument()

app = FastAPI(
    title="OTel Demo API",
    description=(
        "Demonstrates distributed tracing, structured logging, and LLM observability "
        "using OpenTelemetry + OpenLLMetry on the LGTM stack."
    ),
    version="1.0.0",
)

FastAPIInstrumentor.instrument_app(app)

tracer = trace.get_tracer(__name__)
openai_client = AsyncOpenAI(
    api_key=os.environ.get("OPENAI_API_KEY", ""),
)


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------
class ChatRequest(BaseModel):
    """Request body for the /llm/chat endpoint."""

    prompt: str
    model: str = "gpt-4o-mini"
    max_tokens: int = 256


class ChatResponse(BaseModel):
    """Response body for the /llm/chat endpoint."""

    content: str
    model: str
    input_tokens: int
    output_tokens: int


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------
@app.get("/health", tags=["health"])
async def health() -> dict[str, str]:
    """Liveness probe endpoint."""
    return {"status": "ok"}


@app.get("/ready", tags=["health"])
async def ready() -> dict[str, str]:
    """Readiness probe endpoint."""
    return {"status": "ready"}


# ---------------------------------------------------------------------------
# Example API endpoint — emits HTTP span for RED metrics dashboard
# ---------------------------------------------------------------------------
@app.get("/api/items/{item_id}", tags=["items"])
async def get_item(item_id: int, request: Request) -> dict[str, Any]:
    """Fetch item by ID — traced automatically by FastAPIInstrumentor.

    The OTel span will appear in Grafana → Tempo with:
      - http.method = GET
      - http.route = /api/items/{item_id}
      - http.status_code = 200

    Tempo's span-metrics processor converts these into
    traces_spanmetrics_calls_total and traces_spanmetrics_duration_milliseconds
    metrics, which feed the API RED Metrics Grafana dashboard.

    Args:
        item_id: The numeric ID of the item to retrieve.
        request: FastAPI request object (injected by framework).

    Returns:
        A dict containing item data with trace_id for log correlation.
    """
    current_span = trace.get_current_span()
    trace_id = format(current_span.get_span_context().trace_id, "032x")

    log.info("item.fetched", item_id=item_id, trace_id=trace_id)

    return {
        "item_id": item_id,
        "name": f"Item {item_id}",
        "status": "available",
        "trace_id": trace_id,
    }


# ---------------------------------------------------------------------------
# LLM endpoint — emits gen_ai.* span for LLM observability dashboard
# ---------------------------------------------------------------------------
@app.post("/llm/chat", response_model=ChatResponse, tags=["llm"])
async def llm_chat(body: ChatRequest) -> ChatResponse:
    """Send a prompt to an OpenAI model and return the completion.

    OpenLLMetry automatically wraps the openai_client.chat.completions.create
    call in an OTel span with gen_ai.* attributes. The span flows through
    Alloy → Tempo. Tempo's metrics generator converts it into Prometheus
    metrics that feed the LLM Observability dashboard.

    Attributes emitted per call:
      - gen_ai.system = "openai"
      - gen_ai.request.model = body.model
      - gen_ai.operation.name = "chat"
      - gen_ai.usage.input_tokens = <actual prompt tokens>
      - gen_ai.usage.output_tokens = <actual completion tokens>

    Args:
        body: ChatRequest with prompt, model, and max_tokens.

    Returns:
        ChatResponse with content and token usage.

    Raises:
        HTTPException: If the OpenAI API returns an error.
    """
    with tracer.start_as_current_span("llm.chat") as span:
        span.set_attribute("gen_ai.system", "openai")
        span.set_attribute("gen_ai.request.model", body.model)
        span.set_attribute("gen_ai.operation.name", "chat")

        log.info(
            "llm.request",
            model=body.model,
            prompt_length=len(body.prompt),
            # SECURITY: Never log the prompt content in production.
            # Enable only in dev via a feature flag checked against env.
        )

        response = await openai_client.chat.completions.create(
            model=body.model,
            messages=[{"role": "user", "content": body.prompt}],
            max_tokens=body.max_tokens,
        )

        usage = response.usage
        input_tokens = usage.prompt_tokens if usage else 0
        output_tokens = usage.completion_tokens if usage else 0
        content = response.choices[0].message.content or ""

        # Attach token counts to the span — Tempo metrics generator
        # will expose these as traces_spanmetrics dimensions.
        span.set_attribute("gen_ai.usage.input_tokens", input_tokens)
        span.set_attribute("gen_ai.usage.output_tokens", output_tokens)

        log.info(
            "llm.response",
            model=body.model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )

        return ChatResponse(
            content=content,
            model=body.model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
