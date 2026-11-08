#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

RENDER_OFFLINE=true
RENDER_DIR="${RENDER_DIR:-$PROJECT_DIR/rendered}"
validate_config
mkdir -p "$RENDER_DIR"
domain=''
if [[ "$CREATE_ROUTES" == true || "$INCLUDE_ROUTE_SANS" == true ]]; then
  domain="$(resolve_apps_domain)"
fi

render_template "$PROJECT_DIR/manifests/namespaces/namespaces.yaml.tpl" "$RENDER_DIR/namespaces.yaml"
render_template "$PROJECT_DIR/manifests/clusterissuer/clusterissuer.yaml" "$RENDER_DIR/clusterissuer.yaml"
for role in caller calling; do
  for resource in 01-configmap 02-deployment 03-service; do
    render_template "$PROJECT_DIR/manifests/$role/$resource.yaml.tpl" "$RENDER_DIR/$role-$resource.yaml"
  done
done
if [[ "$CREATE_ROUTES" == true ]]; then
  render_template "$PROJECT_DIR/manifests/caller/04-route.yaml.tpl" "$RENDER_DIR/caller-route.yaml" "$domain"
  render_template "$PROJECT_DIR/manifests/calling/04-route.yaml.tpl" "$RENDER_DIR/calling-route.yaml" "$domain"
fi
render_certificate "$CALLER_APP_NAME" "$CALLER_NAMESPACE" "$CALLER_SECRET_NAME" "$RENDER_DIR/caller-certificate.yaml" "$domain"
render_certificate "$CALLING_APP_NAME" "$CALLING_NAMESPACE" "$CALLING_SECRET_NAME" "$RENDER_DIR/calling-certificate.yaml" "$domain"
echo "Rendered manifests in $RENDER_DIR"
