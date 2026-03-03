# Grafana Alloy — Universal OTel Collector

## Overview

Grafana Alloy is the OTel-native, open-source successor to Grafana Agent and Promtail. It runs as a **DaemonSet** on every application node, acting as a universal telemetry router.

Alloy **replaces Promtail** for log collection while simultaneously adding:
- OTLP receiver (port 4317 gRPC, 4318 HTTP) for application traces, metrics, and logs
- Kubernetes pod attribute enrichment (namespace, pod name, deployment name)
- Intelligent routing to the correct LGTM backend

## Architecture

```
                  Application Nodes
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │   Your App Pod          Alloy DaemonSet Pod          │
  │   ┌────────────┐        ┌──────────────────────┐     │
  │   │ OTel SDK   │──OTLP─►│ otelcol.receiver     │     │
  │   │ (traces,   │        │   .otlp "default"    │     │
  │   │  metrics,  │        ├──────────────────────┤     │
  │   │  logs)     │        │ resource_detection   │     │
  │   └────────────┘        │ k8sattributes        │     │
  │                         │ batch processor      │     │
  │   /var/log/pods ───────►│ loki.source.file     │     │
  │   (pod stdout/err)      └──────────┬───────────┘     │
  │                                    │                  │
  └────────────────────────────────────│──────────────────┘
                                       │ routes by signal type
              ┌────────────────────────┼────────────────────┐
              │                        │                    │
              ▼                        ▼                    ▼
        Traces → Tempo          Metrics → Prometheus   Logs → Loki
        :4317 (gRPC)            :9090 (remote_write)   :3100 (push)
```

## Pipeline Configuration

The Alloy pipeline is written in **Alloy configuration language** (formerly River). The config file lives at `kubernetes/alloy/config.alloy`.

### Signal routing

| Signal | Source | Processor chain | Destination |
|---|---|---|---|
| Traces | `otelcol.receiver.otlp` | resource_detection → k8sattributes → batch | `otelcol.exporter.otlp` → Tempo |
| Metrics | `otelcol.receiver.otlp` | resource_detection → k8sattributes → batch | `otelcol.exporter.prometheus` → Prometheus |
| OTel Logs | `otelcol.receiver.otlp` | resource_detection → k8sattributes → batch | `otelcol.exporter.loki` → Loki |
| Pod Logs | `loki.source.file` (host) | `loki.process` (CRI parse + multiline join) | `loki.write` → Loki |

### Kubernetes Attribute Enrichment

The `otelcol.processor.k8sattributes` processor queries the Kubernetes API to attach metadata to every span, metric, and log record:

| Attribute | Value | Source |
|---|---|---|
| `k8s.namespace.name` | `production` | Pod metadata |
| `k8s.pod.name` | `api-service-7f9b4c` | Pod metadata |
| `k8s.deployment.name` | `api-service` | Owner reference |
| `k8s.node.name` | `k8s-worker-0` | Pod spec |
| `service.name` | `api-service` | Pod label `app.kubernetes.io/name` |
| `service.version` | `1.0.0` | Pod label `app.kubernetes.io/version` |

## Configuring Your Application

### 1. Set OTLP endpoint environment variable

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://alloy.logging.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "your-service-name"
```

### 2. Python (FastAPI)

```python
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter())  # reads OTEL_EXPORTER_OTLP_ENDPOINT
)
```

### 3. LLM Observability (OpenLLMetry)

```python
from traceloop.sdk import Traceloop

Traceloop.init(
    app_name="your-service",
    api_endpoint="http://alloy.logging.svc.cluster.local:4317",
)
# All OpenAI / Anthropic calls are now automatically traced
```

### 4. Node.js

```bash
npm install @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-grpc
```

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://alloy.logging.svc.cluster.local:4317',
  }),
});
sdk.start();
```

## Node Placement

Alloy runs on **application nodes only** — it never schedules on observability nodes (they are the backends, not the sources):

- **Tolerates**: `node-role.kubernetes.io/control-plane:NoSchedule` (to also capture system component logs)
- **Does NOT tolerate**: `dedicated=observability:NoSchedule` (automatically excluded from observability nodes)

## Log Collection

Alloy collects container logs by reading `/var/log/pods` on the host node filesystem (same approach as Promtail). The `loki.source.file` component tails the CRI log files in real-time.

### Log labels applied to every stream

```
{
  namespace="production",
  pod="api-service-7f9b4c",
  container="api-service",
  node="k8s-worker-0",
  app="api-service",
  cluster="hetzner"
}
```

### CRI log parsing

Multi-line stack traces are automatically joined using the `loki.process` `stage.multiline` rule:

```alloy
stage.multiline {
  firstline     = "^\\d{4}-\\d{2}-\\d{2}"
  max_wait_time = "3s"
}
```

## Deployment

```bash
# Deploy logging stack (Loki + Alloy)
export MINIO_ROOT_PASSWORD="your-minio-password"
make logging

# Or deploy Alloy standalone
make alloy
```

## Monitoring Alloy Itself

Alloy exposes its own Prometheus metrics at `:12345/metrics`. The ServiceMonitor in `values-alloy.yaml` registers these with Prometheus automatically. The community Grafana dashboard (gnetId: 21260) is pre-imported to visualize:

- Telemetry throughput (spans/sec, log bytes/sec)
- Export errors (failed deliveries to Tempo/Loki/Prometheus)
- Queue depth and batch sizes
- Memory and CPU usage
