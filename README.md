# Hetzner Kubernetes Boilerplate

Production-ready Kubernetes cluster on [Hetzner Cloud](https://www.hetzner.com/cloud) using **Terraform** and **k3s**, following industry best practices.

## Architecture

```
                    ┌──────────────────────────────────┐
                    │         Hetzner Cloud             │
                    │                                    │
                    │   ┌────────────────────────┐      │
                    │   │   Load Balancer (LB11)  │      │
    Internet ──────►│   │   :6443 (K8s API)       │      │
                    │   │   :9345 (k3s supervisor) │      │
                    │   └─────────┬──────────────┘      │
                    │             │                       │
                    │   ┌─────────┼──────────────────┐   │
                    │   │  Private Network (10.0.0.0) │   │
                    │   │         │                    │   │
                    │   │  ┌──────┴──────┐            │   │
                    │   │  │Control Plane│            │   │
                    │   │  │  (3x cpx31) │            │   │
                    │   │  │  k3s server │            │   │
                    │   │  │  etcd       │            │   │
                    │   │  └─────────────┘            │   │
                    │   │                              │   │
                    │   │  ┌─────────────┐            │   │
                    │   │  │   Workers   │            │   │
                    │   │  │  (3x cpx31) │            │   │
                    │   │  │  k3s agent  │            │   │
                    │   │  └─────────────┘            │   │
                    │   │                              │   │
                    │   └──────────────────────────────┘   │
                    └──────────────────────────────────────┘
```

## Stack

| Layer | Component | Purpose |
|-------|-----------|---------|
| **IaC** | Terraform | Infrastructure provisioning |
| **K8s Distribution** | k3s | Lightweight, CNCF-certified Kubernetes |
| **CNI** | Cilium | Networking, network policies, kube-proxy replacement |
| **Cloud Integration** | hcloud-ccm | Node lifecycle, Hetzner LB provisioning |
| **Storage** | hcloud-csi | Persistent volumes (Hetzner Volumes) |
| **Ingress** | NGINX Ingress | HTTP/HTTPS traffic routing |
| **TLS** | cert-manager | Automated Let's Encrypt certificates |
| **Metrics** | Prometheus (kube-prometheus-stack) | Time-series metrics, alerting |
| **Visualization** | Grafana | Single pane of glass (dashboards, explore) |
| **Logging** | Loki + Grafana Alloy | Centralized log aggregation (Grafana-native) |
| **Tracing** | Grafana Tempo | Distributed tracing backend (OTLP) |
| **Collector** | Grafana Alloy | Universal OTel-native collector (replaces Promtail) |
| **APM** | OpenTelemetry Operator | Auto-instrumentation for Python/Node.js/Java/Go |
| **LLM Observability** | OTel GenAI Conventions | Token usage, cost tracking, model latency |
| **Backup** | Velero + etcd snapshots | Cluster state backup & disaster recovery |
| **Secrets** | External Secrets Operator | Sync secrets from Vault, AWS, etc. |
| **DNS** | external-dns | Automatic DNS records from Ingress resources |
| **Autoscaling** | Cluster Autoscaler | Dynamic worker node scaling |
| **Upgrades** | System Upgrade Controller | Automated rolling k3s upgrades via CRDs |
| **GitOps** | ArgoCD | Continuous deployment from Git |
| **Encryption** | WireGuard (Cilium) | Pod-to-pod traffic encryption |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.x
- [hcloud CLI](https://github.com/hetznercloud/cli) (optional, for debugging)
- SSH key pair (`ssh-keygen -t ed25519`)
- Hetzner Cloud API token ([console](https://console.hetzner.cloud) → Project → Security → API Tokens)

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_ORG/hetzner-k8s-boilerplate.git
cd hetzner-k8s-boilerplate

cp .env.example .env
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit both files with your values (at minimum: `HCLOUD_TOKEN` and `ACME_EMAIL`).

### 2. Run pre-flight checks

```bash
make setup
```

### 3. Preview infrastructure

```bash
make plan
```

### 4. Deploy everything

```bash
# Core components only (infra + CCM + CSI + ingress + cert-manager + monitoring)
make deploy

# Core + all optional components
make deploy-all

# Core + selected optional components
./scripts/deploy.sh --logging --argocd --security
```

Core pipeline (always runs):
1. Provisions Hetzner infrastructure (network, firewalls, LB, servers)
2. Bootstraps k3s HA cluster via cloud-init
3. Installs Cilium CNI with WireGuard encryption
4. Deploys Hetzner CCM and CSI driver
5. Installs NGINX Ingress Controller
6. Deploys cert-manager with Let's Encrypt
7. Sets up Prometheus + Grafana monitoring

Optional flags: `--logging`, `--tracing`, `--collector`, `--otel-operator`, `--observability` (all 4), `--argocd`, `--security`, `--external-dns`, `--autoscaler`, `--velero`, `--external-secrets`, or `--all`.

### 5. Access the cluster

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

## Project Structure

```
├── terraform/
│   ├── main.tf                          # Root module — orchestrates everything
│   ├── variables.tf                     # All configurable parameters
│   ├── outputs.tf                       # Cluster endpoints and metadata
│   ├── versions.tf                      # Provider versions and backend config
│   ├── terraform.tfvars.example         # Example configuration
│   ├── cloud-init/
│   │   ├── control-plane.yaml.tftpl     # k3s server bootstrap
│   │   └── worker.yaml.tftpl            # k3s agent bootstrap
│   └── modules/
│       ├── network/                     # Hetzner private network + subnet
│       ├── firewall/                    # Ingress/egress rules per role
│       └── server/                      # Control-plane + worker provisioning
├── kubernetes/
│   ├── core/
│   │   ├── hcloud-ccm/                  # Hetzner Cloud Controller Manager
│   │   └── hcloud-csi/                  # Hetzner CSI Driver + StorageClasses
│   ├── ingress/
│   │   ├── nginx/                       # NGINX Ingress (Helm values + install)
│   │   └── cert-manager/               # cert-manager + Let's Encrypt issuers
│   ├── monitoring/                      # kube-prometheus-stack + dashboards
│   │   └── dashboards/                  # RED, LLM, Service Graph, Alloy dashboards
│   ├── logging/                         # Loki + Promtail log aggregation
│   ├── tracing/                         # Grafana Tempo (distributed tracing)
│   ├── collector/                       # Grafana Alloy (universal OTel collector)
│   ├── otel-operator/                   # OpenTelemetry Operator + Instrumentation CRDs
│   ├── backup/                          # Velero cluster backup & restore
│   ├── security/
│   │   ├── network-policies/            # Default deny + allow rules
│   │   ├── rbac/                        # ClusterRoles for reader/deployer
│   │   ├── external-secrets/            # External Secrets Operator
│   │   └── pod-security.yaml            # Pod Security Standards per namespace
│   ├── system/
│   │   ├── upgrade-controller/          # k3s System Upgrade Controller
│   │   ├── external-dns/                # Automatic DNS record management
│   │   └── autoscaler/                  # Hetzner node autoscaler
│   ├── examples/
│   │   └── sample-app.yaml             # Reference deployment with best practices
│   └── gitops/
│       └── argocd/                      # ArgoCD install + app-of-apps pattern
├── scripts/
│   ├── setup.sh                         # Pre-flight checks
│   ├── deploy.sh                        # Full deployment pipeline (with optional flags)
│   ├── destroy.sh                       # Teardown with confirmation
│   └── upgrade.sh                       # Rolling k3s upgrade script
├── .github/
│   ├── workflows/validate.yml           # CI: terraform validate, kubeconform, trivy
│   └── pull_request_template.md         # PR checklist template
├── Makefile                             # 30+ targets across all categories
├── .env.example                         # Environment variable template
├── CONTRIBUTING.md                      # Development workflow & code standards
├── LICENSE                              # MIT License
└── .gitignore
```

## Make Targets

```
Infrastructure:
  make setup                Run pre-flight checks
  make plan                 Preview Terraform changes
  make apply                Apply Terraform changes
  make deploy               Core deployment (infra + essential K8s components)
  make deploy-all           Full deployment with ALL optional components
  make destroy              Tear down everything (with confirmation)

Core Components:
  make ccm                  Deploy Hetzner Cloud Controller Manager
  make csi                  Deploy Hetzner CSI Driver
  make ingress              Deploy NGINX Ingress Controller
  make cert-manager         Deploy cert-manager

Observability (LGTM Stack):
  make monitoring           Deploy Prometheus + Grafana monitoring stack
  make logging              Deploy Loki + Promtail logging stack
  make tracing              Deploy Grafana Tempo distributed tracing
  make collector            Deploy Grafana Alloy (universal OTel collector)
  make otel-operator        Deploy OpenTelemetry Operator (auto-instrumentation)
  make observability-full   Deploy full LGTM stack (all of the above + dashboards)
  make observability-dashboards  Apply all observability Grafana dashboards
  make hubble               Deploy Hubble UI with Ingress + basic-auth
  make grafana-ingress      Apply Grafana + Alertmanager Ingress manifests

Security:
  make security             Apply network policies, RBAC, quotas, priority classes
  make external-secrets     Deploy External Secrets Operator

System & Operations:
  make argocd               Deploy ArgoCD for GitOps
  make velero               Deploy Velero backup system
  make external-dns         Deploy external-dns
  make autoscaler           Deploy Hetzner Cluster Autoscaler
  make upgrade-controller   Deploy k3s System Upgrade Controller
  make upgrade VERSION=v1.30.2+k3s1    Rolling k3s upgrade

Utilities:
  make kubeconfig           Fetch kubeconfig from cluster
  make status               Cluster health overview (nodes, pods, PVs, backups)
  make nodes                List nodes
  make pods                 List all pods
  make fmt                  Format Terraform files
  make validate             Validate Terraform configuration
  make lint                 Format + validate
  make clean                Remove local artifacts
```

## Configuration

### Server Types (Hetzner Cloud)

| Type | vCPU | RAM | Disk | Monthly Cost |
|------|------|-----|------|-------------|
| `cpx11` | 2 | 2 GB | 40 GB | ~€4.49 |
| `cpx21` | 3 | 4 GB | 80 GB | ~€8.49 |
| `cpx31` | 4 | 8 GB | 160 GB | ~€15.49 |
| `cpx41` | 8 | 16 GB | 240 GB | ~€28.49 |
| `cpx51` | 16 | 32 GB | 360 GB | ~€54.49 |

Default cluster (3 CP + 3 Workers at `cpx31`): ~**€93/month** + LB (~€6) + Volumes.

### Environment Profiles

Edit `terraform.tfvars` for your environment:

**Development** (single CP, minimal):
```hcl
control_plane_count       = 1
control_plane_server_type = "cpx21"
worker_count              = 2
worker_server_type        = "cpx21"
environment               = "dev"
```

**Production** (HA, full):
```hcl
control_plane_count       = 3
control_plane_server_type = "cpx31"
worker_count              = 3
worker_server_type        = "cpx41"
environment               = "production"
```

**Production with Observability Isolation** (recommended):
```hcl
control_plane_count        = 3
control_plane_server_type  = "cpx31"
worker_count               = 3
worker_server_type         = "cpx41"
observability_node_count   = 2
observability_server_type  = "cx41"   # High-RAM for Loki/Tempo/Prometheus
environment                = "production"
```

Observability nodes are automatically tainted with `role=observability:NoSchedule` to prevent application pods from being scheduled on them, ensuring the LGTM stack has dedicated resources.

## Security

### Implemented

- **Network isolation**: Hetzner private network for all inter-node traffic
- **Firewall rules**: Least-privilege per role (control-plane vs worker)
- **WireGuard encryption**: Pod-to-pod traffic encrypted via Cilium
- **Pod Security Standards**: Enforced per namespace (restricted/baseline)
- **Network Policies**: Default-deny with explicit allow rules
- **RBAC templates**: Read-only and deployer roles
- **TLS everywhere**: cert-manager with automatic certificate rotation
- **HSTS**: Enforced via NGINX Ingress
- **Anonymous auth disabled**: On the API server

- **Secret management**: External Secrets Operator syncs secrets from Vault, AWS SM, etc.
- **Alertmanager routing**: Pre-built templates for Slack, PagerDuty, and email

### Recommended Additions

- **Falco** for runtime threat detection
- **OPA/Gatekeeper** for policy enforcement
- **Dex** for OIDC authentication on the API server
- Restrict `ssh_allowed_cidrs` and `api_allowed_cidrs` in firewalls

## Enterprise Observability (LGTM Stack)

Deploy the full open-source observability stack:

```bash
make observability-full
```

This deploys:

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics storage (time-series) |
| **Grafana** | Dashboards and visualization |
| **Loki** | Log aggregation (30-day retention) |
| **Tempo** | Distributed tracing (14-day retention) |
| **Alloy** | Universal OTel collector (replaces Promtail) |
| **OTel Operator** | Auto-instrumentation for Python/Node.js/Java/Go |

### API Tracking (APM)

Add a single annotation to your Deployment to enable auto-instrumentation:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "otel-system/default"
```

This automatically generates RED metrics (Rate, Errors, Duration) and distributed traces.

### LLM Observability

Track token usage, model latency, and estimated costs for OpenAI/Anthropic/HuggingFace calls using OTel GenAI Semantic Conventions. See `docs/components/llm-observability.md`.

### Grafana Dashboards

Pre-built dashboards included:
- API Health (RED Metrics)
- Service Graph (topology map)
- LLM Observability (tokens, cost, latency)
- Grafana Alloy (collector health)

### Logging

Logs are available in Grafana under the Loki datasource. Example LogQL queries:
```
{namespace="production"}
{app="hello-world"} |= "error"
rate({namespace="production"}[5m])
```

## Backup & Disaster Recovery

### Velero (cluster state)

```bash
make velero
```

Pre-configured backup schedules:
- **Daily full backup** at 02:00 UTC (30-day retention)
- **Hourly critical namespaces** (production, argocd — 7-day retention)

Manual operations:
```bash
velero backup create manual-backup --include-namespaces '*'
velero backup get
velero restore create --from-backup <backup-name>
```

### etcd Snapshots

A CronJob in `kube-system` takes etcd snapshots every 6 hours:
```bash
kubectl apply -f kubernetes/backup/etcd-snapshot.yaml
```

## Monitoring

After deployment, access Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open [http://localhost:3000](http://localhost:3000) — default user `admin`.

Pre-loaded dashboards:
- Kubernetes cluster overview
- Node exporter (system metrics)
- NGINX Ingress Controller
- cert-manager
- API Health — RED Metrics (Rate, Errors, Duration)
- Service Graph — Topology Map
- LLM Observability (token usage, cost, model latency)
- Grafana Alloy — Collector Health
- Hetzner Cost & Capacity

## GitOps with ArgoCD

```bash
make argocd
```

Access the ArgoCD UI:

```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

Open [https://localhost:8443](https://localhost:8443).

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

The `app-of-apps.yaml` template enables managing all cluster applications from a single Git repository.

## Upgrading

### k3s Version

**Option 1: System Upgrade Controller (recommended)**

```bash
make upgrade-controller
```

Edit `kubernetes/system/upgrade-controller/upgrade-plan.yaml` with the target version, then:
```bash
kubectl apply -f kubernetes/system/upgrade-controller/upgrade-plan.yaml
kubectl get plans -n system-upgrade  # monitor progress
```

The controller drains, upgrades, and uncordons nodes automatically — control plane first, then workers.

**Option 2: Scripted rolling upgrade**

```bash
make upgrade VERSION=v1.31.0+k3s1
```

This runs `scripts/upgrade.sh` which drains/upgrades/uncordons each node sequentially with interactive confirmation.

**Option 3: Manual**

SSH into each node (control plane first, one at a time):
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.0+k3s1" sh -
```

### Helm Charts

```bash
helm repo update
helm upgrade --install <release> <chart> --namespace <ns> --values <values.yaml>
```

## Troubleshooting

### Nodes not joining

```bash
# Check cloud-init logs on the node
ssh root@<NODE_IP> journalctl -u k3s
ssh root@<NODE_IP> cat /var/log/cloud-init-output.log
```

### Cilium issues

```bash
kubectl -n kube-system exec -it ds/cilium -- cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test
```

### Load Balancer not routing

```bash
hcloud load-balancer describe <LB_NAME>
kubectl get svc -A | grep LoadBalancer
```

## License

MIT
