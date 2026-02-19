#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"
GRAFANA_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 24)}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/monitoring/namespace.yaml

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values kubernetes/monitoring/values.yaml \
  --set grafana.adminPassword="$GRAFANA_PASSWORD" \
  --wait --timeout 10m

echo "============================================="
echo " Monitoring stack deployed successfully"
echo " Grafana admin password: $GRAFANA_PASSWORD"
echo "============================================="
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "  Open http://localhost:3000 (admin / <password above>)"
