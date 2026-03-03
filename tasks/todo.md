# Enterprise Observability Stack (LGTM + Alloy) — Implementation Plan

This repo already deploys:
- **Metrics**: `kube-prometheus-stack` (Prometheus + Grafana + Alertmanager)
- **Logs**: Loki (single-binary) + Promtail (DaemonSet)

The goal is to extend it into an **enterprise-grade, SigNoz-like** experience by adding:
- **Traces**: Grafana Tempo
- **Universal collector**: Grafana Alloy (OpenTelemetry-first)
- **APM-style views**: RED metrics + span metrics + service graph + trace/log correlation
- **LLM observability**: OpenTelemetry GenAI semantic conventions (token usage, model, latency, errors)

---

## 0) Decisions (documented assumptions we’ll implement against)

- [ ] **Topology**: support both of these patterns
  - **A. Split setup (recommended)**: dedicated “observability environment” (separate cluster or dedicated VMs) runs Grafana/Loki/Tempo/(Mimir). App clusters run Alloy only.
  - **B. Single cluster w/ isolation**: add 2–3 dedicated Hetzner nodes tainted `role=observability:NoSchedule` and schedule backends only there.
- [ ] **Storage strategy**:
  - Phase 1 (fastest): PV-backed filesystem for Tempo/Loki (works for small/medium, simpler ops)
  - Phase 2 (enterprise): S3-compatible object storage for Tempo/Loki (+ optional Mimir) (recommended for scale)
- [ ] **Metrics backend**:
  - Phase 1: keep Prometheus (already deployed)
  - Phase 2: add Mimir if multi-cluster + long retention + remote_write at scale is needed
- [ ] **Security posture**:
  - TLS everywhere; in split topology, ingestion endpoints require auth (mTLS or token) and network policy allowlists
  - No prompt/completion logging by default (PII/compliance); optionally allow via explicit opt-in and redaction

---

## 1) Repo structure additions (Kubernetes modules)

- [ ] Add `kubernetes/tracing/` for Tempo
  - `kubernetes/tracing/namespace.yaml`
  - `kubernetes/tracing/values-tempo.yaml` (Tempo + metrics-generator enabled)
  - `kubernetes/tracing/grafana-datasource-tempo.yaml` (Tempo datasource + correlations)
  - `kubernetes/tracing/install.sh` (mirrors existing install scripts)
- [ ] Add `kubernetes/telemetry/` for Grafana Alloy (collector)
  - `kubernetes/telemetry/namespace.yaml` (or use `kube-system` if preferred; default to separate `telemetry`)
  - `kubernetes/telemetry/values-alloy.yaml` (DaemonSet; OTLP receiver; k8s log tailing; Prom scrape)
  - `kubernetes/telemetry/alloy.river` (single source of truth for pipelines)
  - `kubernetes/telemetry/install.sh`
- [ ] Update install orchestration
  - `Makefile`: add `tracing`, `telemetry` targets
  - `scripts/deploy.sh`: add flags `--tracing` and `--telemetry` (and include in `--all` if desired)
- [ ] GitOps parity
  - Add Argo CD apps: `kubernetes/gitops/argocd/apps/tracing.yaml`, `.../apps/telemetry.yaml`
  - Update `kubernetes/gitops/argocd/app-of-apps.yaml` to include them

---

## 2) Tempo configuration (Traces + APM-style outputs)

- [ ] Deploy Tempo in `SingleBinary` first (matching Loki’s current pattern), then provide a scale-out path.
- [ ] Enable **OTLP receivers** (gRPC + HTTP) so Alloy and instrumented services can send traces.
- [ ] Enable **metrics-generator** with:
  - **service graph** metrics (for topology maps)
  - **span metrics** (for RED / latency histograms derived from spans)
  - remote_write to Prometheus (Phase 1) or Mimir (Phase 2)
- [ ] Add Grafana “APM-ish” experience:
  - Tempo datasource configured in Grafana
  - Trace → Logs correlation (Tempo → Loki) via `trace_id` / `span_id` labels
  - Trace → Metrics correlation (Tempo → Prometheus) for span metrics/service graph

Deliverable outcome:
- Grafana Explore: trace search, span detail, exemplars
- Grafana Service Graph: automatically rendered topology
- Dashboards: per-service latency, errors, throughput (derived from spans + RED)

---

## 3) Alloy configuration (Universal router)

Alloy will replace “point tools” (Promtail, ad-hoc OTel collectors) with a single, explicit pipeline:

- [ ] **Traces path**:
  - Receive OTLP from apps (`otelcol.receiver.otlp`)
  - Enrich with k8s metadata (namespace/pod/node/service)
  - Optional tail-sampling / rate limits (enterprise defaults)
  - Export to Tempo (`otelcol.exporter.otlp` → Tempo OTLP gRPC)
- [ ] **Metrics path**:
  - Scrape k8s / node / app metrics (Prometheus scrape config managed by Alloy)
  - Forward to Prometheus via `remote_write` (or to Mimir)
  - Keep kube-prometheus-stack as the “rules + alerting” engine initially
- [ ] **Logs path**:
  - Tail container logs (CRI), parse JSON if present
  - Extract `trace_id` from structured logs where possible (for correlation)
  - Export to Loki
- [ ] **GenAI/LLM signals**:
  - No special collector changes required if apps emit spans with GenAI attributes
  - Add optional processors to drop/redact prompt content at the collector boundary

---

## 4) Application instrumentation (API tracking + LLM observability)

This repo is infra-first, so we’ll provide **reference manifests and docs** for teams to adopt:

- [ ] Add examples under `kubernetes/examples/otel/`
  - `otel-instrumentation` examples (Python/Node) using env vars + sidecar/auto-instrumentation patterns
  - Example `Deployment` showing OTLP export to Alloy
- [ ] API tracking (SigNoz-like)
  - Auto-instrument HTTP/gRPC frameworks (Rate/Errors/Duration)
  - Standardize service naming (`service.name`, `deployment.environment`, `k8s.*`)
  - Propagate trace context through ingress (ensure `traceparent` headers preserved)
- [ ] LLM observability (GenAI semantic conventions)
  - Instrument OpenAI/Anthropic/HF calls to produce spans with `gen_ai.*` attributes
  - Default to **not storing** prompt/completion text; allow opt-in + redaction guidance

---

## 5) Isolation patterns (Hetzner)

### Option B: Dedicated observability nodes inside the same cluster

- [ ] Terraform: extend infra to support an additional worker group:
  - variables: `observability_worker_count`, `observability_worker_server_type`
  - cloud-init: add k3s agent flags `--node-label role=observability` and `--node-taint role=observability:NoSchedule`
- [ ] Helm values: add `nodeSelector` + `tolerations` for Loki/Tempo/Grafana/Prometheus to schedule only on those nodes.

### Option A: Separate observability cluster / environment

- [ ] Deploy this repo twice (e.g., `production` + `observability`), or run backends on dedicated VMs.
- [ ] Expose ingestion endpoints securely:
  - Tempo OTLP (gRPC/HTTP), Loki push API, Prom/Mimir remote_write receiver
  - Ingress w/ TLS + mTLS or token auth; strict firewall allowlists
- [ ] Configure Alloy in app clusters to ship to those endpoints.

---

## 6) Validation (what “done” means)

- [ ] Tempo healthy, can ingest traces from an instrumented sample app
- [ ] Service Graph visible in Grafana
- [ ] Span metrics present in Prometheus (or Mimir) and dashboards render
- [ ] Logs correlated with traces (click from trace to related logs)
- [ ] LLM spans show model + token usage attributes (without leaking prompt by default)
- [ ] Resource limits/requests set; backends run only on observability nodes (if using isolation)

---

## 7) Documentation updates

- [ ] Add docs page: `docs/components/tracing.md` (Tempo)
- [ ] Add docs page: `docs/components/telemetry.md` (Alloy + OTel conventions)
- [ ] Update `docs/architecture/overview.md` with LGTM+Alloy data flow

