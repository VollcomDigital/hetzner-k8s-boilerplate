# LLM Observability

## Overview

LLM observability enables you to monitor prompt latency, token costs, model errors, and the full request lifecycle of your AI/LLM calls. This stack implements LLM tracking using the **OpenTelemetry GenAI Semantic Conventions** — an open standard that works across all LLM providers (OpenAI, Anthropic, Google, HuggingFace, local models).

## Architecture

```
Application (with LLM SDK)
    │
    ├── OTel Auto-Instrumentation (HTTP/gRPC spans)
    └── GenAI Instrumentation (LLM-specific spans)
            │
            ├── gen_ai.request.model = "gpt-4o"
            ├── gen_ai.system = "openai"
            ├── gen_ai.usage.input_tokens = 150
            ├── gen_ai.usage.output_tokens = 500
            └── gen_ai.usage.total_tokens = 650
            │
    Alloy (OTLP) → Tempo (traces) + Prometheus (span metrics)
                                            │
                                    Grafana Dashboard
                                    ├── Token usage per model
                                    ├── Estimated cost per hour
                                    ├── Latency by model (P50/P95/P99)
                                    ├── Error rate by service
                                    └── Recent LLM traces (with prompts)
```

## Instrumentation Options

### Option 1: OpenTelemetry GenAI SDK (Recommended)

The official OTel GenAI instrumentation libraries wrap your LLM client calls automatically:

```bash
pip install opentelemetry-instrumentation-openai
```

```python
from opentelemetry.instrumentation.openai import OpenAIInstrumentor

OpenAIInstrumentor().instrument()
```

### Option 2: OpenLLMetry (Traceloop)

OpenLLMetry provides broader coverage across LLM providers:

```bash
pip install traceloop-sdk
```

```python
from traceloop.sdk import Traceloop

Traceloop.init(
    app_name="my-llm-service",
    api_endpoint="http://alloy.collector.svc.cluster.local:4318",
)
```

### Option 3: Manual Spans

For custom LLM integrations, create spans manually:

```python
from opentelemetry import trace

tracer = trace.get_tracer("llm-client")

with tracer.start_as_current_span("llm.chat") as span:
    span.set_attribute("gen_ai.system", "openai")
    span.set_attribute("gen_ai.request.model", "gpt-4o")
    span.set_attribute("gen_ai.request.max_tokens", 1000)

    response = openai_client.chat.completions.create(...)

    span.set_attribute("gen_ai.usage.input_tokens", response.usage.prompt_tokens)
    span.set_attribute("gen_ai.usage.output_tokens", response.usage.completion_tokens)
    span.set_attribute("gen_ai.usage.total_tokens", response.usage.total_tokens)
    span.set_attribute("gen_ai.response.model", response.model)
```

## Kubernetes Deployment

### Auto-Instrumentation via OTel Operator

Add the annotation to your Deployment:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "otel-system/default"
```

See `kubernetes/examples/llm-instrumented-app.yaml` for a complete example.

### Required Environment Variables

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://alloy.collector.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "my-llm-service"
```

## GenAI Semantic Conventions

The following attributes are automatically captured and used in dashboards:

| Attribute | Example | Description |
|-----------|---------|-------------|
| `gen_ai.system` | `openai` | LLM provider |
| `gen_ai.request.model` | `gpt-4o` | Requested model |
| `gen_ai.response.model` | `gpt-4o-2024-05-13` | Actual model used |
| `gen_ai.usage.input_tokens` | `150` | Prompt tokens |
| `gen_ai.usage.output_tokens` | `500` | Completion tokens |
| `gen_ai.usage.total_tokens` | `650` | Total tokens |
| `gen_ai.request.max_tokens` | `1000` | Max tokens requested |
| `gen_ai.request.temperature` | `0.7` | Sampling temperature |

## Grafana Dashboards

### LLM Observability Dashboard

Deploy with:

```bash
make observability-dashboards
```

The dashboard includes:

- **Total LLM Request Rate** — requests/sec across all models
- **LLM Error Rate** — percentage of failed LLM calls
- **Average Token Usage** — tokens per request
- **P95 LLM Latency** — 95th percentile response time
- **Request Rate by Model** — compare GPT-4 vs Claude vs local models
- **Latency by Model** — identify slow models
- **Token Usage (Input vs Output)** — stacked area chart per model
- **Estimated Cost by Model** — hourly cost based on token pricing
- **LLM Requests by Service** — which Kubernetes workloads call LLMs most
- **Recent LLM Traces** — click through to full Tempo trace view

### Viewing Full Prompts in Traces

1. Go to Grafana → **Explore** → **Tempo**
2. Search with TraceQL:

```
{ span.gen_ai.system != "" }
```

3. Click a trace to see the full span details, including prompt/completion text (if your instrumentation library captures it)

## Cost Tracking

The LLM dashboard estimates hourly cost using configurable per-token prices. Default pricing:

| Model Family | Input ($/1K tokens) | Output ($/1K tokens) |
|-------------|--------------------|--------------------|
| GPT-4 | $0.030 | $0.060 |
| GPT-3.5 | $0.0005 | $0.0015 |
| Claude | $0.015 | $0.075 |

Adjust pricing in the dashboard panel queries or create Grafana variables for dynamic pricing.

## Security Considerations

- **Never log raw prompts** containing PII in production. Configure your instrumentation to redact sensitive content.
- **API keys** must come from Kubernetes Secrets (via External Secrets Operator), never hardcoded.
- The `gen_ai.usage.*` token metrics contain no PII and are safe to store in Prometheus long-term.

## Prerequisites

| Component | Purpose | Install |
|-----------|---------|---------|
| Monitoring (Prometheus + Grafana) | Metrics storage + visualization | `make monitoring` |
| Tracing (Tempo) | Trace storage | `make tracing` |
| Collector (Alloy) | Telemetry routing | `make collector` |
| OTel Operator | Auto-instrumentation injection | `make otel-operator` |

Or deploy everything at once:

```bash
make observability-full
```
