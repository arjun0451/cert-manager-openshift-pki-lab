#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
ROOT="$PROJECT_DIR/certs/root/certs/ca.cert.pem"; INT="$PROJECT_DIR/certs/intermediate/certs/intermediate.cert.pem"; KEY="$PROJECT_DIR/certs/intermediate/private/intermediate.key.pem"
for f in "$ROOT" "$INT" "$KEY"; do [[ -s "$f" ]] || { echo "Missing $f" >&2; exit 1; }; done
oc get namespace "$CERT_MANAGER_NAMESPACE" >/dev/null
# CA issuer Secret: tls.crt must be the issuing Intermediate cert; tls.key its key.
if oc get secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" >/dev/null 2>&1; then
  owner="$(oc get secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || true)"
  [[ "$owner" == pki-lab ]] || { echo 'Refusing to overwrite an existing unlabelled cert-manager/ca-key-pair Secret.' >&2; exit 1; }
fi
oc create secret generic ca-key-pair -n "$CERT_MANAGER_NAMESPACE" --from-file=tls.crt="$INT" --from-file=tls.key="$KEY" --from-file=ca.crt="$ROOT" --dry-run=client -o yaml | oc apply -f -
oc label secret ca-key-pair -n "$CERT_MANAGER_NAMESPACE" app=pki-lab --overwrite
# Distribute public trust only (Root + Intermediate); no CA private key leaves cert-manager namespace.
BUNDLE="$PROJECT_DIR/certs/ca-bundle.crt"; cat "$INT" "$ROOT" > "$BUNDLE"; chmod 644 "$BUNDLE"
for ns in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE"; do
  oc create configmap pki-trust-bundle -n "$ns" --from-file=ca-bundle.crt="$BUNDLE" --dry-run=client -o yaml | oc apply -f -
done
