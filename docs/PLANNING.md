# Hetzner Kubernetes Boilerplate — Planning Document

## Executive Summary

This document outlines the architecture and implementation plan for a production-ready Kubernetes boilerplate deployed on Hetzner Cloud, following industry standards (CNCF landscape, 12-factor app, GitOps).

---

## 1. Technology Stack Decisions

### 1.1 Cluster Distribution

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **k3s** | Lightweight, single binary, low resource footprint, built-in CRI, SQLite/etcd | Less "vanilla" K8s | ✅ **Recommended** for small/medium clusters |
| **kubeadm** | Upstream vanilla, maximum control | Heavier setup, more components | For enterprises needing strict compliance |
| **RKE2** | Rancher hardened, FIPS, CIS benchmark | Heavier, Rancher dependency | For regulated environments |

**Decision:** **k3s** — Ideal for Hetzner VPS (often limited RAM). Certified Kubernetes, 50% less memory than k8s.

### 1.2 Infrastructure as Code (IaC)

- **Terraform** — Industry standard for cloud provisioning
- **Ansible** — For node configuration (SSH-based, agentless)
- **Packer** (optional) — Pre-bake images with k3s pre-installed

**Structure:**
```
terraform/           # Hetzner Cloud resources (servers, LB, firewall, volumes)
ansible/             # Cluster bootstrap, node configuration
scripts/             # Helper scripts, idempotent
```

### 1.3 Hetzner Integration Stack

| Component | Purpose |
|-----------|---------|
| **hcloud-cloud-controller-manager** | LB creation, node metadata, routes |
| **csi-driver-hcloud** | Persistent volume provisioning from Hetzner Block Storage |
| **Hetzner Firewall** | L3/L4 security at cloud edge |

---

## 2. Architecture Overview

### 2.1 Network Topology

```
                    [Internet]
                         |
                    [Hetzner LB]  ← Ingress Traffic (L4)
                         |
    ┌────────────────────┼────────────────────┐
    |              Private Network             |
    |  ┌──────────┐ ┌──────────┐ ┌──────────┐ |
    |  | Control  | | Control  | | Control  | |  Control Plane (3 nodes HA)
    |  | Node 1   | | Node 2   | | Node 3   | |
    |  └──────────┘ └──────────┘ └──────────┘ |
    |  ┌──────────┐ ┌──────────┐ ┌──────────┐ |
    |  | Worker 1 | | Worker 2 | | Worker N | |  Worker Pool
    |  └──────────┘ └──────────┘ └──────────┘ |
    └────────────────────────────────────────┘
```

### 2.2 Node Sizing (Hetzner CX/CPX)

| Role | Recommended | Minimum |
|------|-------------|---------|
| Control Plane | CPX31 (4 vCPU, 8 GB) × 3 | CX22 (2 vCPU, 4 GB) |
| Worker | CPX31 or CPX41 | CX22 |

---

## 3. Component Breakdown

### 3.1 Phase 1: Infrastructure (Terraform)

| Resource | Configuration |
|----------|----------------|
| **SSH Key** | Import or generate, store in Terraform state (encrypted) |
| **Private Network** | 10.0.0.0/16, connect all nodes |
| **Firewall** | Allow: 22 (SSH), 6443 (K8s API), 80/443 (ingress); internal: all |
| **Placement** | Use `location` or `placement_group` for spread/HA |
| **Load Balancer** | L4, TCP 6443 + 80 + 443, attach to control-plane |

### 3.2 Phase 2: Cluster Bootstrap (Ansible)

1. **Prerequisites**
   - Install containerd, kernel modules (overlay, br_netfilter)
   - Disable swap, set `sysctl` for K8s
   - Configure private network as primary

2. **k3s Installation**
   - Control-plane: `k3s server` with `--cluster-init`, TLS SANs for LB
   - Workers: `k3s agent` joining via first control-plane
   - HA: Use embedded etcd (`--cluster-init` on first, `--server` on 2nd/3rd)

3. **Post-install**
   - `kubectl` config to local/admin
   - Verify node Ready status

### 3.3 Phase 3: Cloud Integration

| Component | Helm Chart / Manifest | Notes |
|-----------|------------------------|-------|
| **hcloud-cloud-controller-manager** | Official manifests | Requires `HCLOUD_TOKEN`, node labels |
| **csi-driver-hcloud** | Official manifests | For PVC → Hetzner Volume |
| **Hetzner Firewall** | Terraform | Attach to all nodes |

### 3.4 Phase 4: Networking & Ingress

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **CNI** | k3s default (Flannel) or Cilium | Cilium for advanced policies, observability |
| **Ingress Controller** | Traefik (k3s default) or NGINX Ingress | Traefik ships with k3s |
| **Certificate Manager** | cert-manager | ACME (Let's Encrypt) automation |

### 3.5 Phase 5: GitOps & App Deployment

| Tool | Purpose |
|------|---------|
| **Flux** or **Argo CD** | GitOps — cluster state from Git |
| **Helm** | Package management |
| **Kustomize** | Environment overlays (dev/staging/prod) |

### 3.6 Phase 6: Observability

| Stack | Components |
|-------|------------|
| **Metrics** | Prometheus (kube-prometheus-stack) |
| **Dashboards** | Grafana |
| **Logging** | Loki + Promtail (lightweight) or Vector |
| **Tracing** | Optional: Tempo/Jaeger |

### 3.7 Phase 7: Security Hardening

- **RBAC** — Least privilege, no default cluster-admin for apps
- **Pod Security** — Pod Security Standards (restricted)
- **Network Policies** — Deny-all default, explicit allow
- **Secrets** — External Secrets Operator + Vault/SOPS
- **CIS Benchmark** — kube-bench or RKE2 compliance

---

## 4. Directory Structure (Proposed)

```
hetzner-k8s-boilerplate/
├── README.md
├── docs/
│   ├── PLANNING.md          # This file
│   ├── ARCHITECTURE.md      # Detailed diagrams
│   └── RUNBOOK.md           # Ops procedures
├── terraform/
│   ├── modules/
│   │   ├── hcloud-cluster/  # Reusable Hetzner cluster module
│   │   └── firewall/
│   ├── environments/
│   │   ├── dev/
│   │   └── prod/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ansible/
│   ├── inventory/           # Dynamic or static inventory
│   ├── group_vars/
│   ├── roles/
│   │   ├── k3s-control/
│   │   ├── k3s-worker/
│   │   └── prerequisites/
│   └── playbooks/
│       ├── bootstrap.yml
│       └── upgrade.yml
├── kubernetes/
│   ├── base/                # Kustomize base
│   │   ├── namespace/
│   │   ├── ccm/
│   │   ├── csi/
│   │   ├── cert-manager/
│   │   ├── ingress/
│   │   └── monitoring/
│   ├── overlays/
│   │   ├── dev/
│   │   └── prod/
│   └── flux/                # Flux Kustomizations
├── scripts/
│   ├── deploy.sh            # End-to-end deploy
│   ├── destroy.sh
│   └── health-check.sh
└── .env.example             # Required env vars (no secrets)
```

---

## 5. Implementation Phases (Roadmap)

| Phase | Scope | Estimated Effort |
|-------|-------|------------------|
| **1** | Terraform: VMs, network, firewall, LB | 2–3 days |
| **2** | Ansible: Prerequisites + k3s bootstrap | 2–3 days |
| **3** | Hetzner CCM + CSI | 1 day |
| **4** | Ingress + cert-manager | 1 day |
| **5** | Flux/Argo + sample app | 1–2 days |
| **6** | Monitoring stack | 1–2 days |
| **7** | Documentation, runbook, security | 1–2 days |

**Total:** ~10–14 days for MVP.

---

## 6. Environment Variables & Secrets

| Variable | Source | Purpose |
|----------|--------|---------|
| `HCLOUD_TOKEN` | Vault / CI secret | Terraform + CCM + CSI |
| `SSH_PRIVATE_KEY` | Secure store | Ansible/SSH |
| `FLUX_GITHUB_TOKEN` | GitOps | Flux repo access |
| `ACME_EMAIL` | Config | cert-manager Let's Encrypt |

**Rule:** Never commit secrets. Use `.env.example` with placeholders.

---

## 7. Idempotency & Safety

- **Terraform:** `terraform plan` before `apply`; state in S3 or Terraform Cloud
- **Ansible:** All playbooks idempotent; use `--check` (dry-run) when possible
- **Destruction:** `destroy.sh` should require explicit confirmation + backup reminder

---

## 8. References & Standards

- [Hetzner Cloud API](https://docs.hetzner.cloud/)
- [k3s Documentation](https://docs.k3s.io/)
- [hcloud-cloud-controller-manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)
- [csi-driver-hcloud](https://github.com/hetznercloud/csi-driver)
- [CNCF Cloud Native Trail Map](https://raw.githubusercontent.com/cncf/trailmap/master/CNCF_TrailMap_latest.png)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

---

## 9. Open Decisions (To Resolve)

1. **High Availability:** 3-node control plane vs single-node for dev?
2. **Backup:** etcd backup strategy (Velero, manual snapshots)?
3. **Upgrade Strategy:** In-place k3s upgrade vs rolling new nodes?
4. **Multi-region:** Single `nbg1`/`fsn1`/`hel1` or multi-location?

---

*Document version: 1.0 | Last updated: 2025-02-18*
