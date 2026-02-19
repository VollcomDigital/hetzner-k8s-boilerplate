# Hetzner Kubernetes Boilerplate

Production-ready Kubernetes cluster on [Hetzner Cloud](https://www.hetzner.com/cloud) using **Terraform** and **k3s**, following industry best practices.

## What's Included

| Category | Components |
|----------|-----------|
| **Infrastructure** | Terraform modules for network, firewall, servers, load balancer |
| **Kubernetes** | k3s with Cilium CNI, WireGuard encryption |
| **Cloud Integration** | Hetzner CCM, CSI driver, Cluster Autoscaler |
| **Traffic** | NGINX Ingress, cert-manager, external-dns |
| **Observability** | Prometheus, Grafana, Alertmanager, Loki, Promtail, Hubble |
| **Security** | Network policies, RBAC, Pod Security Standards, External Secrets, Dex OIDC |
| **Operations** | Velero backup, System Upgrade Controller, rolling upgrade scripts |
| **GitOps** | ArgoCD with app-of-apps pattern |
| **CI/CD** | GitHub Actions for validation, security scanning, app deployment |
| **Registry** | Harbor private container registry |

## Quick Start

```bash
git clone https://github.com/VollcomDigital/hetzner-k8s-boilerplate.git
cd hetzner-k8s-boilerplate
cp .env.example .env && cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit .env and terraform.tfvars with your values
make setup    # Pre-flight checks
make plan     # Preview infrastructure
make deploy   # Deploy core components
```

See [Getting Started](getting-started/quick-start.md) for the full guide.

## Cost Estimate

| Environment | Config | Monthly Cost |
|-------------|--------|-------------|
| **Dev** | 1 CP (cpx21) + 2 Workers (cpx21) | ~€30 |
| **Staging** | 3 CP (cpx21) + 2 Workers (cpx31) | ~€65 |
| **Production** | 3 CP (cpx31) + 3 Workers (cpx41) | ~€175 |

Plus load balancers (~€6 each) and persistent volumes (~€0.05/GB/mo).
