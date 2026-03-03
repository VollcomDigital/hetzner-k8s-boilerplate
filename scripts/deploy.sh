#!/usr/bin/env bash
# ============================================================================
# Full cluster deployment: Infrastructure -> k3s -> System components
#
# Usage:
#   ./scripts/deploy.sh                     # Core components only
#   ./scripts/deploy.sh --all               # Core + all optional components
#   ./scripts/deploy.sh --logging --argocd  # Core + selected optional
#
# Optional flags:
#   --logging           Deploy Loki + Promtail
#   --tracing           Deploy Grafana Tempo (distributed tracing)
#   --collector         Deploy Grafana Alloy (universal OTel collector)
#   --otel-operator     Deploy OpenTelemetry Operator (auto-instrumentation)
#   --observability     Deploy full LGTM stack (logging + tracing + collector + otel-operator)
#   --argocd            Deploy ArgoCD
#   --security          Apply network policies, RBAC, quotas, priority classes
#   --external-dns      Deploy external-dns (requires DNS_PROVIDER, CF_API_TOKEN)
#   --autoscaler        Deploy Hetzner Cluster Autoscaler
#   --velero            Deploy Velero backup system
#   --external-secrets  Deploy External Secrets Operator
#   --all               Deploy everything above
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

# Parse flags
OPT_LOGGING=false
OPT_TRACING=false
OPT_COLLECTOR=false
OPT_OTEL_OPERATOR=false
OPT_ARGOCD=false
OPT_SECURITY=false
OPT_EXTERNAL_DNS=false
OPT_AUTOSCALER=false
OPT_VELERO=false
OPT_EXTERNAL_SECRETS=false

for arg in "$@"; do
  case "$arg" in
    --all)
      OPT_LOGGING=true
      OPT_TRACING=true
      OPT_COLLECTOR=true
      OPT_OTEL_OPERATOR=true
      OPT_ARGOCD=true
      OPT_SECURITY=true
      OPT_EXTERNAL_DNS=true
      OPT_AUTOSCALER=true
      OPT_VELERO=true
      OPT_EXTERNAL_SECRETS=true
      ;;
    --observability)
      OPT_LOGGING=true
      OPT_TRACING=true
      OPT_COLLECTOR=true
      OPT_OTEL_OPERATOR=true
      ;;
    --logging)          OPT_LOGGING=true ;;
    --tracing)          OPT_TRACING=true ;;
    --collector)        OPT_COLLECTOR=true ;;
    --otel-operator)    OPT_OTEL_OPERATOR=true ;;
    --argocd)           OPT_ARGOCD=true ;;
    --security)         OPT_SECURITY=true ;;
    --external-dns)     OPT_EXTERNAL_DNS=true ;;
    --autoscaler)       OPT_AUTOSCALER=true ;;
    --velero)           OPT_VELERO=true ;;
    --external-secrets) OPT_EXTERNAL_SECRETS=true ;;
    *) warn "Unknown flag: $arg" ;;
  esac
done

# Load environment if available
[[ -f "$PROJECT_DIR/.env" ]] && source "$PROJECT_DIR/.env"

export KUBECONFIG="${KUBECONFIG:-$PROJECT_DIR/kubeconfig.yaml}"

TOTAL_STEPS=8
OPTIONAL_STEPS=0
$OPT_LOGGING          && ((++OPTIONAL_STEPS)) || true
$OPT_TRACING          && ((++OPTIONAL_STEPS)) || true
$OPT_COLLECTOR        && ((++OPTIONAL_STEPS)) || true
$OPT_OTEL_OPERATOR    && ((++OPTIONAL_STEPS)) || true
$OPT_ARGOCD           && ((++OPTIONAL_STEPS)) || true
$OPT_SECURITY         && ((++OPTIONAL_STEPS)) || true
$OPT_EXTERNAL_DNS     && ((++OPTIONAL_STEPS)) || true
$OPT_AUTOSCALER       && ((++OPTIONAL_STEPS)) || true
$OPT_VELERO           && ((++OPTIONAL_STEPS)) || true
$OPT_EXTERNAL_SECRETS && ((++OPTIONAL_STEPS)) || true
TOTAL_STEPS=$((TOTAL_STEPS + OPTIONAL_STEPS))
CURRENT_STEP=0

next_step() {
  ((++CURRENT_STEP))
  step "$CURRENT_STEP/$TOTAL_STEPS — $1"
}

# =========================================================================
next_step "Terraform: Provision Infrastructure"
# =========================================================================
cd "$PROJECT_DIR/terraform"

terraform init -upgrade
terraform apply -auto-approve

cd "$PROJECT_DIR"

RETRIES=30
until [[ -f "$KUBECONFIG" ]] || [[ $RETRIES -eq 0 ]]; do
  warn "Waiting for kubeconfig... ($RETRIES attempts remaining)"
  sleep 10
  ((--RETRIES)) || true
done

[[ -f "$KUBECONFIG" ]] || error "Kubeconfig not found at $KUBECONFIG"
info "Kubeconfig ready at $KUBECONFIG"

# =========================================================================
next_step "Wait for Nodes"
# =========================================================================
info "Waiting for all nodes to be Ready..."
RETRIES=60
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  [[ $RETRIES -eq 0 ]] && error "Nodes did not become Ready in time"
  sleep 10
  ((--RETRIES)) || true
done

kubectl get nodes -o wide
echo ""

# =========================================================================
next_step "Deploy Hetzner Cloud Controller Manager"
# =========================================================================
kubectl apply -k kubernetes/core/hcloud-ccm/
info "Hetzner CCM deployed. Waiting for pods..."
kubectl rollout status deployment/hcloud-cloud-controller-manager \
  -n kube-system --timeout=120s 2>/dev/null || sleep 15

# =========================================================================
next_step "Deploy Hetzner CSI Driver"
# =========================================================================
kubectl apply -k kubernetes/core/hcloud-csi/
kubectl apply -f kubernetes/core/hcloud-csi/storage-classes.yaml
info "Hetzner CSI driver + storage classes deployed."

# =========================================================================
next_step "Verify Metrics Server"
# =========================================================================
info "Waiting for metrics-server to become available..."
RETRIES=12
until kubectl top nodes &>/dev/null; do
  [[ $RETRIES -eq 0 ]] && { warn "metrics-server not responding — HPA will not function."; break; }
  sleep 10
  ((--RETRIES)) || true
done
if kubectl top nodes &>/dev/null; then
  info "metrics-server is operational."
  kubectl top nodes
fi
echo ""

# =========================================================================
next_step "Deploy NGINX Ingress Controller"
# =========================================================================
bash kubernetes/ingress/nginx/install.sh

# =========================================================================
next_step "Deploy cert-manager"
# =========================================================================
if [[ -n "${ACME_EMAIL:-}" ]]; then
  bash kubernetes/ingress/cert-manager/install.sh
else
  warn "ACME_EMAIL not set — skipping cert-manager. Set it in .env and re-run."
fi

# =========================================================================
next_step "Deploy Monitoring Stack"
# =========================================================================
bash kubernetes/monitoring/install.sh

# =========================================================================
# Optional components
# =========================================================================

if $OPT_LOGGING; then
  next_step "Deploy Logging Stack (Loki + Promtail)"
  bash kubernetes/logging/install.sh
fi

if $OPT_TRACING; then
  next_step "Deploy Tracing Stack (Grafana Tempo)"
  bash kubernetes/tracing/install.sh
fi

if $OPT_COLLECTOR; then
  next_step "Deploy Universal Collector (Grafana Alloy)"
  bash kubernetes/collector/install.sh
fi

if $OPT_OTEL_OPERATOR; then
  next_step "Deploy OpenTelemetry Operator"
  bash kubernetes/otel-operator/install.sh
fi

# Apply observability dashboards if any tracing/collector components were deployed
if $OPT_TRACING || $OPT_COLLECTOR; then
  info "Applying observability Grafana dashboards..."
  kubectl apply -f kubernetes/monitoring/dashboards/red-metrics-configmap.yaml 2>/dev/null || true
  kubectl apply -f kubernetes/monitoring/dashboards/llm-observability-configmap.yaml 2>/dev/null || true
  kubectl apply -f kubernetes/monitoring/dashboards/service-graph-configmap.yaml 2>/dev/null || true
  kubectl apply -f kubernetes/monitoring/dashboards/alloy-collector-configmap.yaml 2>/dev/null || true
  kubectl apply -f kubernetes/tracing/grafana-datasource.yaml 2>/dev/null || true
fi

if $OPT_SECURITY; then
  next_step "Apply Security Policies"
  kubectl apply -f kubernetes/security/priority-classes.yaml
  kubectl apply -f kubernetes/security/pod-security.yaml
  kubectl apply -f kubernetes/security/resource-quotas.yaml 2>/dev/null || \
    warn "Resource quotas skipped (namespaces may not exist yet)"
  kubectl apply -f kubernetes/security/network-policies/
  kubectl apply -f kubernetes/security/rbac/
  info "Network policies, RBAC, quotas, and priority classes applied."
fi

if $OPT_EXTERNAL_SECRETS; then
  next_step "Deploy External Secrets Operator"
  bash kubernetes/security/external-secrets/install.sh
fi

if $OPT_VELERO; then
  next_step "Deploy Velero Backup System"
  bash kubernetes/backup/velero/install.sh
fi

if $OPT_ARGOCD; then
  next_step "Deploy ArgoCD"
  bash kubernetes/gitops/argocd/install.sh
fi

if $OPT_EXTERNAL_DNS; then
  next_step "Deploy external-dns"
  bash kubernetes/system/external-dns/install.sh
fi

if $OPT_AUTOSCALER; then
  next_step "Deploy Hetzner Cluster Autoscaler"
  bash kubernetes/system/autoscaler/install.sh
fi

# =========================================================================
step "Deployment Complete"
# =========================================================================
echo ""
info "Cluster is ready!"
echo ""
echo "  export KUBECONFIG=$KUBECONFIG"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""

OPTIONAL_MSG=""
$OPT_LOGGING          || OPTIONAL_MSG="$OPTIONAL_MSG  make logging            — Loki + Promtail\n"
$OPT_TRACING          || OPTIONAL_MSG="$OPTIONAL_MSG  make tracing            — Grafana Tempo (distributed tracing)\n"
$OPT_COLLECTOR        || OPTIONAL_MSG="$OPTIONAL_MSG  make collector           — Grafana Alloy (universal OTel collector)\n"
$OPT_OTEL_OPERATOR    || OPTIONAL_MSG="$OPTIONAL_MSG  make otel-operator       — OpenTelemetry auto-instrumentation\n"
$OPT_ARGOCD           || OPTIONAL_MSG="$OPTIONAL_MSG  make argocd             — ArgoCD GitOps\n"
$OPT_SECURITY         || OPTIONAL_MSG="$OPTIONAL_MSG  make security           — Network policies + RBAC\n"
$OPT_EXTERNAL_DNS     || OPTIONAL_MSG="$OPTIONAL_MSG  make external-dns       — Automatic DNS records\n"
$OPT_AUTOSCALER       || OPTIONAL_MSG="$OPTIONAL_MSG  make autoscaler         — Node autoscaling\n"
$OPT_VELERO           || OPTIONAL_MSG="$OPTIONAL_MSG  make velero             — Cluster backups\n"
$OPT_EXTERNAL_SECRETS || OPTIONAL_MSG="$OPTIONAL_MSG  make external-secrets   — Secret management\n"

if [[ -n "$OPTIONAL_MSG" ]]; then
  echo "Optional components not deployed:"
  echo -e "$OPTIONAL_MSG"
  echo "Or deploy everything: ./scripts/deploy.sh --all"
fi
