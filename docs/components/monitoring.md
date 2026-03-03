# Monitoring

## LGTM Observability Stack

This cluster uses the full **LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) with Grafana Alloy as the universal collector:

| Component | Role | Namespace | Docs |
|-----------|------|-----------|------|
| **Prometheus** | Metrics storage (time-series) | `monitoring` | This page |
| **Grafana** | Visualization (single pane of glass) | `monitoring` | This page |
| **Loki** | Log aggregation | `logging` | [Logging](logging.md) |
| **Tempo** | Distributed tracing | `tracing` | [Tracing](tracing.md) |
| **Alloy** | Universal OTel collector | `collector` | [Collector](collector.md) |
| **OTel Operator** | Auto-instrumentation injection | `otel-system` | [LLM Observability](llm-observability.md) |

### Deploy Full Stack

```bash
make observability-full
```

Or deploy individual components:

```bash
make monitoring        # Prometheus + Grafana + Alertmanager
make logging           # Loki + Promtail
make tracing           # Grafana Tempo
make collector         # Grafana Alloy (replaces Promtail)
make otel-operator     # OpenTelemetry auto-instrumentation
make observability-dashboards  # All dashboards + datasources
```

## kube-prometheus-stack

```bash
make monitoring
```

Deploys Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics.

### Access Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open [http://localhost:3000](http://localhost:3000) — user `admin`.

### Pre-loaded Dashboards

**Infrastructure:**

- Kubernetes cluster overview
- Node exporter (system metrics)
- NGINX Ingress Controller
- cert-manager
- Hetzner Cost & Capacity

**Observability (LGTM):**

- API Health — RED Metrics (Rate, Errors, Duration)
- Service Graph — Topology Map
- LLM Observability (token usage, cost, model latency)
- Grafana Alloy — Collector Health

Deploy observability dashboards:

```bash
make observability-dashboards
```

### Grafana Datasources

Grafana is pre-configured with these datasources:

| Datasource | Type | Auto-configured |
|------------|------|----------------|
| Prometheus | Metrics | Yes (via Helm) |
| Loki | Logs | Yes (via ConfigMap) |
| Tempo | Traces | Yes (via ConfigMap) |

The Tempo datasource includes:

- **Trace-to-Logs** — click a trace span to jump to Loki logs
- **Trace-to-Metrics** — correlate traces with Prometheus metrics
- **Service Map** — auto-generated topology graph from traces
- **Node Graph** — visual trace waterfall

### Alertmanager

Configure alert routing in `kubernetes/monitoring/alertmanager-config.yaml`.
Templates included for Slack, PagerDuty, and email receivers.

### Remote Write Receiver

Prometheus is configured with `enableRemoteWriteReceiver: true` to accept metrics from:

- Grafana Alloy (OTel metrics via remote write)
- Tempo Metrics Generator (span metrics and service graph metrics)

### Exemplar Storage

Exemplar storage is enabled, allowing you to click from a Prometheus metric directly to the trace that generated it.

## Hetzner Cost Dashboard

A custom Grafana dashboard showing estimated monthly costs:

- Server costs (by node type)
- Volume costs (by PV capacity)
- Load balancer costs
- CPU/memory utilization vs capacity

Import from `kubernetes/monitoring/dashboards/hetzner-cost.json`.

## Node Isolation

For production, dedicate Hetzner nodes to the observability stack using Terraform:

```hcl
observability_node_count  = 2
observability_server_type = "cx41"  # High-RAM recommended
```

This provisions nodes with `role=observability:NoSchedule` taint. Uncomment the `nodeSelector` and `tolerations` sections in the monitoring values to schedule LGTM components on these dedicated nodes.

See [Architecture > Overview](../architecture/overview.md) for the full isolation strategy.
