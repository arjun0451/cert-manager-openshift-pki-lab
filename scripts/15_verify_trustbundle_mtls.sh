#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
need openssl
need curl
validate_config
[[ "$(oc get bundle "$TRUST_BUNDLE_NAME" -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}')" == True ]] || { echo 'ERROR: Bundle is not Synced.' >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for namespace in "$TRUST_CALLER_NAMESPACE" "$TRUST_CALLING_NAMESPACE"; do
  oc get configmap "$TRUST_BUNDLE_NAME" -n "$namespace" -o jsonpath='{.data.ca-bundle\.crt}' | grep -q 'BEGIN CERTIFICATE'
  oc get configmap "$TRUST_BUNDLE_NAME" -n "$namespace" -o jsonpath='{.binaryData.ca-bundle\.p12}' | base64 -d | openssl pkcs12 -info -noout -passin pass: >/dev/null 2>&1
done
for pair in "$TRUST_CALLER_APP_NAME:$TRUST_CALLER_NAMESPACE:$TRUST_CALLING_APP_NAME:$TRUST_CALLING_NAMESPACE" "$TRUST_CALLING_APP_NAME:$TRUST_CALLING_NAMESPACE:$TRUST_CALLER_APP_NAME:$TRUST_CALLER_NAMESPACE"; do
  IFS=: read -r app ns peer peer_ns <<<"$pair"
  cert="${app}-tls-secret"
  pod="trust-mtls-check-${app}"
  oc delete pod "$pod" -n "$ns" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
  cat > "$TMP/$pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $pod
  namespace: $ns
  labels: {app: pki-lab, component: test, pki-lab-owned: "true"}
spec:
  restartPolicy: Never
  terminationGracePeriodSeconds: 0
  securityContext:
    runAsNonRoot: true
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "sleep 120"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities: {drop: [ALL]}
    volumeMounts:
    - {name: identity, mountPath: /identity, readOnly: true}
    - {name: trust, mountPath: /trust, readOnly: true}
  volumes:
  - name: identity
    secret: {secretName: $cert}
  - name: trust
    configMap: {name: $TRUST_BUNDLE_NAME}
EOF
  oc apply -f "$TMP/$pod.yaml" >/dev/null
  oc wait --for=condition=Ready "pod/$pod" -n "$ns" --timeout=120s
  oc exec -n "$ns" "$pod" -- sh -c "curl --fail --silent --cacert /trust/ca-bundle.crt --cert /identity/tls.crt --key /identity/tls.key https://$peer.$peer_ns.svc.cluster.local:443/" >/dev/null
  oc delete pod "$pod" -n "$ns" --ignore-not-found=true --wait=true >/dev/null
done
if [[ "$CREATE_ROUTES" == true ]]; then
  domain="$(resolve_apps_domain)"
  for app in "$TRUST_CALLER_APP_NAME" "$TRUST_CALLING_APP_NAME"; do
    curl --fail --silent --show-error --cacert "$PROJECT_DIR/certs/ca-bundle.crt" "https://$app.$domain/" | grep -Fq "$app"
  done
fi
echo 'Verified PEM and PKCS#12 trust bundles plus bidirectional mTLS.'
