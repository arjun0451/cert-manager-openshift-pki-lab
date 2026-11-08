#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
# Run curl in an ephemeral pod with both identities and the public trust bundle mounted.
TMP="$(mktemp)"
cat > "$TMP" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pki-mtls-check
  namespace: $CALLER_NAMESPACE
  labels: {app: pki-lab, component: test}
spec:
  restartPolicy: Never
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - {name: caller-cert, mountPath: /identity, readOnly: true}
    - {name: trust, mountPath: /trust, readOnly: true}
  volumes:
  - name: caller-cert
    secret: {secretName: caller-app-tls-secret}
  - name: trust
    configMap: {name: pki-trust-bundle}
EOF
trap 'oc delete pod pki-mtls-check -n "$CALLER_NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true; oc delete pod pki-mtls-check-reverse -n "$CALLING_NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true; rm -f "$TMP"' EXIT
oc apply -f "$TMP" >/dev/null
oc wait --for=condition=Ready pod/pki-mtls-check -n "$CALLER_NAMESPACE" --timeout=120s
# Positive: client authenticates to caller NGINX; caller NGINX then authenticates to calling NGINX.
oc exec -n "$CALLER_NAMESPACE" pki-mtls-check -- curl --fail --silent --show-error \
  --cacert /trust/ca-bundle.crt --cert /identity/tls.crt --key /identity/tls.key \
  https://caller-app.caller-ns.svc.cluster.local:443/call-peer | grep -q calling-app
# Negative: caller NGINX must reject a client without a certificate.
if oc exec -n "$CALLER_NAMESPACE" pki-mtls-check -- curl --silent --output /dev/null --max-time 10 \
  --cacert /trust/ca-bundle.crt https://caller-app.caller-ns.svc.cluster.local:443/; then
  echo 'ERROR: unauthenticated TLS request unexpectedly succeeded' >&2; exit 1
fi
# Reverse direction: calling identity connects to caller service.
cat > "$TMP" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pki-mtls-check-reverse
  namespace: $CALLING_NAMESPACE
spec:
  restartPolicy: Never
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - {name: calling-cert, mountPath: /identity, readOnly: true}
    - {name: trust, mountPath: /trust, readOnly: true}
  volumes:
  - name: calling-cert
    secret: {secretName: calling-app-tls-secret}
  - name: trust
    configMap: {name: pki-trust-bundle}
EOF
oc apply -f "$TMP" >/dev/null
oc wait --for=condition=Ready pod/pki-mtls-check-reverse -n "$CALLING_NAMESPACE" --timeout=120s
oc exec -n "$CALLING_NAMESPACE" pki-mtls-check-reverse -- curl --fail --silent --show-error \
  --cacert /trust/ca-bundle.crt --cert /identity/tls.crt --key /identity/tls.key \
  https://calling-app.calling-ns.svc.cluster.local:443/call-peer | grep -q caller-app
oc delete pod pki-mtls-check-reverse -n "$CALLING_NAMESPACE" --ignore-not-found=true >/dev/null
rm -f "$TMP"
echo 'mTLS verification passed in both directions; unauthenticated client was rejected.'
