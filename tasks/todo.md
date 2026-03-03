# Enterprise Observability Stack - Implementation Plan

## Overview
Transform existing PLG stack (Prometheus, Loki, Grafana + Promtail) into a full LGTM stack
(Loki, Grafana, Tempo, Mimir/Prometheus) with Grafana Alloy as the universal OTel-native collector.
Includes API tracking (RED metrics, service graph) and LLM observability (GenAI semantic conventions).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Application Cluster (lightweight collectors only)                  │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ App Pod   │  │ App Pod   │  │ App Pod   │  │ OTel Auto-Instr  │   │
│  │ (Python)  │  │ (Node.js) │  │ (Go)      │  │ (Operator)       │   │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └────────┬─────────┘   │
│        │               │               │                │              │
│        └───────────────┴───────────────┴────────────────┘              │
│                                  │                                     │
│                    ┌─────────────▼──────────────┐                      │
│                    │      Grafana Alloy          │                      │
│                    │   (DaemonSet per node)       │                      │
│                    │  - OTLP receiver             │                      │
│                    │  - Prometheus scraper         │                      │
│                    │  - Log collector              │                      │
│                    └─────────────┬──────────────┘                      │
│                                  │                                     │
└──────────────────────────────────┼─────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
    ┌─────────▼───────┐  ┌────────▼────────┐  ┌────────▼────────┐
    │   Prometheus     │  │     Loki        │  │     Tempo       │
    │   (Metrics)      │  │     (Logs)      │  │   (Traces)      │
    └─────────┬───────┘  └────────┬────────┘  └────────┬────────┘
              │                    │                     │
              └────────────────────┼────────────────────┘
                                   │
                         ┌─────────▼──────────┐
                         │     Grafana         │
                         │  (Dashboards)       │
                         │  - API Health       │
                         │  - LLM Observability│
                         │  - Service Graph    │
                         └─────────────────────┘
```

## Implementation Phases

### Phase 1: Core Tracing Backend
- [x] Create `kubernetes/tracing/` — Grafana Tempo (namespace, values, install script)
- [x] Add Tempo datasource ConfigMap for Grafana
- [x] Enable service graph and trace-to-logs correlation

### Phase 2: Universal Collector (Grafana Alloy)
- [x] Create `kubernetes/collector/` — Grafana Alloy (namespace, values, install script)
- [x] Configure OTLP receiver (gRPC + HTTP)
- [x] Configure Prometheus scraping
- [x] Configure log collection (replacing Promtail)
- [x] Route: metrics→Prometheus, logs→Loki, traces→Tempo

### Phase 3: Observability Node Isolation
- [x] Add Terraform variables for observability node pool
- [x] Configure taints (`role=observability:NoSchedule`) on dedicated nodes
- [x] Add tolerations + nodeSelector to all LGTM Helm values
- [x] Alloy DaemonSet tolerates all taints (runs everywhere)

### Phase 4: API Tracking (APM)
- [x] Deploy OpenTelemetry Operator for auto-instrumentation
- [x] Create Instrumentation CRDs for Python, Node.js, Java, Go
- [x] Create RED metrics Grafana dashboard (Rate, Errors, Duration)
- [x] Enable Grafana Service Graph visualization

### Phase 5: LLM Observability
- [x] Create example OpenLLMetry/OTel GenAI instrumentation config
- [x] Create LLM observability Grafana dashboard (tokens, latency, cost, model)
- [x] Document GenAI semantic conventions integration

### Phase 6: GitOps & Integration
- [x] Add ArgoCD Application manifests for Tempo, Alloy, OTel Operator
- [x] Update Makefile with new targets (tracing, collector, otel-operator)
- [x] Update deploy.sh with new optional flags
- [x] Add network policies for new namespaces
- [x] Update smoke-test.sh

### Phase 7: Documentation
- [x] Create docs/components/tracing.md
- [x] Create docs/components/collector.md
- [x] Create docs/components/llm-observability.md
- [x] Update docs/architecture/overview.md
- [x] Update docs/components/monitoring.md and logging.md
