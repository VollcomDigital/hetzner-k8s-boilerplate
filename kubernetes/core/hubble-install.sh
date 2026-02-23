#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

NAMESPACE="kube-system"
HUBBLE_USER="${HUBBLE_USER:-admin}"
HUBBLE_PASSWORD="${HUBBLE_PASSWORD:-}"

if [[ -z "$HUBBLE_PASSWORD" ]]; then
  error "HUBBLE_PASSWORD is required. Export it before running this installer."
fi

info "Generating basic-auth secret for Hubble UI..."

if ! command -v htpasswd &>/dev/null; then
  warn "htpasswd not found. Installing apache2-utils..."
  sudo apt-get update -qq && sudo apt-get install -y -qq apache2-utils
fi

AUTH_FILE=$(mktemp)
htpasswd -bc "$AUTH_FILE" "$HUBBLE_USER" "$HUBBLE_PASSWORD"

kubectl create secret generic hubble-basic-auth \
  --from-file=auth="$AUTH_FILE" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f "$AUTH_FILE"

kubectl apply -f kubernetes/core/hubble-ingress.yaml

echo ""
echo "============================================="
info "Hubble UI Ingress deployed"
echo "============================================="
echo ""
echo "  User:     $HUBBLE_USER"
echo ""
echo "  Update the host in kubernetes/core/hubble-ingress.yaml"
echo "  then access: https://hubble.your-domain.com"
echo ""
echo "  Port-forward (no Ingress needed):"
echo "    kubectl port-forward -n kube-system svc/hubble-ui 8080:80"
echo "    Open http://localhost:8080"
