# Upgrading

## k3s Version

### Option 1: System Upgrade Controller (Recommended)

```bash
make upgrade-controller
```

Edit the version in `kubernetes/system/upgrade-controller/upgrade-plan.yaml`, then:

```bash
kubectl apply -f kubernetes/system/upgrade-controller/upgrade-plan.yaml
kubectl get plans -n system-upgrade
```

### Option 2: Scripted Rolling Upgrade

```bash
make upgrade VERSION=v1.31.0+k3s1
```

### Option 3: Manual

SSH into each node (control plane first):

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.0+k3s1" sh -
```

## Helm Charts

```bash
helm repo update
helm upgrade --install <release> <chart> --namespace <ns> --values <values.yaml>
```

With Renovate configured, Helm chart updates arrive as automated PRs.
