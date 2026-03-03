#!/usr/bin/env bash
set -euo pipefail

# Alloy runs in the logging namespace alongside Loki (keeps RBAC and network
# policies scoped to one observability-adjacent namespace).
NAMESPACE="logging"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "Deploying Grafana Alloy (OTel-native universal collector)..."
helm upgrade --install alloy grafana/alloy \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values kubernetes/alloy/values-alloy.yaml \
  --set-file alloy.configMap.content=kubernetes/alloy/config.alloy \
  --wait --timeout 5m

echo "============================================="
echo " Grafana Alloy deployed as DaemonSet"
echo " Namespace: $NAMESPACE"
echo "============================================="
echo ""
echo "OTLP ingestion (from instrumented apps):"
echo "  gRPC: alloy.logging.svc.cluster.local:4317"
echo "  HTTP: alloy.logging.svc.cluster.local:4318"
echo ""
echo "Configure your app's OTel SDK:"
echo "  OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.logging.svc.cluster.local:4317"
echo "  OTEL_SERVICE_NAME=your-service-name"
echo ""
echo "For LLM observability (OpenLLMetry):"
echo "  TRACELOOP_BASE_URL=http://alloy.logging.svc.cluster.local:4318"
