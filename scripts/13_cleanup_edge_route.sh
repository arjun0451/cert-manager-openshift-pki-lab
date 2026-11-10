#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
CLEANUP_DRY_RUN="${CLEANUP_DRY_RUN:-false}"
[[ "$CLEANUP_DRY_RUN" == true || "$CLEANUP_DRY_RUN" == false ]] || { echo 'ERROR: CLEANUP_DRY_RUN must be true or false.' >&2; exit 1; }

if ! oc get namespace "$EDGE_ROUTE_NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace $EDGE_ROUTE_NAMESPACE does not exist."
  exit 0
fi
[[ "$(oc get namespace "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.metadata.labels.pki-lab-owned}')" == true && "$(oc get namespace "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.metadata.labels.pki-lab-created}')" == true ]] || { echo "Refusing to clean a namespace not created by this lab: $EDGE_ROUTE_NAMESPACE." >&2; exit 1; }
if [[ "$CLEANUP_DRY_RUN" == true ]]; then
  oc delete route,deployment,service,configmap,certificate,secret,role,rolebinding -n "$EDGE_ROUTE_NAMESPACE" -l pki-lab-owned=true --ignore-not-found=true --dry-run=client -o name
  oc delete namespace "$EDGE_ROUTE_NAMESPACE" --dry-run=client -o name
else
  oc delete route,deployment,service,configmap,certificate,secret,role,rolebinding -n "$EDGE_ROUTE_NAMESPACE" -l pki-lab-owned=true --ignore-not-found=true
  oc delete namespace "$EDGE_ROUTE_NAMESPACE" --wait=true --timeout=120s
fi
