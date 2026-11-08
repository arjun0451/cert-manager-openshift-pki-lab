#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/scripts/lib/common.sh"
require_oc_login
for ns in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE"; do
  if oc get namespace "$ns" -o jsonpath='{.metadata.labels.pki-lab-managed}' 2>/dev/null | grep -qx true; then
    oc delete route caller-app calling-app -n "$ns" --ignore-not-found=true 2>/dev/null || true
    if [[ "$ns" == "$CALLER_NAMESPACE" ]]; then dep=nginx-caller; svc=caller-app; cm=nginx-config-caller; cert=caller-app-tls; secret=caller-app-tls-secret; else dep=nginx-calling; svc=calling-app; cm=nginx-config-calling; cert=calling-app-tls; secret=calling-app-tls-secret; fi
    oc delete deployment "$dep" -n "$ns" --ignore-not-found=true
    oc delete service "$svc" -n "$ns" --ignore-not-found=true
    oc delete configmap "$cm" pki-trust-bundle -n "$ns" --ignore-not-found=true
    oc delete certificate "$cert" -n "$ns" --ignore-not-found=true
    oc delete secret "$secret" -n "$ns" --ignore-not-found=true
    # Delete only namespaces created by this lab; preserve pre-existing/shared namespaces.
    created="$(oc get namespace "$ns" -o jsonpath='{.metadata.labels.pki-lab-created}' 2>/dev/null || true)"
    if [[ "$created" == true ]]; then
      oc delete namespace "$ns" --wait=true --timeout=120s
    else
      echo "Preserving pre-existing namespace $ns."
    fi
  else
    echo "Skipping $ns: missing pki-lab-managed=true label."
  fi
done
if [[ "$(oc get clusterissuer "$CLUSTER_ISSUER_NAME" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || true)" == pki-lab ]]; then
  oc delete clusterissuer "$CLUSTER_ISSUER_NAME" --ignore-not-found=true
fi
if [[ "$(oc get secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || true)" == pki-lab ]]; then
  oc delete secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" --ignore-not-found=true
fi
rm -f "$PROJECT_DIR/certs/ca-bundle.crt" "$PROJECT_DIR/certs/mtls-test-pod.yaml"
echo 'Lab cluster resources removed. Generated CA files under certs/ were retained; securely archive or remove them separately.'
