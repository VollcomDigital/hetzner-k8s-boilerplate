# Hetzner Cloud Controller Manager

The CCM integrates Kubernetes with Hetzner Cloud to provide:

- **Node lifecycle management** — auto-detects node metadata (region, type, IPs)
- **Load Balancer provisioning** — creates Hetzner LBs for `type: LoadBalancer` services
- **Route management** — configures routes for pod networking via Hetzner private networks

## Prerequisites

A secret named `hcloud` must exist in `kube-system` with:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: "<HCLOUD_API_TOKEN>"
  network: "<NETWORK_NAME>"
```

This is automatically created by the control-plane cloud-init script.

## Apply

```bash
kubectl apply -k kubernetes/core/hcloud-ccm/
```
