# Distributed Tracing — Grafana Tempo

## Overview

Grafana Tempo is the distributed tracing backend in the LGTM stack. It stores the complete journey of a request as it hops through your microservices and external APIs (including LLM calls).

Tempo is deployed in **Microservices mode** (distributor, ingester, querier, query-frontend, compactor) backed by **MinIO** (S3-compatible object storage), giving you horizontal scalability and data durability without vendor lock-in.

## Data Flow

```
Instrumented App → OTel SDK
         ↓
Grafana Alloy (OTLP receiver, logging namespace)
         ↓
Tempo Distributor :4317 (gRPC OTLP)
         ↓
Tempo Ingester → MinIO (tempo-traces bucket)
         ↓
Tempo Metrics Generator → Prometheus (remote_write)
         ↓ (span-metrics + service-graphs)
Grafana Dashboards (API RED Metrics, Service Graph)
```

## Components

| Component | Replicas | Role |
|---|---|---|
| Distributor | 2 | Receives OTLP traces from Alloy / apps |
| Ingester | 2 | Buffers traces in WAL, flushes to MinIO |
| Querier | 1 | Executes TraceQL queries against MinIO |
| Query Frontend | 1 | Fan-out coordinator for query sharding |
| Compactor | 1 | Merges blocks, enforces 30-day retention |
| Metrics Generator | 1 | Converts spans into Prometheus metrics |

## Metrics Generator — The "SigNoz APM" Bridge

The Metrics Generator is what enables Grafana to display SigNoz-equivalent APM views **without a paid APM tool**.

It reads every incoming trace and emits two sets of Prometheus metrics via remote_write:

### `span-metrics` processor
Generates RED metrics per service and HTTP route from OTel HTTP semantic conventions:

```promql
# Request rate per endpoint
sum by (service, http_route, http_method) (
  rate(traces_spanmetrics_calls_total[5m])
)

# P99 latency per endpoint
histogram_quantile(0.99,
  sum by (service, http_route, le) (
    rate(traces_spanmetrics_duration_milliseconds_bucket[5m])
  )
)

# Error rate per endpoint
sum(rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
  /
sum(rate(traces_spanmetrics_calls_total[5m]))
```

### `service-graphs` processor
Generates a real-time service topology graph from trace parent-child relationships:

```promql
# Service call rate (edges in the service map)
rate(traces_service_graph_request_total[5m])

# Inter-service P99 latency
histogram_quantile(0.99,
  sum by (client, server, le) (
    rate(traces_service_graph_request_duration_seconds_bucket[5m])
  )
)
```

View the topology in **Grafana → Explore → Tempo → Service Graph tab**.

## Ingestion Protocols

Tempo Distributor accepts traces via:

| Protocol | Port | Use case |
|---|---|---|
| OTLP gRPC | 4317 | Alloy + all modern OTel SDKs (recommended) |
| OTLP HTTP | 4318 | SDKs that don't support gRPC |
| Zipkin | 9411 | Legacy services |
| Jaeger gRPC | 14250 | Legacy services |
| Jaeger HTTP | 14268 | Legacy services |

## TraceQL Queries

TraceQL is Tempo's trace query language (similar to LogQL for logs):

```traceql
# Find all traces with errors
{ status = error }

# Find slow LLM API calls (> 2 seconds)
{ .gen_ai.system = "openai" && duration > 2s }

# Find traces for a specific service + route
{ .service.name = "api-service" && .http.route = "/api/items/{item_id}" }

# Find traces with high token usage
{ .gen_ai.usage.output_tokens > 1000 }
```

## LLM Observability

When your application uses [OpenLLMetry](https://github.com/traceloop/openllmetry) (or the native OTel GenAI SDK), each LLM API call produces a trace span with standardized `gen_ai.*` attributes:

| Attribute | Example Value | Description |
|---|---|---|
| `gen_ai.system` | `openai` | LLM provider |
| `gen_ai.request.model` | `gpt-4o-mini` | Model requested |
| `gen_ai.operation.name` | `chat` | Operation type |
| `gen_ai.usage.input_tokens` | `142` | Prompt token count |
| `gen_ai.usage.output_tokens` | `87` | Completion token count |

These attributes are indexed by Tempo and become dimensions in the Metrics Generator's span-metrics, powering the **LLM Observability Grafana dashboard**.

## Storage

- **Backend**: MinIO (S3-compatible), bucket `tempo-traces`
- **Endpoint**: `http://minio.storage.svc.cluster.local:9000`
- **Retention**: 30 days (720h), enforced by Compactor
- **WAL**: 10Gi per Ingester (in-flight buffer on Hetzner Volume)

## Node Isolation

All Tempo components run exclusively on observability-tainted nodes:

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: observability
    effect: NoSchedule

nodeSelector:
  dedicated: observability
```

## Deployment

```bash
# 1. Deploy MinIO first (creates the tempo-traces bucket)
make minio-storage

# 2. Deploy Tempo
export MINIO_ROOT_PASSWORD="your-minio-password"
make tracing

# 3. Tempo datasource is auto-registered in Grafana
# View traces: Grafana → Explore → Tempo
```

## Grafana Integration

Tempo is auto-registered as a Grafana datasource via the ConfigMap in `kubernetes/tracing/grafana-datasource.yaml`. The datasource is configured with:

- **Trace-to-Logs**: Links any span to the Loki log stream from the same pod during that time window
- **Trace-to-Metrics**: Links any span to the corresponding Prometheus RED metric
- **Service Graph**: Draws a real-time dependency map from `traces_service_graph_*` metrics
- **Node Graph**: Visualizes the internal call tree of a single trace
