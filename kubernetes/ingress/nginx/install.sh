#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-nginx"

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl apply -f kubernetes/ingress/nginx/namespace.yaml

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace "$NAMESPACE" \
  --values kubernetes/ingress/nginx/values.yaml \
  --wait --timeout 5m

echo "NGINX Ingress Controller deployed successfully."
