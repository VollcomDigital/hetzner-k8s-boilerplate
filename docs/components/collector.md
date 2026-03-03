# Universal Collector (Grafana Alloy)

## Overview

Grafana Alloy is the universal, OpenTelemetry-native data collector that replaces Promtail in the LGTM stack. Deployed as a DaemonSet (one instance per node), Alloy acts as a universal telemetry router:

- **Receives** OTLP traces, metrics, and logs from applications
- **Scrapes** Prometheus metrics from Kubernetes infrastructure
- **Collects** container logs from the filesystem (replacing Promtail)
- **Routes** each signal to its correct backend: metrics→Prometheus, logs→Loki, traces→Tempo

## Quick Start

```bash
make collector
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Grafana Alloy (per node)                  │
│                                                              │
│  OTLP Receiver (gRPC/HTTP)                                   │
│       │                                                       │
│       ├── Batch Processor                                     │
│       │       │                                               │
│       │       ├── Traces  → Attribute Enrichment → Tempo     │
│       │       ├── Metrics → Prometheus Remote Write           │
│       │       └── Logs    → Loki Push                        │
│       │                                                       │
│  Kubernetes Log Discovery                                     │
│       │                                                       │
│       └── CRI Parser → Multiline → Label Processing → Loki  │
│                                                              │
│  Prometheus Scraper                                           │
│       │                                                       │
│       └── Service Discovery → Prometheus Remote Write        │
│                                                              │
│  Self-Monitoring → Prometheus                                │
└─────────────────────────────────────────────────────────────┘
```

## Endpoints

| Protocol | Address | Purpose |
|----------|---------|---------|
| OTLP gRPC | `alloy.collector.svc.cluster.local:4317` | Application traces/metrics/logs |
| OTLP HTTP | `alloy.collector.svc.cluster.local:4318` | Application traces/metrics/logs |

## Signal Routing

| Signal | Destination | Protocol |
|--------|-------------|----------|
| Traces | Tempo Distributor | OTLP gRPC |
| Metrics | Prometheus | Remote Write |
| Logs | Loki | Push API |

## Migrating from Promtail

Alloy fully replaces Promtail for log collection. After deploying Alloy:

1. Verify logs are flowing to Loki via Grafana → Explore → Loki
2. Uninstall Promtail:

```bash
helm uninstall promtail -n logging
```

Alloy preserves the same log processing pipeline:
- CRI log format parsing
- Multiline aggregation (stacktraces)
- Label enrichment (namespace, pod, container, app, node)
- Label dropping (filename, stream)

## Sending Telemetry from Applications

### Automatic (via OTel Operator)

Add the annotation to your pod template:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "otel-system/default"
```

The OTel Operator injects the SDK which sends to `alloy.collector.svc.cluster.local:4317`.

### Manual (via Environment Variables)

Set these environment variables in your application:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://alloy.collector.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "my-service"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,deployment.environment=production"
```

## Cluster Metadata Enrichment

Alloy automatically adds the attribute `k8s.cluster.name=hetzner-k8s` to all traces, enabling multi-cluster correlation if you later add more clusters.

## Tolerations

Alloy tolerates both control-plane and observability node taints, ensuring it runs on every node in the cluster:

```yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: role
    operator: Equal
    value: observability
    effect: NoSchedule
```

## Monitoring Alloy Itself

A dedicated Grafana dashboard ("Grafana Alloy — Collector Health") tracks:

- Instances up/down
- Traces/metrics/logs exported per second
- Export errors by signal type
- CPU and memory usage per Alloy instance

Deploy it with:

```bash
make observability-dashboards
```

## Configuration

| File | Purpose |
|------|---------|
| `kubernetes/collector/namespace.yaml` | Namespace definition |
| `kubernetes/collector/values.yaml` | Alloy Helm values (includes full River config) |
| `kubernetes/collector/install.sh` | Installation script |
