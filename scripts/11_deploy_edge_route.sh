#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
validate_config

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
DOMAIN="$(resolve_apps_domain)"
if ! oc get namespace "$EDGE_ROUTE_NAMESPACE" >/dev/null 2>&1; then
  render_template "$PROJECT_DIR/manifests/edgeroute/00-namespace.yaml.tpl" "$TMP/00-namespace.yaml" "$DOMAIN"
  oc apply -f "$TMP/00-namespace.yaml"
else
  echo "Using existing namespace $EDGE_ROUTE_NAMESPACE; it will not be marked lab-owned."
fi
for resource in 01-configmap 02-deployment 03-service 04-certificate 05-router-secret-reader-role 06-router-secret-reader-binding; do
  render_template "$PROJECT_DIR/manifests/edgeroute/$resource.yaml.tpl" "$TMP/$resource.yaml" "$DOMAIN"
  oc apply -f "$TMP/$resource.yaml"
done
oc wait --for=condition=Ready certificate/edge-route-cert -n "$EDGE_ROUTE_NAMESPACE" --timeout=180s
render_template "$PROJECT_DIR/manifests/edgeroute/07-route.yaml.tpl" "$TMP/07-route.yaml" "$DOMAIN"
oc apply -f "$TMP/07-route.yaml"
oc rollout restart "deployment/$EDGE_ROUTE_APP_NAME" -n "$EDGE_ROUTE_NAMESPACE"
oc rollout status "deployment/$EDGE_ROUTE_APP_NAME" -n "$EDGE_ROUTE_NAMESPACE" --timeout=180s
echo "Edge Route available at https://$EDGE_ROUTE_NAME.$DOMAIN"
