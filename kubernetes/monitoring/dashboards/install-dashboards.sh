#!/usr/bin/env bash
# Loads custom Grafana dashboard JSON files into Kubernetes ConfigMaps.
# The Grafana sidecar (label: grafana_dashboard=1) will pick these up automatically.
set -euo pipefail

NAMESPACE="${1:-monitoring}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -A DASHBOARDS=(
  ["grafana-dashboard-api-red-metrics"]="api-red-metrics.json"
  ["grafana-dashboard-llm-observability"]="llm-observability.json"
  ["grafana-dashboard-hetzner-cost"]="hetzner-cost.json"
)

declare -A FOLDERS=(
  ["grafana-dashboard-api-red-metrics"]="APM & Tracing"
  ["grafana-dashboard-llm-observability"]="LLM Observability"
  ["grafana-dashboard-hetzner-cost"]="Infrastructure"
)

for CM_NAME in "${!DASHBOARDS[@]}"; do
  JSON_FILE="${SCRIPT_DIR}/${DASHBOARDS[$CM_NAME]}"
  FOLDER="${FOLDERS[$CM_NAME]}"

  if [[ ! -f "$JSON_FILE" ]]; then
    echo "  Skipping $CM_NAME: $JSON_FILE not found"
    continue
  fi

  echo "  Loading dashboard: $CM_NAME (folder: $FOLDER)..."
  kubectl create configmap "$CM_NAME" \
    --from-file="${DASHBOARDS[$CM_NAME]}=$JSON_FILE" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml \
  | kubectl annotate --local -f - "grafana_folder=$FOLDER" --dry-run=client -o yaml \
  | kubectl label --local -f - "grafana_dashboard=1" --dry-run=client -o yaml \
  | kubectl apply -f -
done

echo ""
echo "Dashboards loaded. Grafana sidecar will pick them up within ~30 seconds."
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
