# Troubleshooting

## Nodes Not Joining

```bash
# Check cloud-init logs
ssh root@<NODE_IP> cat /var/log/cloud-init-output.log

# Check k3s service
ssh root@<NODE_IP> journalctl -u k3s -f

# Verify the node can reach the API LB
ssh root@<NODE_IP> curl -sk https://<LB_IP>:6443/healthz
```

## Cilium Issues

```bash
kubectl -n kube-system exec -it ds/cilium -- cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium connectivity test
```

## Load Balancer Not Routing

```bash
hcloud load-balancer describe <LB_NAME>
kubectl get svc -A | grep LoadBalancer
```

## Pods Stuck in Pending

```bash
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'

# Check resource availability
kubectl top nodes
kubectl describe node <node-name> | grep -A5 "Allocated resources"
```

## Certificate Issues

```bash
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>
kubectl get challenges -A
kubectl logs -n cert-manager -l app=cert-manager
```

## Smoke Test

Run the full health check suite:

```bash
make smoke-test
```

This verifies all core systems and deploys a test workload.
