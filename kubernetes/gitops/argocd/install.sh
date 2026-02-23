#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl apply -f kubernetes/gitops/argocd/namespace.yaml

helm upgrade --install argocd argo/argo-cd \
  --namespace "$NAMESPACE" \
  --values kubernetes/gitops/argocd/values.yaml \
  --wait --timeout 5m

echo "============================================="
echo " ArgoCD deployed successfully"
echo "============================================="
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8443:443"
echo "  Open https://localhost:8443"
echo ""
echo "Retrieve initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d && echo"
