#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
CLEANUP_DRY_RUN="${CLEANUP_DRY_RUN:-false}"
[[ "$CLEANUP_DRY_RUN" == true || "$CLEANUP_DRY_RUN" == false ]] || { echo 'ERROR: CLEANUP_DRY_RUN must be true or false.' >&2; exit 1; }
if [[ "$(oc get bundle "$TRUST_BUNDLE_NAME" -o jsonpath='{.metadata.labels.pki-lab-owned}' 2>/dev/null || true)" == true ]]; then
  if [[ "$CLEANUP_DRY_RUN" == true ]]; then oc delete bundle "$TRUST_BUNDLE_NAME" --dry-run=client -o name; else oc delete bundle "$TRUST_BUNDLE_NAME" --ignore-not-found=true; fi
fi
for namespace in "$TRUST_CALLER_NAMESPACE" "$TRUST_CALLING_NAMESPACE"; do
  [[ "$(oc get namespace "$namespace" -o jsonpath='{.metadata.labels.pki-lab-owned}' 2>/dev/null || true)" == true && "$(oc get namespace "$namespace" -o jsonpath='{.metadata.labels.pki-lab-created}' 2>/dev/null || true)" == true ]] || { echo "Preserving namespace $namespace."; continue; }
  if [[ "$CLEANUP_DRY_RUN" == true ]]; then oc delete namespace "$namespace" --dry-run=client -o name; else oc delete namespace "$namespace" --wait=true --timeout=120s; fi
done
