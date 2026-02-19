#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
  --namespace "$NAMESPACE" \
  --values kubernetes/gitops/argocd/values.yaml \
  --wait --timeout 5m

INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "not-yet-available")

echo "============================================="
echo " ArgoCD deployed successfully"
echo " Initial admin password: $INITIAL_PASSWORD"
echo "============================================="
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8443:443"
echo "  Open https://localhost:8443 (admin / <password above>)"
echo ""
echo "CLI login:"
echo "  argocd login localhost:8443 --username admin --password '$INITIAL_PASSWORD'"
