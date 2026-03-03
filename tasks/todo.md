# Enterprise Observability Stack — Implementation Plan

## Goal
Upgrade the existing PLG stack to a full LGTM (Loki, Grafana, Tempo, Mimir/Prometheus) enterprise
observability platform with SigNoz-equivalent capabilities: distributed tracing, API tracking (RED
metrics via Service Graph), and LLM observability (OTel GenAI semantic conventions).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  Application Nodes (existing)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │  App Pods    │  │  App Pods    │  │  Grafana Alloy      │  │
│  │ (OTel SDK)   │  │ (OTel SDK)   │  │  DaemonSet          │  │
│  │ + OpenLLMetry│  │ + OpenLLMetry│  │  - OTLP receiver    │  │
│  └──────┬───────┘  └──────┬───────┘  │  - Log collector    │  │
│         └────────────────►│◄─────────┤  - Scrape metrics   │  │
│                           └──────────┴──────────┬───────────┘  │
└───────────────────────────────────────────────── │ ─────────────┘
                                                   │
              ┌────────────────────────────────────┘
              │  Ships traces/logs/metrics over network
              ▼
┌─────────────────────────────────────────────────────────────────┐
│         Observability Nodes (tainted: dedicated=observability)  │
│  ┌─────────────┐  ┌────────────┐  ┌───────┐  ┌────────────┐  │
│  │  Prometheus │  │   Loki     │  │ Tempo │  │  Grafana   │  │
│  │  + remote   │  │  (MinIO    │  │ (dist │  │  (single   │  │
│  │  write recv │  │  backend)  │  │  ributed│ │  pane of   │  │
│  └──────┬──────┘  └──────┬─────┘  └───┬───┘  │  glass)    │  │
│         │                │             │       └────────────┘  │
│         └────────────────┴─────────────┘                       │
│                          │                                      │
│                ┌─────────▼──────────┐                          │
│                │       MinIO        │                           │
│                │  (S3-compatible    │                           │
│                │   object store)    │                           │
│                └────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Traces**: App → OTel SDK → Alloy (OTLP receiver) → Tempo (distributed)
   → Tempo metrics generator → Prometheus (spans→RED metrics for Service Graph)
2. **Logs**: Pod stdout → Alloy (Kubernetes log collector) → Loki
   App → OTel Logs SDK → Alloy (OTLP receiver) → Loki
3. **Metrics**: App → OTel Metrics SDK → Alloy (OTLP receiver) → Prometheus (remote_write)
   Infrastructure → kube-prometheus-stack (unchanged)
4. **LLM**: App → OpenLLMetry → OTel trace with gen_ai.* attributes → Alloy → Tempo
   Tempo metrics generator → Prometheus → Grafana LLM dashboard

## Node Isolation Strategy

- **Taint**: `dedicated=observability:NoSchedule` on observability nodes
- **Toleration**: Added to Loki, Tempo, Prometheus, Grafana, MinIO
- **NodeSelector**: `dedicated: observability` on all backend components
- **Alloy**: Tolerates control-plane only — automatically excluded from observability nodes

## Checklist

- [x] tasks/todo.md
- [ ] terraform/variables.tf — observability node variables
- [ ] terraform/modules/server/variables.tf — pass-through variables
- [ ] terraform/modules/server/main.tf — observability node resources
- [ ] terraform/cloud-init/observability.yaml.tftpl — cloud-init with k3s taints
- [ ] kubernetes/storage/minio/namespace.yaml
- [ ] kubernetes/storage/minio/values-minio.yaml
- [ ] kubernetes/storage/minio/install.sh
- [ ] kubernetes/tracing/namespace.yaml
- [ ] kubernetes/tracing/values-tempo.yaml
- [ ] kubernetes/tracing/grafana-datasource.yaml
- [ ] kubernetes/tracing/install.sh
- [ ] kubernetes/alloy/values-alloy.yaml
- [ ] kubernetes/alloy/config.alloy
- [ ] kubernetes/alloy/install.sh
- [ ] kubernetes/logging/values-loki.yaml — MinIO backend + node isolation
- [ ] kubernetes/logging/install.sh — remove Promtail, add Alloy
- [ ] kubernetes/monitoring/values.yaml — remote_write + sidecar datasources + node isolation + dashboards
- [ ] kubernetes/monitoring/dashboards/api-red-metrics.json
- [ ] kubernetes/monitoring/dashboards/llm-observability.json
- [ ] kubernetes/monitoring/dashboards/otel-collector.json
- [ ] kubernetes/security/network-policies/allow-tracing.yaml
- [ ] kubernetes/security/network-policies/allow-alloy.yaml
- [ ] kubernetes/gitops/argocd/apps/minio-observability.yaml
- [ ] kubernetes/gitops/argocd/apps/tempo.yaml
- [ ] kubernetes/gitops/argocd/apps/alloy.yaml
- [ ] kubernetes/gitops/argocd/apps/loki.yaml — updated (MinIO, Alloy)
- [ ] kubernetes/examples/otel-instrumented-app.yaml
- [ ] app/main.py
- [ ] app/requirements.txt
- [ ] app/Dockerfile
- [ ] Makefile — new targets
- [ ] docs/components/tracing.md
- [ ] docs/components/alloy.md
- [ ] docs/architecture/observability.md
- [ ] mkdocs.yml — navigation
- [ ] README.md — observability section
