#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="tracing"
MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-minio-admin}"
MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD must be set}"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/tracing/namespace.yaml

echo "Deploying Grafana Tempo (distributed tracing backend)..."
helm upgrade --install tempo grafana/tempo-distributed \
  --namespace "$NAMESPACE" \
  --values kubernetes/tracing/values-tempo.yaml \
  --set "storage.trace.s3.access_key=${MINIO_ACCESS_KEY}" \
  --set "storage.trace.s3.secret_key=${MINIO_SECRET_KEY}" \
  --wait --timeout 10m

echo "Registering Tempo datasource in Grafana..."
kubectl apply -f kubernetes/tracing/grafana-datasource.yaml

echo "============================================="
echo " Tempo distributed tracing deployed"
echo " Namespace: $NAMESPACE"
echo "============================================="
echo ""
echo "OTLP ingestion endpoints (from apps/Alloy):"
echo "  gRPC: tempo-distributor.tracing.svc.cluster.local:4317"
echo "  HTTP: tempo-distributor.tracing.svc.cluster.local:4318"
echo ""
echo "Query endpoint (from Grafana):"
echo "  http://tempo-query-frontend.tracing.svc.cluster.local:3100"
echo ""
echo "View traces in Grafana → Explore → Tempo datasource"
echo "  TraceQL example: { .service.name=\"api-service\" && duration > 1s }"
echo ""
echo "Service Graph in Grafana → Explore → Tempo → Service Graph tab"
