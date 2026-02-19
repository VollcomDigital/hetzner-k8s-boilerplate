#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="external-secrets"

helm repo add external-secrets https://charts.external-secrets.io
helm repo update

kubectl apply -f kubernetes/security/external-secrets/namespace.yaml

helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace "$NAMESPACE" \
  --values kubernetes/security/external-secrets/values.yaml \
  --wait --timeout 5m

echo "Waiting for CRDs to be established..."
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=60s
kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=60s

echo "============================================="
echo " External Secrets Operator deployed"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Configure a ClusterSecretStore backend (Vault, AWS, etc.)"
echo "  2. See examples: kubernetes/security/external-secrets/cluster-secret-store.yaml"
echo "  3. Create ExternalSecret resources to sync secrets into Kubernetes"
echo ""
echo "Example ExternalSecret:"
echo '  apiVersion: external-secrets.io/v1beta1'
echo '  kind: ExternalSecret'
echo '  metadata:'
echo '    name: my-secret'
echo '  spec:'
echo '    refreshInterval: 1h'
echo '    secretStoreRef:'
echo '      name: vault-store'
echo '      kind: ClusterSecretStore'
echo '    target:'
echo '      name: my-secret'
echo '    data:'
echo '      - secretKey: password'
echo '        remoteRef:'
echo '          key: my-app/production'
echo '          property: password'
