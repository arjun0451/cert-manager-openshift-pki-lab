#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/scripts/lib/common.sh"
require_oc_login
CLEANUP_DRY_RUN="${CLEANUP_DRY_RUN:-false}"
[[ "$CLEANUP_DRY_RUN" == true || "$CLEANUP_DRY_RUN" == false ]] || { echo 'ERROR: CLEANUP_DRY_RUN must be true or false.' >&2; exit 1; }
delete_owned() {
  local namespace="$1"; shift
  local args=("$@" -n "$namespace" -l pki-lab-owned=true --ignore-not-found=true)
  if [[ "$CLEANUP_DRY_RUN" == true ]]; then
    oc delete "${args[@]}" --dry-run=client -o name
  else
    oc delete "${args[@]}"
  fi
}
for ns in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE"; do
  delete_owned "$ns" route,deployment,service,configmap,certificate,secret
  if [[ "$(oc get namespace "$ns" -o jsonpath='{.metadata.labels.pki-lab-created}' 2>/dev/null || true)" == true && "$(oc get namespace "$ns" -o jsonpath='{.metadata.labels.pki-lab-owned}' 2>/dev/null || true)" == true ]]; then
    if [[ "$CLEANUP_DRY_RUN" == true ]]; then oc delete namespace "$ns" --dry-run=client -o name; else oc delete namespace "$ns" --wait=true --timeout=120s; fi
  else
    echo "Preserving namespace $ns."
  fi
done
if [[ "$(oc get clusterissuer "$CLUSTER_ISSUER_NAME" -o jsonpath='{.metadata.labels.pki-lab-owned}' 2>/dev/null || true)" == true ]]; then
  if [[ "$CLEANUP_DRY_RUN" == true ]]; then oc delete clusterissuer "$CLUSTER_ISSUER_NAME" --dry-run=client -o name; else oc delete clusterissuer "$CLUSTER_ISSUER_NAME" --ignore-not-found=true; fi
fi
if [[ "$(oc get secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" -o jsonpath='{.metadata.labels.pki-lab-owned}' 2>/dev/null || true)" == true ]]; then
  if [[ "$CLEANUP_DRY_RUN" == true ]]; then oc delete secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" --dry-run=client -o name; else oc delete secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" --ignore-not-found=true; fi
fi
rm -f "$PROJECT_DIR/certs/ca-bundle.crt" "$PROJECT_DIR/certs/mtls-test-pod.yaml"
echo 'Lab-owned cluster resources removed. Generated CA files under certs/ were retained.'
