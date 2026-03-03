#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="logging"
MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-minio-admin}"
MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD must be set}"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/logging/namespace.yaml

echo "Deploying Loki (SimpleScalable mode with MinIO backend)..."
helm upgrade --install loki grafana/loki \
  --namespace "$NAMESPACE" \
  --values kubernetes/logging/values-loki.yaml \
  --set "loki.storage.s3.accessKeyId=${MINIO_ACCESS_KEY}" \
  --set "loki.storage.s3.secretAccessKey=${MINIO_SECRET_KEY}" \
  --wait --timeout 10m

echo "Adding Loki datasource to Grafana..."
kubectl apply -f kubernetes/logging/grafana-datasource.yaml

echo "Deploying Grafana Alloy (OTel-native log collector + OTLP receiver)..."
bash kubernetes/alloy/install.sh

echo "============================================="
echo " Logging + Collection stack deployed"
echo " Loki (SimpleScalable) + Grafana Alloy"
echo "============================================="
echo ""
echo "Log ingestion via Alloy (auto-collects pod logs):"
echo "  All pod stdout/stderr shipped to Loki automatically"
echo ""
echo "Query logs in Grafana → Explore → Loki datasource"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo ""
echo "Example LogQL queries:"
echo '  {namespace="production"}'
echo '  {app="api-service"} |= "error"'
echo '  {namespace="production"} | json | level="error"'
echo '  rate({namespace="production"}[5m])'
