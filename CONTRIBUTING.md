# Contributing

Thank you for considering contributing to the Hetzner Kubernetes Boilerplate.

## Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USER/hetzner-k8s-boilerplate.git`
3. Create a feature branch: `git checkout -b feat/my-feature`
4. Make your changes
5. Ensure checks pass: `make lint`
6. Commit with semantic messages (see below)
7. Push and open a Pull Request

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready |
| `feat/*` | New features |
| `fix/*` | Bug fixes |
| `docs/*` | Documentation only |

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add Velero backup schedules
fix: correct NGINX values file path
perf: reduce Prometheus resource requests
docs: add autoscaler configuration guide
chore: update Helm chart versions
```

## Code Standards

### Terraform

- Run `terraform fmt -recursive` before committing
- All variables must have `description` and `type`
- Use `validation` blocks for inputs where possible
- Module outputs must have `description`

### Kubernetes Manifests

- All Deployments must have `resources.requests` and `resources.limits`
- Use `labels` consistently: `app.kubernetes.io/name`, `app.kubernetes.io/part-of`
- Helm values files must include comments referencing the upstream chart docs
- Security: non-root containers, read-only FS, drop all capabilities where feasible

### Shell Scripts

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Use functions for reusable logic
- Include colored output for user-facing scripts
- Quote all variable expansions

## Testing

Before submitting a PR:

```bash
make lint               # Terraform fmt + validate
make setup              # Pre-flight checks
```

CI will also run:
- `terraform validate`
- `kubeconform` against Kubernetes manifests
- `trivy` security scan on Terraform and Kubernetes configs

## Adding a New Component

1. Create a directory under the appropriate category:
   - `kubernetes/core/` — cluster-critical (CNI, CSI, CCM)
   - `kubernetes/system/` — operational tooling (autoscaler, DNS, upgrades)
   - `kubernetes/ingress/` — traffic management
   - `kubernetes/monitoring/` or `kubernetes/logging/` — observability
   - `kubernetes/security/` — policies, secrets, RBAC
2. Include at minimum:
   - `values.yaml` — Helm values (if Helm-based)
   - `install.sh` — idempotent installation script
   - `namespace.yaml` — dedicated namespace (if applicable)
3. Add a `make` target in the Makefile
4. Add an ArgoCD Application manifest in `kubernetes/gitops/argocd/apps/`
5. Update the README project structure and Make Targets sections
