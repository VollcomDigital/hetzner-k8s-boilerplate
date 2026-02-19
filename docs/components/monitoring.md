# Monitoring

## kube-prometheus-stack

```bash
make monitoring
```

Deploys Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics.

### Access Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open [http://localhost:3000](http://localhost:3000) — user `admin`.

### Pre-loaded Dashboards

- Kubernetes cluster overview
- Node exporter (system metrics)
- NGINX Ingress Controller
- cert-manager
- Hetzner Cost & Capacity

### Alertmanager

Configure alert routing in `kubernetes/monitoring/alertmanager-config.yaml`.
Templates included for Slack, PagerDuty, and email receivers.

## Hetzner Cost Dashboard

A custom Grafana dashboard showing estimated monthly costs:

- Server costs (by node type)
- Volume costs (by PV capacity)
- Load balancer costs
- CPU/memory utilization vs capacity

Import from `kubernetes/monitoring/dashboards/hetzner-cost.json`.
