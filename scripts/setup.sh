#!/usr/bin/env bash
# ============================================================================
# Pre-flight checks and local tooling setup
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_command() {
  if command -v "$1" &>/dev/null; then
    info "$1 found: $(command -v "$1")"
  else
    warn "$1 not found — installing..."
    return 1
  fi
}

info "========================================="
info " Hetzner K8s Boilerplate — Setup"
info "========================================="
echo ""

# -- Check required tools --
MISSING=()

check_command terraform || MISSING+=("terraform")
check_command kubectl   || MISSING+=("kubectl")
check_command helm      || MISSING+=("helm")
check_command hcloud    || MISSING+=("hcloud")
check_command jq        || MISSING+=("jq")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Missing tools: ${MISSING[*]}"
  echo ""
  echo "Install instructions:"
  echo "  terraform: https://developer.hashicorp.com/terraform/install"
  echo "  kubectl:   https://kubernetes.io/docs/tasks/tools/"
  echo "  helm:      https://helm.sh/docs/intro/install/"
  echo "  hcloud:    https://github.com/hetznercloud/cli"
  echo "  jq:        https://jqlang.github.io/jq/download/"
  echo ""
  error "Please install the missing tools and re-run this script."
fi

# -- Check SSH key --
SSH_KEY="${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}"
if [[ -f "$SSH_KEY" ]]; then
  info "SSH public key found: $SSH_KEY"
else
  warn "SSH key not found at $SSH_KEY"
  echo "  Generate one: ssh-keygen -t ed25519 -C 'k8s-cluster'"
fi

# -- Check Hetzner token --
if [[ -n "${HCLOUD_TOKEN:-}" ]]; then
  info "HCLOUD_TOKEN is set"
  hcloud context create k8s-setup 2>/dev/null || true
else
  warn "HCLOUD_TOKEN not set. Export it or add to .env file."
fi

# -- Check terraform.tfvars --
if [[ -f terraform/terraform.tfvars ]]; then
  info "terraform.tfvars found"
else
  warn "terraform/terraform.tfvars not found"
  echo "  Copy the example: cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
fi

echo ""
info "Setup check complete. Run 'make plan' to preview infrastructure."
