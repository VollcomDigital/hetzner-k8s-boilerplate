#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="external-dns"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
helm repo update

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Ensure the provider credentials secret exists
if ! kubectl get secret -n "$NAMESPACE" cloudflare-credentials &>/dev/null; then
  if [[ -n "${CF_API_TOKEN:-}" ]]; then
    kubectl create secret generic cloudflare-credentials \
      --namespace "$NAMESPACE" \
      --from-literal=api-token="$CF_API_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    echo "WARNING: Set CF_API_TOKEN env var or create the cloudflare-credentials secret manually."
    echo "  kubectl create secret generic cloudflare-credentials \\"
    echo "    --namespace $NAMESPACE \\"
    echo "    --from-literal=api-token=YOUR_TOKEN"
  fi
fi

helm upgrade --install external-dns external-dns/external-dns \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/external-dns/values.yaml \
  --wait --timeout 5m

echo "============================================="
echo " external-dns deployed"
echo "============================================="
echo ""
echo "DNS records will be auto-created for Ingress resources"
echo "with hosts matching the configured domainFilters."
