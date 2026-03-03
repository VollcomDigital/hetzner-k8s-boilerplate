#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="collector"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/collector/namespace.yaml

echo "Deploying Grafana Alloy (DaemonSet)..."
helm upgrade --install alloy grafana/alloy \
  --namespace "$NAMESPACE" \
  --values kubernetes/collector/values.yaml \
  --wait --timeout 5m

echo "============================================="
echo " Grafana Alloy deployed (universal collector)"
echo "============================================="
echo ""
echo "Alloy accepts telemetry via:"
echo "  OTLP gRPC: alloy.collector.svc.cluster.local:4317"
echo "  OTLP HTTP: alloy.collector.svc.cluster.local:4318"
echo ""
echo "Alloy routes signals to:"
echo "  Traces  -> Tempo   (tracing namespace)"
echo "  Metrics -> Prometheus (monitoring namespace)"
echo "  Logs    -> Loki    (logging namespace)"
echo ""
echo "NOTE: If migrating from Promtail, you can safely uninstall Promtail:"
echo "  helm uninstall promtail -n logging"
