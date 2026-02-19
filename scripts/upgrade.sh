#!/usr/bin/env bash
# ============================================================================
# Rolling k3s upgrade — drain, upgrade, uncordon per node
# Usage: ./scripts/upgrade.sh <target-version> [--control-plane-only|--workers-only]
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

[[ -f "$PROJECT_DIR/.env" ]] && source "$PROJECT_DIR/.env"
export KUBECONFIG="${KUBECONFIG:-$PROJECT_DIR/kubeconfig.yaml}"

TARGET_VERSION="${1:?Usage: $0 <k3s-version> [--control-plane-only|--workers-only]}"
MODE="${2:-all}"

SSH_KEY="${SSH_PRIVATE_KEY_PATH:-$HOME/.ssh/id_ed25519}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

upgrade_node() {
  local NODE_NAME="$1"
  local NODE_IP="$2"
  local NODE_ROLE="$3"

  step "Upgrading ${NODE_ROLE}: ${NODE_NAME} (${NODE_IP})"

  info "Draining node ${NODE_NAME}..."
  kubectl drain "$NODE_NAME" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --force \
    --timeout=300s || warn "Drain completed with warnings"

  info "Installing k3s ${TARGET_VERSION} on ${NODE_IP}..."
  # shellcheck disable=SC2029
  ssh $SSH_OPTS -i "$SSH_KEY" "root@${NODE_IP}" \
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${TARGET_VERSION}' sh -"

  info "Waiting for node ${NODE_NAME} to rejoin..."
  local RETRIES=30
  until kubectl get node "$NODE_NAME" 2>/dev/null | grep -q "Ready"; do
    [[ $RETRIES -eq 0 ]] && error "Node ${NODE_NAME} did not become Ready"
    sleep 10
    ((RETRIES--))
  done

  info "Uncordoning node ${NODE_NAME}..."
  kubectl uncordon "$NODE_NAME"

  local ACTUAL_VERSION
  ACTUAL_VERSION=$(kubectl get node "$NODE_NAME" -o jsonpath='{.status.nodeInfo.kubeletVersion}')
  info "Node ${NODE_NAME} running: ${ACTUAL_VERSION}"
  echo ""
}

# Validate target version format
if [[ ! "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]; then
  error "Invalid version format. Expected: v1.30.2+k3s1"
fi

step "k3s Rolling Upgrade → ${TARGET_VERSION}"

info "Current node versions:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,STATUS:.status.conditions[-1].type
echo ""

read -rp "Proceed with upgrade to ${TARGET_VERSION}? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[yY]$ ]] || error "Aborted."

# Get node lists from Terraform outputs
cd "$PROJECT_DIR/terraform"
CP_IPS=($(terraform output -json control_plane_ips | jq -r '.[]'))
WORKER_IPS=($(terraform output -json worker_ips | jq -r '.[]'))
cd "$PROJECT_DIR"

# Upgrade control-plane nodes first (one at a time)
if [[ "$MODE" != "--workers-only" ]]; then
  step "Phase 1: Control Plane Nodes"
  for i in "${!CP_IPS[@]}"; do
    NODE_NAME=$(kubectl get nodes -l "node-role.kubernetes.io/control-plane" \
      -o jsonpath="{.items[${i}].metadata.name}" 2>/dev/null || echo "unknown-cp-${i}")
    upgrade_node "$NODE_NAME" "${CP_IPS[$i]}" "control-plane"

    if [[ $i -lt $((${#CP_IPS[@]} - 1)) ]]; then
      info "Waiting 30s before next control-plane node..."
      sleep 30
    fi
  done
fi

# Upgrade worker nodes (one at a time)
if [[ "$MODE" != "--control-plane-only" ]]; then
  step "Phase 2: Worker Nodes"
  for i in "${!WORKER_IPS[@]}"; do
    NODE_NAME=$(kubectl get nodes -l "!node-role.kubernetes.io/control-plane" \
      -o jsonpath="{.items[${i}].metadata.name}" 2>/dev/null || echo "unknown-worker-${i}")
    upgrade_node "$NODE_NAME" "${WORKER_IPS[$i]}" "worker"

    if [[ $i -lt $((${#WORKER_IPS[@]} - 1)) ]]; then
      info "Waiting 15s before next worker node..."
      sleep 15
    fi
  done
fi

step "Upgrade Complete"
info "All nodes upgraded to ${TARGET_VERSION}:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,STATUS:.status.conditions[-1].type
