# Architecture Overview

```
                         Internet
                            │
                  ┌─────────┴──────────┐
                  │   Hetzner Cloud     │
                  │                      │
         ┌────────────────┐    ┌────────────────┐
         │  API Server LB │    │  Ingress LB    │
         │  :6443 / :9345 │    │  :80 / :443    │
         └───────┬────────┘    └───────┬────────┘
                 │                      │
    ┌────────────┼──────────────────────┼────────────┐
    │            │   Private Network    │            │
    │            │     10.0.0.0/16      │            │
    │   ┌────────┴────────┐   ┌────────┴────────┐   │
    │   │  Control Plane  │   │     Workers     │   │
    │   │   3x cpx31      │   │    3x cpx41     │   │
    │   │                  │   │                  │   │
    │   │  k3s server     │   │  k3s agent      │   │
    │   │  etcd           │   │  NGINX Ingress  │   │
    │   │  Cilium         │   │  Cilium         │   │
    │   │  CCM            │   │  Workloads      │   │
    │   └─────────────────┘   └─────────────────┘   │
    │                                                │
    │   Pod Network: 10.42.0.0/16 (Cilium)          │
    │   Svc Network: 10.43.0.0/16                    │
    │   Encryption: WireGuard (pod-to-pod)           │
    └────────────────────────────────────────────────┘
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| K8s distribution | k3s | Lightweight, CNCF-certified, no managed K8s on Hetzner |
| CNI | Cilium | eBPF performance, replaces kube-proxy, WireGuard encryption, Hubble observability |
| HA strategy | 3 CP + LB | Embedded etcd quorum, API fronted by Hetzner LB |
| IaC | Terraform (modular) | Reproducible, stateful, team-friendly |
| GitOps | ArgoCD | App-of-apps pattern, OIDC-ready, strong community |
| Monitoring | kube-prometheus-stack | Industry standard, batteries-included |
| Logging | Loki + Promtail | Grafana-native, low resource overhead vs ELK |
| Backup | Velero + etcd snapshots | Full cluster state + granular namespace recovery |
