# Prerequisites

## Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | Infrastructure provisioning |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Kubernetes CLI |
| [Helm](https://helm.sh/docs/intro/install/) | >= 3.x | Package manager for K8s |
| [jq](https://jqlang.github.io/jq/) | >= 1.6 | JSON processor (used by scripts) |

## Optional Tools

| Tool | Purpose |
|------|---------|
| [hcloud CLI](https://github.com/hetznercloud/cli) | Hetzner Cloud debugging |
| [cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli) | CNI troubleshooting |
| [kubelogin](https://github.com/int128/kubelogin) | OIDC authentication for kubectl |
| [velero CLI](https://velero.io/docs/main/basic-install/) | Backup management |
| [argocd CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | GitOps management |

## Accounts & Credentials

1. **Hetzner Cloud API Token** — [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Security → API Tokens (read/write)
2. **SSH Key Pair** — `ssh-keygen -t ed25519 -C "k8s-cluster"`
3. **Email address** — For Let's Encrypt certificates
4. **DNS provider credentials** (optional) — Cloudflare API token or Hetzner DNS token

## Verify Setup

```bash
make setup
```

This checks for all required tools and credentials.
