# Architecture Overview

## Cluster Topology

```
                              Internet
                                 │
                       ┌─────────┴──────────┐
                       │   Hetzner Cloud     │
                       │                      │
              ┌────────────────┐    ┌────────────────┐
              │  API Server LB │    │  Ingress LB    │
              │  :6443 / :9345 │    │  :80 / :443    │
              └───────┬────────┘    └───────┬────────┘
                      │                      │
    ┌─────────────────┼──────────────────────┼──────────────────────┐
    │                 │   Private Network    │                      │
    │                 │     10.0.0.0/16      │                      │
    │  ┌──────────────┴──────┐  ┌───────────┴──────┐  ┌──────────────────┐ │
    │  │   Control Plane     │  │    Workers       │  │  Observability   │ │
    │  │    3x cpx31         │  │    3x cpx41      │  │   2-3x cx41      │ │
    │  │                      │  │                  │  │   (optional)     │ │
    │  │  k3s server         │  │  k3s agent       │  │  k3s agent       │ │
    │  │  etcd               │  │  NGINX Ingress   │  │  Prometheus      │ │
    │  │  Cilium             │  │  Cilium          │  │  Grafana         │ │
    │  │  CCM                │  │  Alloy (DaemonSet)│  │  Loki           │ │
    │  │                      │  │  Workloads       │  │  Tempo          │ │
    │  └──────────────────────┘  └──────────────────┘  └──────────────────┘ │
    │                                                                       │
    │   Pod Network: 10.42.0.0/16 (Cilium)                                 │
    │   Svc Network: 10.43.0.0/16                                          │
    │   Encryption: WireGuard (pod-to-pod)                                 │
    │   Taint: role=observability:NoSchedule (obs nodes only)              │
    └───────────────────────────────────────────────────────────────────────┘
```

## LGTM Observability Stack

The cluster uses a full enterprise-grade observability stack based on the LGTM pattern:

```
 ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
 │  App Pods     │  │  App Pods     │  │  LLM Service │
 │  (auto-instr) │  │  (manual SDK) │  │  (GenAI SDK) │
 └──────┬────────┘  └──────┬────────┘  └──────┬───────┘
        │                   │                   │
        └───────────────────┴───────────────────┘
                            │
              ┌─────────────▼──────────────┐
              │     Grafana Alloy           │
              │     (DaemonSet per node)     │
              │  OTLP + Log collection +    │
              │  Prometheus scraping         │
              └──────┬──────┬──────┬────────┘
                     │      │      │
            ┌────────┘      │      └────────┐
            ▼               ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  Prometheus   │ │    Loki      │ │    Tempo     │
    │  (Metrics)    │ │   (Logs)     │ │  (Traces)    │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           └────────────────┼────────────────┘
                            ▼
                    ┌──────────────┐
                    │   Grafana    │
                    │  Dashboards: │
                    │  - RED/APM   │
                    │  - LLM Cost  │
                    │  - Service   │
                    │    Graph     │
                    └──────────────┘
```

### Components

| Component | Namespace | Role |
|-----------|-----------|------|
| **Prometheus** | `monitoring` | Time-series metrics (node health, pod resources, API rates) |
| **Grafana** | `monitoring` | Single pane of glass for all dashboards |
| **Loki** | `logging` | Compressed log storage with LogQL |
| **Tempo** | `tracing` | Distributed trace storage with TraceQL |
| **Alloy** | `collector` | Universal OTel-native collector (replaces Promtail) |
| **OTel Operator** | `otel-system` | Auto-instrumentation injection for Python/Node.js/Java/Go |

### Signal Flow

| Signal | Source | Collector | Backend | Query Language |
|--------|--------|-----------|---------|---------------|
| Metrics | Prometheus exporters, OTel SDK | Alloy | Prometheus | PromQL |
| Logs | Container stdout, app logs | Alloy | Loki | LogQL |
| Traces | OTel SDK, auto-instrumentation | Alloy | Tempo | TraceQL |

## Node Isolation Strategy

For production deployments, the observability stack can be isolated on dedicated Hetzner nodes:

1. **Provision**: Set `observability_node_count = 2` in Terraform
2. **Taint**: Nodes are tainted with `role=observability:NoSchedule` via cloud-init
3. **Label**: Nodes receive `node-role.kubernetes.io/observability=true` label
4. **Tolerate**: LGTM components are configured with matching tolerations
5. **Isolate**: Regular application pods cannot be scheduled on observability nodes

This prevents resource contention — if an application spews millions of error logs, Loki won't starve your production pods of CPU/RAM.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| K8s distribution | k3s | Lightweight, CNCF-certified, no managed K8s on Hetzner |
| CNI | Cilium | eBPF performance, replaces kube-proxy, WireGuard encryption, Hubble observability |
| HA strategy | 3 CP + LB | Embedded etcd quorum, API fronted by Hetzner LB |
| IaC | Terraform (modular) | Reproducible, stateful, team-friendly |
| GitOps | ArgoCD | App-of-apps pattern, OIDC-ready, strong community |
| Observability | LGTM (Prometheus + Loki + Tempo + Grafana) | Full open-source stack, no vendor lock-in, OTel-native |
| Collector | Grafana Alloy | Universal OTel collector, replaces Promtail, routes all signals |
| APM / Tracing | OpenTelemetry + Tempo | Industry standard, auto-instrumentation, GenAI conventions |
| LLM Observability | OTel GenAI Semantic Conventions | Open standard for token/cost/latency tracking across all providers |
| Backup | Velero + etcd snapshots | Full cluster state + granular namespace recovery |
