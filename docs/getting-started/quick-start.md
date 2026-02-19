# Quick Start

## 1. Clone and Configure

```bash
git clone https://github.com/VollcomDigital/hetzner-k8s-boilerplate.git
cd hetzner-k8s-boilerplate

cp .env.example .env
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit both files. At minimum, set:

- `HCLOUD_TOKEN` — Your Hetzner Cloud API token
- `ACME_EMAIL` — Email for Let's Encrypt certificates

## 2. Choose an Environment

Use pre-built environment presets:

=== "Development"

    ```bash
    cd terraform && terraform plan -var-file=envs/dev.tfvars
    ```
    1 CP + 2 Workers (cpx21) — ~€30/month

=== "Staging"

    ```bash
    cd terraform && terraform plan -var-file=envs/staging.tfvars
    ```
    3 CP (cpx21) + 2 Workers (cpx31) — ~€65/month

=== "Production"

    ```bash
    cd terraform && terraform plan -var-file=envs/production.tfvars
    ```
    3 CP (cpx31) + 3 Workers (cpx41) — ~€175/month

Or customize `terraform/terraform.tfvars` directly.

## 3. Deploy

```bash
# Core components only
make deploy

# Everything including optional components
make deploy-all

# Selective optional components
./scripts/deploy.sh --logging --argocd --security
```

## 4. Access the Cluster

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

## 5. Verify

```bash
make smoke-test
```

## Next Steps

- `make argocd` — Set up GitOps
- `make security` — Apply network policies and RBAC
- `make logging` — Centralized log aggregation
- `make dex` — OIDC authentication
