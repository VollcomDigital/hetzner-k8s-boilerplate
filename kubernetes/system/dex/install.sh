#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

NAMESPACE="dex"
DEX_DOMAIN="${DEX_DOMAIN:-dex.example.com}"

# Validate required env vars for GitHub connector
if [[ -z "${GITHUB_CLIENT_ID:-}" || -z "${GITHUB_CLIENT_SECRET:-}" ]]; then
  error "GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are required."
fi

# Generate client secrets if not provided
DEX_K8S_SECRET="${DEX_KUBERNETES_CLIENT_SECRET:-$(openssl rand -hex 16)}"
DEX_ARGOCD_SECRET="${DEX_ARGOCD_CLIENT_SECRET:-$(openssl rand -hex 16)}"

helm repo add dex https://charts.dexidp.io
helm repo update

kubectl apply -f kubernetes/system/dex/namespace.yaml

# Create secrets for connectors
kubectl create secret generic dex-connectors \
  --namespace "$NAMESPACE" \
  --from-literal=GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID}" \
  --from-literal=GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET}" \
  --from-literal=DEX_KUBERNETES_CLIENT_SECRET="$DEX_K8S_SECRET" \
  --from-literal=DEX_ARGOCD_CLIENT_SECRET="$DEX_ARGOCD_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install dex dex/dex \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/dex/values.yaml \
  --set "envFrom[0].secretRef.name=dex-connectors" \
  --wait --timeout 5m

echo ""
echo "============================================="
info "Dex OIDC Provider deployed"
echo "============================================="
echo ""
echo "  Dex URL: https://$DEX_DOMAIN"
echo "  Kubernetes client secret: $DEX_K8S_SECRET"
echo "  ArgoCD client secret:     $DEX_ARGOCD_SECRET"
echo ""
echo "To configure kubectl for OIDC login, install kubelogin:"
echo "  https://github.com/int128/kubelogin"
echo ""
echo "Then set up your kubeconfig:"
echo "  kubectl oidc-login setup \\"
echo "    --oidc-issuer-url=https://$DEX_DOMAIN \\"
echo "    --oidc-client-id=kubernetes \\"
echo "    --oidc-client-secret=$DEX_K8S_SECRET"
echo ""
echo "IMPORTANT: The k3s API server must be configured with OIDC flags."
echo "See: kubernetes/system/dex/README.md"
