#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
need curl
need openssl
validate_config

DOMAIN="$(resolve_apps_domain)"
HOST="$EDGE_ROUTE_NAME.$DOMAIN"
[[ "$(oc get certificate edge-route-cert -n "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == True ]] || { echo 'Edge Route Certificate is not Ready.' >&2; exit 1; }
[[ "$(oc get route "$EDGE_ROUTE_NAME" -n "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.spec.tls.termination}')" == edge ]] || { echo 'Route is not edge terminated.' >&2; exit 1; }
[[ "$(oc get route "$EDGE_ROUTE_NAME" -n "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.spec.tls.externalCertificate.name}')" == "$EDGE_ROUTE_TLS_SECRET" ]] || { echo 'Route does not reference the cert-manager Secret.' >&2; exit 1; }
oc get secret "$EDGE_ROUTE_TLS_SECRET" -n "$EDGE_ROUTE_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -ext subjectAltName | grep -Fq "DNS:$HOST"
curl --fail --silent --show-error --cacert "$PROJECT_DIR/certs/ca-bundle.crt" "https://$HOST/" | grep -Fq 'Backend transport seen by this pod: <strong>http</strong>'
echo "Verified edge TLS at the router and HTTP transport from router to backend for $HOST."
