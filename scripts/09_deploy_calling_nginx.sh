#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
validate_config
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for template in calling/03-service.yaml.tpl calling/01-configmap.yaml.tpl calling/02-deployment.yaml.tpl; do
  output="$TMP/${template##*/}"
  render_template "$PROJECT_DIR/manifests/$template" "$output"
  oc apply -f "$output"
done
if [[ "$CREATE_ROUTES" == true ]]; then
  domain="$(resolve_apps_domain)"
  render_template "$PROJECT_DIR/manifests/calling/04-route.yaml.tpl" "$TMP/calling-route.yaml" "$domain"
  oc apply -f "$TMP/calling-route.yaml"
fi
oc rollout restart "deployment/$CALLING_DEPLOYMENT_NAME" -n "$CALLING_NAMESPACE"
oc rollout status "deployment/$CALLING_DEPLOYMENT_NAME" -n "$CALLING_NAMESPACE" --timeout=180s
