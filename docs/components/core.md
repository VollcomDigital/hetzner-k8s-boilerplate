# Core Components

## Hetzner Cloud Controller Manager (CCM)

Integrates Kubernetes with Hetzner Cloud:

- Auto-detects node metadata (region, type, IPs)
- Provisions Hetzner Load Balancers for `type: LoadBalancer` services
- Manages node lifecycle (cordons terminated nodes)

```bash
make ccm
```

## Hetzner CSI Driver

Provides persistent storage via Hetzner Volumes:

```bash
make csi
```

### Storage Classes

| Name | Type | Reclaim | Default |
|------|------|---------|---------|
| `hcloud-volumes` | Local NVMe | Delete | Yes |
| `hcloud-volumes-retain` | Local NVMe | Retain | No |
| `hcloud-volumes-network` | Network-attached | Delete | No |

## Cilium CNI

Deployed via cloud-init on the first control-plane node. Includes:

- eBPF dataplane (kube-proxy replacement)
- WireGuard pod-to-pod encryption
- Hubble relay and UI for network observability

Access Hubble UI:

```bash
make hubble
# or port-forward:
kubectl port-forward -n kube-system svc/hubble-ui 8080:80
```
