#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

NAMESPACE="external-dns"
DNS_PROVIDER="${DNS_PROVIDER:-cloudflare}"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
helm repo update

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

case "$DNS_PROVIDER" in
  cloudflare)
    SECRET_NAME="cloudflare-credentials"
    if ! kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
      if [[ -n "${CF_API_TOKEN:-}" ]]; then
        kubectl create secret generic "$SECRET_NAME" \
          --namespace "$NAMESPACE" \
          --from-literal=api-token="$CF_API_TOKEN" \
          --dry-run=client -o yaml | kubectl apply -f -
        info "Cloudflare credentials secret created."
      else
        warn "CF_API_TOKEN not set. Create the secret manually:"
        echo "  kubectl create secret generic $SECRET_NAME \\"
        echo "    --namespace $NAMESPACE \\"
        echo "    --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN"
        echo ""
        warn "Continuing installation — external-dns will crash-loop until the secret exists."
      fi
    else
      info "Secret $SECRET_NAME already exists."
    fi
    ;;

  hetzner)
    SECRET_NAME="hetzner-dns-credentials"
    if ! kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
      if [[ -n "${HETZNER_DNS_TOKEN:-}" ]]; then
        kubectl create secret generic "$SECRET_NAME" \
          --namespace "$NAMESPACE" \
          --from-literal=api-token="$HETZNER_DNS_TOKEN" \
          --dry-run=client -o yaml | kubectl apply -f -
        info "Hetzner DNS credentials secret created."
      else
        warn "HETZNER_DNS_TOKEN not set. Create the secret manually:"
        echo "  kubectl create secret generic $SECRET_NAME \\"
        echo "    --namespace $NAMESPACE \\"
        echo "    --from-literal=api-token=YOUR_HETZNER_DNS_TOKEN"
      fi
    fi

    info "Patching values for Hetzner DNS provider..."
    EXTRA_ARGS="--set provider.name=hetzner"
    EXTRA_ARGS="$EXTRA_ARGS --set env[0].name=HETZNER_TOKEN"
    EXTRA_ARGS="$EXTRA_ARGS --set env[0].valueFrom.secretKeyRef.name=$SECRET_NAME"
    EXTRA_ARGS="$EXTRA_ARGS --set env[0].valueFrom.secretKeyRef.key=api-token"
    ;;

  *)
    error "Unsupported DNS_PROVIDER: $DNS_PROVIDER (supported: cloudflare, hetzner)"
    ;;
esac

# shellcheck disable=SC2086
helm upgrade --install external-dns external-dns/external-dns \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/external-dns/values.yaml \
  ${EXTRA_ARGS:-} \
  --wait --timeout 5m

echo ""
echo "============================================="
info "external-dns deployed (provider: $DNS_PROVIDER)"
echo "============================================="
echo ""
echo "DNS records will be auto-created for Ingress resources"
echo "with hosts matching the configured domainFilters."
echo ""
echo "Verify:"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=external-dns -f"
