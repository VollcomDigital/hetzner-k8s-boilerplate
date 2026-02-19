#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="system-upgrade"
SUC_VERSION="${SUC_VERSION:-v0.14.2}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing System Upgrade Controller ${SUC_VERSION}..."
kubectl apply -f "https://github.com/rancher/system-upgrade-controller/releases/download/${SUC_VERSION}/system-upgrade-controller.yaml"

echo "Waiting for controller to be ready..."
kubectl wait --for=condition=Available deployment/system-upgrade-controller \
  -n "$NAMESPACE" --timeout=120s

echo "============================================="
echo " k3s System Upgrade Controller deployed"
echo "============================================="
echo ""
echo "To trigger an upgrade, apply a Plan:"
echo "  kubectl apply -f kubernetes/system/upgrade-controller/upgrade-plan.yaml"
echo ""
echo "Monitor upgrades:"
echo "  kubectl get plans -n system-upgrade"
echo "  kubectl get jobs -n system-upgrade"
