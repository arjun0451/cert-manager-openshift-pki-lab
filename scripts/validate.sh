#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

RENDER_OFFLINE=true
RENDER_DIR="${RENDER_DIR:-$PROJECT_DIR/rendered}"
validate_config
[[ -d "$RENDER_DIR" ]] || { echo "ERROR: Rendered manifests not found: $RENDER_DIR" >&2; exit 1; }
! grep -R -n -E '__[A-Z0-9_]+__' "$RENDER_DIR"
for script in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/scripts/lib/*.sh "$PROJECT_DIR"/cleanup.sh; do
  bash -n "$script"
done
for certificate in caller calling; do
  if [[ "$certificate" == caller ]]; then app="$CALLER_APP_NAME"; ns="$CALLER_NAMESPACE"; else app="$CALLING_APP_NAME"; ns="$CALLING_NAMESPACE"; fi
  file="$RENDER_DIR/$certificate-certificate.yaml"
  for san in "$app" "$app.$ns" "$app.$ns.svc" "$app.$ns.svc.cluster.local"; do
    grep -Fq -- "- $san" "$file" || { echo "ERROR: Missing rendered SAN $san" >&2; exit 1; }
  done
  grep -Fq -- '- server auth' "$file"
  grep -Fq -- '- client auth' "$file"
done
if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
  domain="$(resolve_apps_domain)"
  grep -Fq -- "- $CALLER_APP_NAME.$domain" "$RENDER_DIR/caller-certificate.yaml"
  grep -Fq -- "- $CALLING_APP_NAME.$domain" "$RENDER_DIR/calling-certificate.yaml"
fi
if [[ "$CREATE_ROUTES" == true ]]; then
  for route in "$RENDER_DIR/caller-route.yaml" "$RENDER_DIR/calling-route.yaml"; do
    grep -Fxq 'apiVersion: route.openshift.io/v1' "$route"
    grep -Fxq 'kind: Route' "$route"
    grep -Fxq '    termination: passthrough' "$route"
  done
fi
edge_route="$RENDER_DIR/edgeroute-07-route.yaml"
edge_certificate="$RENDER_DIR/edgeroute-04-certificate.yaml"
grep -Fxq 'apiVersion: route.openshift.io/v1' "$edge_route"
grep -Fxq 'kind: Route' "$edge_route"
grep -Fxq '    termination: edge' "$edge_route"
grep -Fxq '    insecureEdgeTerminationPolicy: Redirect' "$edge_route"
grep -Fxq "      name: $EDGE_ROUTE_TLS_SECRET" "$edge_route"
grep -Fq "  - $EDGE_ROUTE_NAME.$(resolve_apps_domain)" "$edge_certificate"
grep -Fxq '  - server auth' "$edge_certificate"
root="$PROJECT_DIR/certs/root/certs/ca.cert.pem"
intermediate="$PROJECT_DIR/certs/intermediate/certs/intermediate.cert.pem"
if [[ -s "$root" && -s "$intermediate" ]]; then
  openssl verify -CAfile "$root" "$intermediate"
fi
echo 'Offline validation passed.'
