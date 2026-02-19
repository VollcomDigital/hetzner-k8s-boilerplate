#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="velero"

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

kubectl apply -f kubernetes/backup/velero/namespace.yaml

helm upgrade --install velero vmware-tanzu/velero \
  --namespace "$NAMESPACE" \
  --values kubernetes/backup/velero/values.yaml \
  --wait --timeout 5m

echo "============================================="
echo " Velero deployed successfully"
echo "============================================="
echo ""
echo "Verify backup location:"
echo "  velero backup-location get"
echo ""
echo "Create an on-demand backup:"
echo "  velero backup create manual-backup --include-namespaces '*'"
echo ""
echo "List backups:"
echo "  velero backup get"
echo ""
echo "Restore from backup:"
echo "  velero restore create --from-backup <backup-name>"
