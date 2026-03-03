#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="storage"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minio-admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-$(openssl rand -base64 24)}"

helm repo add minio https://charts.min.io/
helm repo update

kubectl apply -f kubernetes/storage/minio/namespace.yaml

echo "Deploying MinIO (S3-compatible object storage for Loki + Tempo)..."
helm upgrade --install minio minio/minio \
  --namespace "$NAMESPACE" \
  --values kubernetes/storage/minio/values-minio.yaml \
  --set rootUser="$MINIO_ROOT_USER" \
  --set rootPassword="$MINIO_ROOT_PASSWORD" \
  --wait --timeout 5m

echo "============================================="
echo " MinIO deployed in namespace: $NAMESPACE"
echo " Root user:     $MINIO_ROOT_USER"
echo " Root password: $MINIO_ROOT_PASSWORD"
echo "============================================="
echo ""
echo "IMPORTANT: Store these credentials — they are needed for:"
echo "  - kubernetes/logging/values-loki.yaml (loki.storage.s3.*)"
echo "  - kubernetes/tracing/values-tempo.yaml (tempo.structuredConfig.storage.trace.s3.*)"
echo ""
echo "Console (port-forward): kubectl port-forward -n storage svc/minio-console 9001:9001"
echo "  Open http://localhost:9001 ($MINIO_ROOT_USER / $MINIO_ROOT_PASSWORD)"
echo ""
echo "API endpoint (in-cluster): http://minio.storage.svc.cluster.local:9000"
