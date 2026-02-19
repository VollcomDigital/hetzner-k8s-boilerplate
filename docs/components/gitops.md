# GitOps with ArgoCD

## Installation

```bash
make argocd
```

## Access

```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## App-of-Apps Pattern

All cluster components are defined as ArgoCD Application manifests in
`kubernetes/gitops/argocd/apps/`. The root `app-of-apps.yaml` manages them all.

### Sync Waves

| Wave | Component |
|------|-----------|
| 1 | Hetzner CCM |
| 2 | Hetzner CSI, System Upgrade Controller |
| 3 | NGINX Ingress, External Secrets |
| 4 | cert-manager |
| 5 | Monitoring |
| 6-7 | Logging (Loki, Promtail) |
| 8 | Velero |
| 9 | external-dns, Autoscaler |
| 10 | Security Policies |

## Deploying Your Application

Update the `repoURL` in Application manifests to point to your Git repository,
then ArgoCD will auto-sync changes on every commit.
