#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

NAMESPACE="registry"
HARBOR_PASSWORD="${HARBOR_ADMIN_PASSWORD:-}"

if [[ -z "$HARBOR_PASSWORD" ]]; then
  error "HARBOR_ADMIN_PASSWORD is required. Export it before running this installer."
fi

helm repo add harbor https://helm.goharbor.io
helm repo update

kubectl apply -f kubernetes/system/registry/namespace.yaml

helm upgrade --install harbor harbor/harbor \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/registry/values.yaml \
  --set harborAdminPassword="$HARBOR_PASSWORD" \
  --wait --timeout 10m

echo ""
echo "============================================="
info "Harbor Container Registry deployed"
echo "============================================="
echo ""
echo "  URL:      https://registry.example.com"
echo "  User:     admin"
echo ""
echo "Login:"
echo "  docker login registry.example.com -u admin"
echo ""
echo "Configure k3s to use Harbor (on each node):"
echo "  cat > /etc/rancher/k3s/registries.yaml <<EOF"
echo "  mirrors:"
echo "    registry.example.com:"
echo "      endpoint:"
echo "        - https://registry.example.com"
echo "  EOF"
echo "  systemctl restart k3s"
