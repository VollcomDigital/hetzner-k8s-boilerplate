# Observability Architecture — LGTM Stack

## Overview

This boilerplate implements the **LGTM stack** (Loki, Grafana, Tempo, Mimir/Prometheus) — a completely open-source, enterprise-grade observability platform that mirrors the capabilities of commercial APM tools like SigNoz, Datadog, or New Relic.

## Stack Components

| Component | Role | Namespace | Chart |
|---|---|---|---|
| **Grafana** | Visualization & dashboards | `monitoring` | `prometheus-community/kube-prometheus-stack` |
| **Prometheus** | Metrics storage + alerting | `monitoring` | Bundled in kube-prometheus-stack |
| **Alertmanager** | Alert routing (Slack, PagerDuty) | `monitoring` | Bundled in kube-prometheus-stack |
| **Loki** | Log aggregation & query | `logging` | `grafana/loki` |
| **Grafana Alloy** | OTel-native collector (DaemonSet) | `logging` | `grafana/alloy` |
| **Tempo** | Distributed tracing | `tracing` | `grafana/tempo-distributed` |
| **MinIO** | S3-compatible object storage | `storage` | `minio/minio` |
| **Hubble UI** | Cilium network observability | `kube-system` | Cilium built-in |

## The Node Isolation Strategy

Following the enterprise "split" architecture on Hetzner, workloads are physically isolated using **Kubernetes Taints and Tolerations**:

### Application Nodes (existing workers)

Run all your production microservices. Grafana Alloy runs here as a DaemonSet — it is the only observability component on these nodes. Its sole job is to collect telemetry and ship it off-node immediately.

### Observability Nodes (dedicated, tainted)

Run all LGTM backends: Prometheus, Grafana, Loki, Tempo, MinIO.

**Taint applied at k3s bootstrap** (in cloud-init):
```bash
--node-label "dedicated=observability"
--node-taint "dedicated=observability:NoSchedule"
```

**Toleration in all LGTM Helm charts**:
```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: observability
    effect: NoSchedule
nodeSelector:
  dedicated: observability
```

**Why this prevents "flying blind" outages**: If your application nodes crash, the observability nodes continue running unaffected. You retain full metrics, logs, and traces to diagnose the outage.

## Data Flow Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                        Application Nodes                          │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ Grafana Alloy DaemonSet (logging namespace)                 │  │
│  │                                                             │  │
│  │  OTLP Receiver :4317/:4318 ◄── App OTel SDKs              │  │
│  │  loki.source.file          ◄── /var/log/pods (host mount)  │  │
│  │                                                             │  │
│  │  Pipeline: resource_detection → k8sattributes → batch      │  │
│  │                    │                │               │       │  │
│  │               Traces           Metrics          Logs       │  │
│  └───────────────────────────────────────────────────────────────┘  │
│               │                    │               │             │
└───────────────┼────────────────────┼───────────────┼─────────────┘
                │ OTLP gRPC          │ remote_write  │ push API
                ▼                    ▼               ▼
┌───────────────────────────────────────────────────────────────────┐
│                      Observability Nodes                          │
│              (tainted: dedicated=observability:NoSchedule)        │
│                                                                   │
│  ┌──────────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │ Tempo Distributed │  │ Prometheus  │  │ Loki SimpleScalable  │ │
│  │ :4317 distributor │  │ :9090       │  │ :3100 gateway        │ │
│  │ :3100 query-front │  │ remote_write│  │ write (x2)           │ │
│  │ metrics generator─┼─►│ receiver    │  │ read  (x2)           │ │
│  └────────┬──────────┘  └──────┬──────┘  └──────────┬───────────┘ │
│           │                    │                    │             │
│           └────────────────────┴────────────────────┘             │
│                                │                                  │
│                    ┌───────────▼──────────┐                       │
│                    │      MinIO           │                       │
│                    │  loki-chunks (Loki)  │                       │
│                    │  tempo-traces (Tempo)│                       │
│                    └──────────────────────┘                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Grafana                                                    │   │
│  │  Datasources: Prometheus | Loki | Tempo                   │   │
│  │  Dashboards:                                               │   │
│  │    Infrastructure → Kubernetes, Node Exporter, Cost        │   │
│  │    APM & Tracing  → API RED Metrics, Service Graph         │   │
│  │    LLM Observ.   → Token Usage, Latency, Cost Estimate    │   │
│  └────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

## API Tracking (SigNoz-equivalent APM)

To replicate SigNoz's APM view showing endpoint latency, error rates, and throughput:

1. **Instrument your app** with any OTel SDK (Python, Node.js, Go, Java). FastAPIInstrumentor, gin-gonic middleware, etc. produce HTTP semantic convention spans automatically.

2. **Spans flow** through Alloy → Tempo Distributor.

3. **Tempo's Metrics Generator** converts spans into `traces_spanmetrics_*` Prometheus metrics using the `span-metrics` processor.

4. **Grafana dashboard** (API RED Metrics) queries these metrics to show:
   - Request rate per endpoint (`http.route` dimension)
   - Error rate (spans with `status_code=STATUS_CODE_ERROR`)
   - P50/P95/P99 latency histograms

5. **Service Graph** is built from the `service-graphs` processor, which reads parent-child span relationships to construct `traces_service_graph_*` metrics — visible as a live topology map in Grafana.

## LLM Observability

To monitor LLM API usage (token costs, latency, errors per model):

1. **Add OpenLLMetry** to your service:
   ```python
   from traceloop.sdk import Traceloop
   Traceloop.init(app_name="my-service",
                  api_endpoint="http://alloy.logging.svc.cluster.local:4317")
   ```

2. **Every LLM call** (OpenAI, Anthropic, HuggingFace) is automatically wrapped in an OTel span with `gen_ai.*` attributes.

3. **Grafana LLM Observability dashboard** reads `traces_spanmetrics_*` metrics filtered by `gen_ai.*` dimensions to show:
   - API call rate per model
   - P50/P99 latency per model
   - Token usage trends
   - Estimated cost per hour

## Deployment Order

The stack has a strict dependency order — MinIO must exist before Loki/Tempo start, and Prometheus must exist before the Metrics Generator can remote_write:

```
1. make monitoring          → Prometheus + Grafana + Alertmanager
2. make minio-storage       → MinIO (creates loki-* and tempo-* buckets)
3. make logging             → Loki (SimpleScalable) + Grafana Alloy
4. make tracing             → Tempo Distributed
5. make dashboards          → Load API RED + LLM Observability dashboards
```

Or as a single command:
```bash
make monitoring && make observability
```

In GitOps mode (ArgoCD), sync-waves enforce the same order: `4 → 5 → 6 → 7`.

## Terraform: Provisioning Observability Nodes

Add observability nodes by setting these variables in your `terraform.tfvars`:

```hcl
observability_node_count  = 2
observability_server_type = "cx52"    # 8 vCPU, 32GB RAM — sufficient for LGTM
```

The nodes join the cluster via k3s with the taint and label baked into cloud-init. No manual `kubectl taint` is required.

## Recommended Hetzner Server Types

| Role | Server Type | vCPU | RAM | Monthly Cost (est.) |
|---|---|---|---|---|
| App workers | `cpx31` | 4 | 8 GB | ~12 EUR |
| Observability nodes | `cx52` | 8 | 32 GB | ~36 EUR |

Two `cx52` nodes for ~72 EUR/month provides a resilient LGTM stack with room to grow. Compare to SigNoz Cloud pricing or Datadog ingestion costs at scale.
