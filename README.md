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
| **Monitoring** | kube-prometheus-stack | Prometheus + Grafana + Alertmanager |
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
make deploy
```

This runs the full pipeline:
1. Provisions Hetzner infrastructure (network, firewalls, LB, servers)
2. Bootstraps k3s HA cluster via cloud-init
3. Installs Cilium CNI with WireGuard encryption
4. Deploys Hetzner CCM and CSI driver
5. Installs NGINX Ingress Controller
6. Deploys cert-manager with Let's Encrypt
7. Sets up Prometheus + Grafana monitoring

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
│       ├── server/                      # Control-plane + worker provisioning
│       └── load-balancer/               # API server HA load balancer
├── kubernetes/
│   ├── core/
│   │   ├── hcloud-ccm/                  # Hetzner Cloud Controller Manager
│   │   └── hcloud-csi/                  # Hetzner CSI Driver + StorageClasses
│   ├── ingress/
│   │   ├── nginx/                       # NGINX Ingress (Helm values + install)
│   │   └── cert-manager/               # cert-manager + Let's Encrypt issuers
│   ├── monitoring/                      # kube-prometheus-stack (Helm values)
│   ├── security/
│   │   ├── network-policies/            # Default deny + allow rules
│   │   ├── rbac/                        # ClusterRoles for reader/deployer
│   │   └── pod-security.yaml            # Pod Security Standards per namespace
│   └── gitops/
│       └── argocd/                      # ArgoCD install + app-of-apps pattern
├── scripts/
│   ├── setup.sh                         # Pre-flight checks
│   ├── deploy.sh                        # Full deployment pipeline
│   └── destroy.sh                       # Teardown with confirmation
├── .github/workflows/
│   └── validate.yml                     # CI: terraform validate, kubeconform, trivy
├── Makefile                             # All operations via make targets
├── .env.example                         # Environment variable template
└── .gitignore
```

## Make Targets

```
make help          Show all available targets
make setup         Run pre-flight checks
make plan          Preview Terraform changes
make apply         Apply Terraform changes
make deploy        Full deployment (infra + all K8s components)
make destroy       Tear down everything (with confirmation)
make ccm           Deploy Hetzner Cloud Controller Manager
make csi           Deploy Hetzner CSI Driver
make ingress       Deploy NGINX Ingress Controller
make cert-manager  Deploy cert-manager
make monitoring    Deploy Prometheus + Grafana
make argocd        Deploy ArgoCD
make security      Apply network policies + RBAC
make kubeconfig    Fetch kubeconfig from cluster
make status        Cluster health overview
make nodes         List nodes
make pods          List all pods
make fmt           Format Terraform files
make validate      Validate Terraform configuration
make lint          Format + validate
make clean         Remove local artifacts
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

### Recommended Additions

- **Sealed Secrets** or **External Secrets Operator** for secret management
- **Falco** for runtime threat detection
- **OPA/Gatekeeper** for policy enforcement
- **Dex** for OIDC authentication on the API server
- Restrict `ssh_allowed_cidrs` and `api_allowed_cidrs` in firewalls

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

1. Update `k3s_version` in `terraform.tfvars`
2. SSH into each node and run:
   ```bash
   curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.0+k3s1" sh -
   ```
3. Upgrade control-plane nodes first (one at a time), then workers

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
