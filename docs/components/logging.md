# Logging

## Loki + Promtail / Alloy

```bash
make logging
```

- **Loki** — log aggregation backend (single-binary mode, 30-day retention)
- **Promtail** — DaemonSet that ships container logs to Loki (legacy)
- **Grafana Alloy** — Universal collector that replaces Promtail (recommended)

Logs are available in Grafana under the Loki datasource.

### Migration to Alloy

Grafana Alloy replaces Promtail as the log collector while also handling metrics and traces. To migrate:

1. Deploy Alloy: `make collector`
2. Verify logs are flowing in Grafana → Explore → Loki
3. Uninstall Promtail: `helm uninstall promtail -n logging`

See [Collector](collector.md) for full Alloy documentation.

### Example LogQL Queries

```
{namespace="production"}
{app="my-app"} |= "error"
{namespace="production"} | json | level="error"
rate({namespace="production"}[5m])
```

### Trace-to-Log Correlation

When using the full LGTM stack (with Tempo), you can jump from a trace span directly to the corresponding logs. The Tempo datasource in Grafana is pre-configured with trace-to-logs linking.

### Storage

Loki stores data on a 50Gi Hetzner Volume. Adjust in `kubernetes/logging/values-loki.yaml`.
