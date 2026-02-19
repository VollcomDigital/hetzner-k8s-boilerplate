# Backup & Disaster Recovery

## Velero

```bash
make velero
```

### Backup Schedules

| Schedule | Scope | Retention |
|----------|-------|-----------|
| Daily at 02:00 UTC | All namespaces | 30 days |
| Hourly | production, argocd | 7 days |

### Manual Operations

```bash
# Create backup
velero backup create manual-$(date +%Y%m%d) --include-namespaces '*'

# List backups
velero backup get

# Restore
velero restore create --from-backup <backup-name>

# Restore single namespace
velero restore create --from-backup <backup-name> --include-namespaces production
```

## etcd Snapshots

A CronJob takes etcd snapshots every 6 hours on control-plane nodes:

```bash
kubectl apply -f kubernetes/backup/etcd-snapshot.yaml
```

Snapshots are stored at `/var/lib/rancher/k3s/server/db/snapshots/` on CP nodes.
