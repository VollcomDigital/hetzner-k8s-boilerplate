#!/usr/bin/env bash
# ============================================================================
# Tear down all cluster resources
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo ""
echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING: This will destroy ALL resources!   ║${NC}"
echo -e "${RED}║  Servers, networks, LBs, volumes — GONE.    ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""

read -rp "Type 'destroy' to confirm: " CONFIRM
[[ "$CONFIRM" == "destroy" ]] || error "Aborted."

echo ""
warn "Destroying infrastructure in 5 seconds... (Ctrl+C to abort)"
sleep 5

cd "$PROJECT_DIR/terraform"

terraform destroy -auto-approve

# Clean up local artifacts
rm -f "$PROJECT_DIR/kubeconfig.yaml"

echo ""
echo "All resources destroyed. Kubeconfig removed."
