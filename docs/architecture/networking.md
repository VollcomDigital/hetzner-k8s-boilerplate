# Networking

## Network Topology

- **Hetzner Private Network** (`10.0.0.0/16`) — all inter-node traffic stays private
- **Pod CIDR** (`10.42.0.0/16`) — managed by Cilium
- **Service CIDR** (`10.43.0.0/16`) — ClusterIP range
- **Cluster DNS** (`10.43.0.10`) — CoreDNS

## Cilium CNI

Cilium replaces both the default Flannel CNI and kube-proxy:

- **eBPF dataplane** — kernel-level packet processing, no iptables
- **kube-proxy replacement** — lower latency, better scalability
- **WireGuard encryption** — transparent pod-to-pod encryption
- **Hubble** — network flow observability (relay + UI)

## Firewalls

Two Hetzner firewalls with least-privilege rules:

### Control Plane

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Configurable | SSH |
| 6443 | TCP | Configurable | Kubernetes API |
| 2379-2380 | TCP | Private network | etcd |
| 9345 | TCP | Private network | k3s supervisor |
| 10250 | TCP | Private network | Kubelet |
| 4240, 8472-8473 | TCP/UDP | Private network | Cilium |

### Workers

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Configurable | SSH |
| 80, 443 | TCP | Any | Ingress traffic |
| 10250 | TCP | Private network | Kubelet |
| 30000-32767 | TCP | Any | NodePort range |
| 4240, 8472-8473 | TCP/UDP | Private network | Cilium |
