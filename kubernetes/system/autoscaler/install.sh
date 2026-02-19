#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kube-system"

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/autoscaler/values.yaml \
  --wait --timeout 5m

echo "============================================="
echo " Hetzner Cluster Autoscaler deployed"
echo "============================================="
echo ""
echo "Worker nodes will scale between min/max based on pod demand."
echo ""
echo "Monitor autoscaler:"
echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler -f"
echo "  kubectl get configmap -n kube-system cluster-autoscaler-status -o yaml"
