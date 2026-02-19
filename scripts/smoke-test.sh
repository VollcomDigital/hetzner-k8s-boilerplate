#!/usr/bin/env bash
# ============================================================================
# End-to-end smoke test
#
# Deploys a test workload, verifies it's reachable, checks core systems,
# then cleans up. Exit code 0 = all checks passed.
#
# Usage:
#   ./scripts/smoke-test.sh              # Full suite
#   ./scripts/smoke-test.sh --skip-app   # Skip app deploy (infra checks only)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; ((++PASS)); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; ((++FAIL)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; ((++WARN)); }
section() { echo -e "\n${CYAN}--- $* ---${NC}"; }

SKIP_APP=false
[[ "${1:-}" == "--skip-app" ]] && SKIP_APP=true

[[ -f "$PROJECT_DIR/.env" ]] && source "$PROJECT_DIR/.env"
export KUBECONFIG="${KUBECONFIG:-$PROJECT_DIR/kubeconfig.yaml}"

SMOKE_NS="smoke-test"

cleanup() {
  if [[ "$SKIP_APP" == false ]]; then
    echo ""
    echo "Cleaning up smoke-test namespace..."
    kubectl delete namespace "$SMOKE_NS" --ignore-not-found --wait=false 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo ""
echo "============================================="
echo " Hetzner K8s Boilerplate — Smoke Test"
echo "============================================="

# =========================================================================
section "1. Cluster Connectivity"
# =========================================================================

if kubectl cluster-info &>/dev/null; then
  pass "kubectl can reach the API server"
else
  fail "kubectl cannot reach the API server"
  echo "  Ensure KUBECONFIG=$KUBECONFIG is valid"
  exit 1
fi

API_VERSION=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
pass "API server version: $API_VERSION"

# =========================================================================
section "2. Node Health"
# =========================================================================

TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)

if [[ "$READY_NODES" -gt 0 ]]; then
  pass "Nodes Ready: $READY_NODES / $TOTAL_NODES"
else
  fail "No nodes in Ready state"
fi

NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" || true)
if [[ -n "$NOT_READY" ]]; then
  fail "Nodes not Ready:\n$NOT_READY"
fi

# =========================================================================
section "3. Core System Pods"
# =========================================================================

check_deployment() {
  local NS="$1" NAME="$2" LABEL="$3"
  if kubectl get deployment "$NAME" -n "$NS" &>/dev/null; then
    READY=$(kubectl get deployment "$NAME" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment "$NAME" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "?")
    if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
      pass "$LABEL ($READY/$DESIRED replicas)"
    else
      fail "$LABEL ($READY/$DESIRED replicas)"
    fi
  else
    warn "$LABEL not found (may not be deployed)"
  fi
}

check_daemonset() {
  local NS="$1" NAME="$2" LABEL="$3"
  if kubectl get daemonset "$NAME" -n "$NS" &>/dev/null; then
    READY=$(kubectl get daemonset "$NAME" -n "$NS" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get daemonset "$NAME" -n "$NS" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "?")
    if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
      pass "$LABEL ($READY/$DESIRED nodes)"
    else
      fail "$LABEL ($READY/$DESIRED nodes)"
    fi
  else
    warn "$LABEL not found"
  fi
}

check_daemonset  "kube-system" "cilium"                          "Cilium CNI"
check_deployment "kube-system" "cilium-operator"                 "Cilium Operator"
check_deployment "kube-system" "coredns"                         "CoreDNS"
check_deployment "kube-system" "hcloud-cloud-controller-manager" "Hetzner CCM"

# CSI runs as multiple components
if kubectl get pods -n kube-system -l app=hcloud-csi --no-headers 2>/dev/null | grep -q "Running"; then
  pass "Hetzner CSI Driver"
else
  warn "Hetzner CSI Driver pods not found or not Running"
fi

# =========================================================================
section "4. Metrics Server"
# =========================================================================

if kubectl top nodes &>/dev/null; then
  pass "metrics-server is functional (kubectl top nodes works)"
else
  warn "metrics-server not responding (HPA may not work)"
fi

# =========================================================================
section "5. Storage Classes"
# =========================================================================

DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$DEFAULT_SC" ]]; then
  pass "Default StorageClass: $DEFAULT_SC"
else
  warn "No default StorageClass found"
fi

SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
pass "Total StorageClasses: $SC_COUNT"

# =========================================================================
section "6. Ingress Controller"
# =========================================================================

check_deployment "ingress-nginx" "ingress-nginx-controller" "NGINX Ingress Controller"

INGRESS_SVC=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -n "$INGRESS_SVC" ]]; then
  pass "Ingress LB IP: $INGRESS_SVC"
else
  warn "Ingress LoadBalancer IP not assigned yet"
fi

# =========================================================================
section "7. cert-manager"
# =========================================================================

check_deployment "cert-manager" "cert-manager" "cert-manager"
check_deployment "cert-manager" "cert-manager-webhook" "cert-manager webhook"

ISSUERS=$(kubectl get clusterissuers --no-headers 2>/dev/null | wc -l)
if [[ "$ISSUERS" -gt 0 ]]; then
  pass "ClusterIssuers configured: $ISSUERS"
else
  warn "No ClusterIssuers found (cert-manager may not be deployed)"
fi

# =========================================================================
section "8. Monitoring"
# =========================================================================

check_deployment "monitoring" "kube-prometheus-stack-operator"    "Prometheus Operator"
check_deployment "monitoring" "kube-prometheus-stack-grafana"     "Grafana"

PROM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || true)
if [[ "$PROM_PODS" -gt 0 ]]; then
  pass "Prometheus instances running: $PROM_PODS"
else
  warn "Prometheus not found in monitoring namespace"
fi

# =========================================================================
section "9. Optional Components"
# =========================================================================

check_deployment "logging"          "loki"                       "Loki"         2>/dev/null || true
check_daemonset  "logging"          "promtail"                   "Promtail"     2>/dev/null || true
check_deployment "argocd"           "argocd-server"              "ArgoCD"       2>/dev/null || true
check_deployment "external-secrets" "external-secrets"           "External Secrets Operator" 2>/dev/null || true
check_deployment "velero"           "velero"                     "Velero"       2>/dev/null || true
check_deployment "external-dns"     "external-dns"               "external-dns" 2>/dev/null || true

# =========================================================================
if [[ "$SKIP_APP" == false ]]; then
section "10. App Deployment Test"
# =========================================================================

  kubectl create namespace "$SMOKE_NS" --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -n "$SMOKE_NS" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: smoke-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: smoke-test
  template:
    metadata:
      labels:
        app: smoke-test
    spec:
      containers:
        - name: web
          image: gcr.io/google-samples/hello-app:2.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              memory: 32Mi
---
apiVersion: v1
kind: Service
metadata:
  name: smoke-test
spec:
  selector:
    app: smoke-test
  ports:
    - port: 80
      targetPort: 8080
EOF

  echo "  Waiting for pod to be Ready (up to 120s)..."
  if kubectl wait --for=condition=Ready pod -l app=smoke-test -n "$SMOKE_NS" --timeout=120s &>/dev/null; then
    pass "Pod scheduled and Running"
  else
    fail "Pod did not become Ready within 120s"
  fi

  POD_NAME=$(kubectl get pod -n "$SMOKE_NS" -l app=smoke-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$POD_NAME" ]]; then
    NODE=$(kubectl get pod "$POD_NAME" -n "$SMOKE_NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "unknown")
    pass "Pod scheduled on node: $NODE"
  fi

  SVC_IP=$(kubectl get svc smoke-test -n "$SMOKE_NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
  if [[ -n "$SVC_IP" ]]; then
    pass "ClusterIP service created: $SVC_IP"

    RESP=$(kubectl run smoke-curl --image=curlimages/curl --rm -i --restart=Never \
      -n "$SMOKE_NS" --timeout=30s -- \
      curl -sf "http://smoke-test.${SMOKE_NS}.svc.cluster.local" 2>/dev/null || echo "")
    if echo "$RESP" | grep -qi "hello"; then
      pass "In-cluster HTTP request returned valid response"
    else
      fail "In-cluster HTTP request failed or returned unexpected response"
    fi
  else
    fail "Service ClusterIP not assigned"
  fi
fi

# =========================================================================
section "Results"
# =========================================================================

echo ""
echo -e "  ${GREEN}Passed: $PASS${NC}  |  ${RED}Failed: $FAIL${NC}  |  ${YELLOW}Warnings: $WARN${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Some checks failed. Review the output above.${NC}"
  exit 1
else
  echo -e "${GREEN}All checks passed. Cluster is healthy.${NC}"
  exit 0
fi
