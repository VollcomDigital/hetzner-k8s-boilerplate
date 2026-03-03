#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="otel-system"

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

kubectl apply -f kubernetes/otel-operator/namespace.yaml

echo "Deploying OpenTelemetry Operator..."
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace "$NAMESPACE" \
  --values kubernetes/otel-operator/values.yaml \
  --wait --timeout 5m

echo "Deploying Instrumentation CRDs..."
kubectl apply -f kubernetes/otel-operator/instrumentation.yaml

echo "============================================="
echo " OpenTelemetry Operator deployed"
echo "============================================="
echo ""
echo "Auto-instrument workloads by adding annotations to pods:"
echo '  instrumentation.opentelemetry.io/inject-python: "true"'
echo '  instrumentation.opentelemetry.io/inject-nodejs: "true"'
echo '  instrumentation.opentelemetry.io/inject-java: "true"'
echo '  instrumentation.opentelemetry.io/inject-go: "otel-system/default"'
echo ""
echo "Traces are sent to: alloy.collector.svc.cluster.local:4317 (OTLP gRPC)"
