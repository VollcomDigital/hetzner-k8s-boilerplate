# Hetzner Kubernetes Boilerplate (Production-Ready Plan)

This repository will become a reusable, industry-standard boilerplate to deploy and operate a Kubernetes cluster on Hetzner Cloud with strong defaults for security, reliability, and repeatability.

## 1) Goal

Build a template that enables teams to:

- Provision infrastructure using Infrastructure as Code (IaC)
- Bootstrap a highly available Kubernetes control plane
- Manage cluster add-ons and workloads via GitOps
- Enforce security and policy guardrails by default
- Operate the platform with observability, backups, and recovery runbooks

## 2) Architecture Decisions (Recommended Baseline)

### Core Stack

- **Infrastructure provisioning:** Terraform (`hcloud` + DNS + firewall + network resources)
- **Kubernetes OS/Bootstrap:** Talos Linux + `talosctl`
- **CNI / Networking:** Cilium (network policy + eBPF data plane)
- **Cloud integration:** Hetzner Cloud Controller Manager + Hetzner CSI
- **Ingress:** NGINX Ingress Controller (or Traefik if preferred)
- **TLS:** cert-manager + Let's Encrypt
- **DNS automation:** external-dns (Hetzner DNS)
- **GitOps:** FluxCD (preferred for lightweight bootstrap)
- **Secrets in Git:** SOPS + age
- **Policy engine:** Kyverno (or Gatekeeper)
- **Observability:** kube-prometheus-stack + Loki
- **Backup/restore:** Velero (cluster objects + PV backup target in S3-compatible object storage)

### Cluster Topology

- **Control plane:** 3 nodes (same network zone, separate hosts)
- **Worker nodes:** 3+ nodes (autoscaling-ready pattern for future)
- **Private network:** all node-to-node traffic private
- **Public entrypoints:** only ingress load balancer and tightly controlled API access
- **API endpoint:** fronted by Hetzner load balancer and protected via firewall allowlist/VPN

## 3) Repository Blueprint

```text
.
├── terraform/
│   ├── modules/
│   │   ├── network/
│   │   ├── firewall/
│   │   ├── servers/
│   │   ├── loadbalancer/
│   │   └── dns/
│   └── envs/
│       ├── dev/
│       └── prod/
├── talos/
│   ├── patches/
│   ├── generated/              # gitignored
│   └── scripts/
├── kubernetes/
│   ├── bootstrap/              # flux bootstrap manifests
│   ├── clusters/
│   │   ├── dev/
│   │   └── prod/
│   ├── infrastructure/         # ingress, cert-manager, cilium, csi, ccm
│   └── apps/
├── policies/                   # kyverno constraints and baselines
├── scripts/
├── .github/workflows/
├── Makefile
└── README.md
```

## 4) Implementation Phases

## Phase 0 - Foundations and Standards

**Deliverables**

- Branching and release strategy documented
- `pre-commit` hooks and formatting/lint policy
- Makefile task interface (`make init`, `make plan`, `make bootstrap`, `make verify`)
- Secret handling baseline (`.env.example`, SOPS + age setup)

**Exit criteria**

- Every local and CI command is deterministic and documented

## Phase 1 - Terraform Infrastructure

**Deliverables**

- Terraform modules for network, subnets, firewalls, servers, load balancers, DNS
- Environment overlays (`dev`, `prod`) using shared modules
- Remote state backend and lock strategy documented
- Outputs for Talos bootstrap (IPs, node names, LB endpoint)

**Exit criteria**

- `terraform plan` and `terraform apply` produce a full cluster-ready substrate

## Phase 2 - Kubernetes Bootstrap (Talos)

**Deliverables**

- Talos machine configs generated from Terraform outputs
- Control plane bootstrap automation scripts
- Kubeconfig retrieval and smoke checks
- Node labels/taints conventions documented

**Exit criteria**

- All control plane and worker nodes join successfully
- `kubectl get nodes` shows healthy cluster

## Phase 3 - Mandatory Platform Add-ons

**Deliverables**

- Hetzner CCM and CSI installed
- Cilium deployed with baseline network policies
- Ingress controller + cert-manager + external-dns installed
- Default StorageClass and PVC test workload

**Exit criteria**

- Public test app reachable over HTTPS with valid certificate
- Dynamic volume provisioning works

## Phase 4 - GitOps and Environment Promotion

**Deliverables**

- Flux bootstrap and source/reconciliation strategy
- Folder conventions for `clusters/dev` and `clusters/prod`
- Promotion flow (dev -> prod) via pull request policy
- Drift detection and reconciliation alerting

**Exit criteria**

- Merging manifests to main branch reconciles cluster automatically

## Phase 5 - Security Hardening and Compliance

**Deliverables**

- Pod Security admission defaults and namespace policies
- Kyverno policies (no latest tags, resource limits required, privileged constraints)
- Image scanning in CI (Trivy)
- RBAC least-privilege templates and break-glass procedure

**Exit criteria**

- Security baseline checks pass in CI and admission controls block non-compliant manifests

## Phase 6 - Observability, Backups, and Recovery

**Deliverables**

- Metrics, logs, and alert routing configured
- Velero backup schedules + restore playbooks
- Etcd backup strategy and disaster recovery runbook
- SLOs and alert threshold baselines

**Exit criteria**

- Successful restore drill documented end-to-end

## 5) CI/CD Quality Gates (Minimum)

Add GitHub Actions workflows for:

- Terraform `fmt`, `validate`, `plan`, `tflint`, `checkov`
- Kubernetes manifest validation (`kubeconform`, `kube-linter`)
- Helm linting (if charts are used)
- YAML linting and policy tests
- Optional integration smoke tests against a disposable test cluster

All pull requests must pass quality gates before merge.

## 6) Security and Reliability Defaults

- No direct SSH administration for routine operations (prefer Talos API + GitOps workflows)
- API server access restricted via firewall/VPN/IP allowlist
- Secrets encrypted at rest in Git with SOPS
- Enforce `requests/limits`, anti-affinity for critical workloads, and PodDisruptionBudgets
- Multi-AZ equivalent pattern is limited on Hetzner; prioritize same-zone low-latency control plane plus tested backups/restore

## 7) Definition of Done (Boilerplate v1)

The boilerplate is ready when a new team can:

1. Clone the repo, set environment variables/secrets, and run documented commands
2. Provision infra with Terraform
3. Bootstrap Kubernetes and core add-ons
4. Deploy a sample app via GitOps with TLS and DNS
5. Observe metrics/logs and trigger a backup + restore validation
6. Pass all CI checks without manual exceptions

## 8) Suggested First Iteration (1-2 weeks)

1. Scaffold repository structure + Makefile task interface
2. Build Terraform modules for network/firewall/servers/LB
3. Bootstrap Talos cluster and validate node lifecycle
4. Install CCM/CSI/Cilium/Ingress/cert-manager
5. Add Flux + one sample app with HTTPS endpoint
6. Add CI checks for Terraform and manifest validation

---

If you want, the next step can be implementing this plan directly in this repository as a working scaffold (folders, Makefile, Terraform module stubs, and GitHub Actions) so you can start deploying immediately.