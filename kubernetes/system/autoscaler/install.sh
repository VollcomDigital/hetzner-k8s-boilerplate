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

NAMESPACE="kube-system"

# Retrieve cluster metadata from Terraform if available
TF_DIR="$PROJECT_DIR/terraform"
if [[ -d "$TF_DIR/.terraform" ]]; then
  info "Reading cluster metadata from Terraform outputs..."
  CLUSTER_NAME=$(cd "$TF_DIR" && terraform output -raw cluster_name 2>/dev/null || echo "k8s")
  API_LB_IP=$(cd "$TF_DIR" && terraform output -raw api_lb_ipv4 2>/dev/null || echo "")
  K3S_TOKEN_VAL=$(cd "$TF_DIR" && terraform output -raw k3s_token 2>/dev/null || echo "")
  K3S_VERSION_VAL=$(cd "$TF_DIR" && terraform output -raw k3s_version 2>/dev/null || echo "v1.30.2+k3s1")
else
  warn "Terraform state not found. Using environment variables or defaults."
  CLUSTER_NAME="${CLUSTER_NAME:-k8s}"
  API_LB_IP="${API_SERVER_LB:-}"
  K3S_TOKEN_VAL="${K3S_TOKEN:-}"
  K3S_VERSION_VAL="${K3S_VERSION:-v1.30.2+k3s1}"
fi

if [[ -z "$API_LB_IP" || -z "$K3S_TOKEN_VAL" ]]; then
  warn "API_SERVER_LB or K3S_TOKEN not available."
  warn "Set them as env vars or ensure Terraform state is initialized."
  warn "Autoscaler will deploy but new nodes won't be able to join without valid cloud-init."
fi

# Build cloud-init for autoscaled workers
CLOUD_INIT_B64=""
if [[ -n "$API_LB_IP" && -n "$K3S_TOKEN_VAL" ]]; then
  info "Generating base64-encoded cloud-init for worker nodes..."
  CLOUD_INIT_B64=$(sed \
    -e "s|K3S_VERSION|${K3S_VERSION_VAL}|g" \
    -e "s|K3S_TOKEN|${K3S_TOKEN_VAL}|g" \
    -e "s|API_SERVER_LB|${API_LB_IP}|g" \
    "$SCRIPT_DIR/cloud-init-worker.yaml" | base64 -w0)
fi

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace "$NAMESPACE" \
  --values kubernetes/system/autoscaler/values.yaml \
  --set autoDiscovery.clusterName="$CLUSTER_NAME" \
  --set "extraEnv.HCLOUD_CLOUD_INIT=$CLOUD_INIT_B64" \
  --set "extraEnv.HCLOUD_NETWORK=${CLUSTER_NAME}-network" \
  --set "extraEnv.HCLOUD_FIREWALL=${CLUSTER_NAME}-worker" \
  --set "extraEnv.HCLOUD_SSH_KEY=${CLUSTER_NAME}-key" \
  --wait --timeout 5m

echo ""
echo "============================================="
info "Hetzner Cluster Autoscaler deployed"
echo "============================================="
echo ""
echo "Worker nodes will scale between min/max based on pod demand."
echo "Autoscaled nodes join via cloud-init with k3s agent."
echo ""
echo "Monitor:"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=cluster-autoscaler -f"
echo "  kubectl get configmap -n $NAMESPACE cluster-autoscaler-status -o yaml"
