# Scaling

## Worker Nodes (Manual)

Update `worker_count` in `terraform.tfvars` and apply:

```bash
cd terraform && terraform apply
```

## Cluster Autoscaler (Automatic)

```bash
make autoscaler
```

The autoscaler watches for unschedulable pods and automatically provisions
new Hetzner Cloud servers. When demand drops, idle nodes are drained and deleted.

Configuration in `kubernetes/system/autoscaler/values.yaml`:

- `minSize: 2` — minimum worker nodes
- `maxSize: 10` — maximum worker nodes
- `scale-down-utilization-threshold: 0.5` — scale down if < 50% utilized

## Horizontal Pod Autoscaler

The sample app includes an HPA that scales pods based on CPU/memory.
k3s bundles metrics-server, which is verified during deployment.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```
