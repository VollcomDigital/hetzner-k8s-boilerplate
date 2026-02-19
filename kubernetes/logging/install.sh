#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="logging"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/logging/namespace.yaml

echo "Deploying Loki..."
helm upgrade --install loki grafana/loki \
  --namespace "$NAMESPACE" \
  --values kubernetes/logging/values-loki.yaml \
  --wait --timeout 5m

echo "Deploying Promtail..."
helm upgrade --install promtail grafana/promtail \
  --namespace "$NAMESPACE" \
  --values kubernetes/logging/values-promtail.yaml \
  --wait --timeout 5m

echo "Adding Loki datasource to Grafana..."
kubectl apply -f kubernetes/logging/grafana-datasource.yaml

echo "============================================="
echo " Logging stack deployed (Loki + Promtail)"
echo "============================================="
echo ""
echo "Query logs in Grafana → Explore → Loki datasource"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo ""
echo "Example LogQL queries:"
echo '  {namespace="production"}'
echo '  {app="hello-world"} |= "error"'
echo '  rate({namespace="production"}[5m])'
