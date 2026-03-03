# Distributed Tracing (Grafana Tempo)

## Overview

Grafana Tempo is the distributed tracing backend of the LGTM observability stack. It stores the exact journey of every request as it traverses your microservices, enabling you to:

- **Debug latency** — pinpoint which service or database call is slow
- **Trace LLM calls** — see prompt latency, token usage, and model errors
- **Visualize topology** — auto-generate a real-time service graph from traces
- **Correlate signals** — jump from a trace to the corresponding logs (Loki) and metrics (Prometheus)

## Quick Start

```bash
make tracing
```

This deploys Tempo in distributed mode with the following components:

| Component | Role |
|-----------|------|
| **Distributor** | Receives OTLP traces from Alloy/apps |
| **Ingester** | Writes trace data to persistent storage |
| **Querier** | Executes TraceQL queries |
| **Query Frontend** | Caches and distributes queries |
| **Compactor** | Merges and compresses trace blocks |
| **Metrics Generator** | Produces RED metrics and service graph data from traces |
| **Gateway** | Nginx-based gateway for routing |

## Architecture

```
Applications → Alloy (collector) → Tempo Distributor → Ingester → Storage
                                                                      ↑
Grafana → Query Frontend → Querier ──────────────────────────────────┘
                                                                      
Tempo Metrics Generator → Prometheus (span metrics, service graph metrics)
```

## Endpoints

| Protocol | Address |
|----------|---------|
| OTLP gRPC | `tempo-distributed-distributor.tracing.svc.cluster.local:4317` |
| OTLP HTTP | `tempo-distributed-distributor.tracing.svc.cluster.local:4318` |
| Query (Grafana) | `tempo-distributed-query-frontend.tracing.svc.cluster.local:3100` |

## Metrics Generator

The metrics generator automatically derives time-series metrics from incoming traces:

- **Span Metrics** — Rate, Error rate, and Duration (RED) per service/endpoint
- **Service Graph** — Request rate, error rate, and latency between services

These metrics are remote-written to Prometheus and power the RED Metrics and Service Graph dashboards.

### Tracked Dimensions

- `service.name`, `http.method`, `http.status_code`, `http.route`
- `rpc.method`, `rpc.service`
- `gen_ai.request.model`, `gen_ai.system` (for LLM observability)

## Querying Traces

### In Grafana

1. Go to **Explore** → Select **Tempo** datasource
2. Use the **Search** tab to find traces by service, duration, or status
3. Use **TraceQL** for advanced queries:

```
{ resource.service.name = "my-api" && span.http.status_code >= 500 }
```

```
{ span.gen_ai.system = "openai" && duration > 5s }
```

### Trace-to-Logs Correlation

The Tempo datasource is pre-configured with trace-to-logs linking. Click any span in a trace to jump to the corresponding logs in Loki with matching `traceID`.

## Storage

Tempo stores trace data on 30Gi Hetzner Volumes. Retention is set to 14 days (336h).

Adjust in `kubernetes/tracing/values.yaml`:

```yaml
ingester:
  persistence:
    size: 30Gi

compactor:
  config:
    compaction:
      block_retention: 336h
```

## Node Isolation

When dedicated observability nodes are provisioned (via `observability_node_count` in Terraform), uncomment the `nodeSelector` and `tolerations` sections in `kubernetes/tracing/values.yaml` to schedule Tempo only on isolated nodes.

## Configuration

| File | Purpose |
|------|---------|
| `kubernetes/tracing/namespace.yaml` | Namespace definition |
| `kubernetes/tracing/values.yaml` | Tempo Helm values |
| `kubernetes/tracing/install.sh` | Installation script |
| `kubernetes/tracing/grafana-datasource.yaml` | Grafana datasource ConfigMap |
