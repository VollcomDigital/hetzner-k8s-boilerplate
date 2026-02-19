#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cert-manager"
ACME_EMAIL="${ACME_EMAIL:?ERROR: Set ACME_EMAIL environment variable}"

helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace "$NAMESPACE" \
  --set crds.enabled=true \
  --set replicaCount=2 \
  --set prometheus.enabled=true \
  --set prometheus.servicemonitor.enabled=true \
  --wait --timeout 5m

echo "Waiting for cert-manager webhook to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager-webhook \
  -n "$NAMESPACE" --timeout=120s

# Apply ClusterIssuers with email substitution
sed "s#\${ACME_EMAIL}#$ACME_EMAIL#g" \
  kubernetes/ingress/cert-manager/cluster-issuers.yaml | kubectl apply -f -

echo "cert-manager deployed with Let's Encrypt ClusterIssuers."
