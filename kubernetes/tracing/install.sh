#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="tracing"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/tracing/namespace.yaml

echo "Deploying Grafana Tempo (distributed mode)..."
helm upgrade --install tempo-distributed grafana/tempo-distributed \
  --namespace "$NAMESPACE" \
  --values kubernetes/tracing/values.yaml \
  --wait --timeout 10m

echo "Adding Tempo datasource to Grafana..."
kubectl apply -f kubernetes/tracing/grafana-datasource.yaml

echo "============================================="
echo " Tracing stack deployed (Grafana Tempo)"
echo "============================================="
echo ""
echo "Tempo accepts traces via:"
echo "  OTLP gRPC: tempo-distributed-distributor.tracing.svc.cluster.local:4317"
echo "  OTLP HTTP: tempo-distributed-distributor.tracing.svc.cluster.local:4318"
echo ""
echo "Query traces in Grafana -> Explore -> Tempo datasource"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
