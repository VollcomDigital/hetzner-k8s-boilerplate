#!/usr/bin/env bash
# ============================================================================
# Full cluster deployment: Infrastructure → k3s → System components
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${CYAN}=== $* ===${NC}\n"; }

# Load environment if available
[[ -f "$PROJECT_DIR/.env" ]] && source "$PROJECT_DIR/.env"

export KUBECONFIG="${KUBECONFIG:-$PROJECT_DIR/kubeconfig.yaml}"

# -------------------------------------------------------------------------
step "1/7 — Terraform: Provision Infrastructure"
# -------------------------------------------------------------------------
cd "$PROJECT_DIR/terraform"

terraform init -upgrade
terraform apply -auto-approve

cd "$PROJECT_DIR"

# Wait for kubeconfig
RETRIES=30
until [[ -f "$KUBECONFIG" ]] || [[ $RETRIES -eq 0 ]]; do
  warn "Waiting for kubeconfig... ($RETRIES attempts remaining)"
  sleep 10
  ((RETRIES--))
done

[[ -f "$KUBECONFIG" ]] || error "Kubeconfig not found at $KUBECONFIG"
info "Kubeconfig ready at $KUBECONFIG"

# -------------------------------------------------------------------------
step "2/7 — Wait for Nodes"
# -------------------------------------------------------------------------
info "Waiting for all nodes to be Ready..."
RETRIES=60
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  [[ $RETRIES -eq 0 ]] && error "Nodes did not become Ready in time"
  sleep 10
  ((RETRIES--))
done

kubectl get nodes -o wide
echo ""

# -------------------------------------------------------------------------
step "3/7 — Deploy Hetzner Cloud Controller Manager"
# -------------------------------------------------------------------------
kubectl apply -k kubernetes/core/hcloud-ccm/
info "Hetzner CCM deployed. Waiting for pods..."
sleep 15

# -------------------------------------------------------------------------
step "4/7 — Deploy Hetzner CSI Driver"
# -------------------------------------------------------------------------
kubectl apply -k kubernetes/core/hcloud-csi/
kubectl apply -f kubernetes/core/hcloud-csi/storage-classes.yaml
info "Hetzner CSI driver + storage classes deployed."

# -------------------------------------------------------------------------
step "5/7 — Deploy NGINX Ingress Controller"
# -------------------------------------------------------------------------
bash kubernetes/ingress/nginx/install.sh

# -------------------------------------------------------------------------
step "6/7 — Deploy cert-manager"
# -------------------------------------------------------------------------
if [[ -n "${ACME_EMAIL:-}" ]]; then
  bash kubernetes/ingress/cert-manager/install.sh
else
  warn "ACME_EMAIL not set — skipping cert-manager. Set it in .env and re-run."
fi

# -------------------------------------------------------------------------
step "7/7 — Deploy Monitoring Stack"
# -------------------------------------------------------------------------
bash kubernetes/monitoring/install.sh

# -------------------------------------------------------------------------
step "Deployment Complete"
# -------------------------------------------------------------------------
echo ""
info "Cluster is ready!"
echo ""
echo "  export KUBECONFIG=$KUBECONFIG"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
echo "Optional next steps:"
echo "  make argocd     — Install ArgoCD for GitOps"
echo "  make security   — Apply network policies and RBAC"
