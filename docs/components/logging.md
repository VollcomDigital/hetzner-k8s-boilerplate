# Logging

## Loki + Promtail

```bash
make logging
```

- **Loki** — log aggregation backend (single-binary mode, 30-day retention)
- **Promtail** — DaemonSet that ships container logs to Loki

Logs are available in Grafana under the Loki datasource.

### Example LogQL Queries

```
{namespace="production"}
{app="my-app"} |= "error"
{namespace="production"} | json | level="error"
rate({namespace="production"}[5m])
```

### Storage

Loki stores data on a 50Gi Hetzner Volume. Adjust in `kubernetes/logging/values-loki.yaml`.
