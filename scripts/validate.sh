#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

RENDER_OFFLINE=true
RENDER_DIR="${RENDER_DIR:-$PROJECT_DIR/rendered}"
validate_config
[[ -d "$RENDER_DIR" ]] || { echo "ERROR: Rendered manifests not found: $RENDER_DIR" >&2; exit 1; }
! rg -n '__[A-Z0-9_]+__' "$RENDER_DIR"
for script in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/scripts/lib/*.sh "$PROJECT_DIR"/cleanup.sh; do
  bash -n "$script"
done
for certificate in caller calling; do
  if [[ "$certificate" == caller ]]; then app="$CALLER_APP_NAME"; ns="$CALLER_NAMESPACE"; else app="$CALLING_APP_NAME"; ns="$CALLING_NAMESPACE"; fi
  file="$RENDER_DIR/$certificate-certificate.yaml"
  for san in "$app" "$app.$ns" "$app.$ns.svc" "$app.$ns.svc.cluster.local"; do
    rg -Fq -- "- $san" "$file" || { echo "ERROR: Missing rendered SAN $san" >&2; exit 1; }
  done
  rg -Fq -- '- server auth' "$file"
  rg -Fq -- '- client auth' "$file"
done
if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
  domain="$(resolve_apps_domain)"
  rg -Fq -- "- $CALLER_APP_NAME.$domain" "$RENDER_DIR/caller-certificate.yaml"
  rg -Fq -- "- $CALLING_APP_NAME.$domain" "$RENDER_DIR/calling-certificate.yaml"
fi
if [[ "$CREATE_ROUTES" == true ]]; then
  for route in "$RENDER_DIR"/*-route.yaml; do
    rg -Fxq 'apiVersion: route.openshift.io/v1' "$route"
    rg -Fxq 'kind: Route' "$route"
    rg -Fxq '    termination: passthrough' "$route"
  done
fi
root="$PROJECT_DIR/certs/root/certs/ca.cert.pem"
intermediate="$PROJECT_DIR/certs/intermediate/certs/intermediate.cert.pem"
if [[ -s "$root" && -s "$intermediate" ]]; then
  openssl verify -CAfile "$root" "$intermediate"
fi
echo 'Offline validation passed.'
