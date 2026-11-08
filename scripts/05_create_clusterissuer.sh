#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
oc get secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" >/dev/null
if oc get clusterissuer "$CLUSTER_ISSUER_NAME" >/dev/null 2>&1; then
  owner="$(oc get clusterissuer "$CLUSTER_ISSUER_NAME" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || true)"
  [[ "$owner" == pki-lab ]] || { echo "Refusing to overwrite unlabelled ClusterIssuer $CLUSTER_ISSUER_NAME." >&2; exit 1; }
fi
sed "s/__ISSUER_NAME__/${CLUSTER_ISSUER_NAME}/g" "$PROJECT_DIR/manifests/clusterissuer/clusterissuer.yaml" | oc apply -f -
for i in {1..60}; do
  [[ "$(oc get clusterissuer "$CLUSTER_ISSUER_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)" == True ]] && { echo 'ClusterIssuer Ready'; exit 0; }
  sleep 2
done
echo "ClusterIssuer is not Ready; inspect: oc describe clusterissuer $CLUSTER_ISSUER_NAME" >&2; exit 1
