#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
validate_config
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Create both Services before either NGINX starts; static upstream DNS names must resolve at NGINX startup.
for template in caller/03-service.yaml.tpl calling/03-service.yaml.tpl caller/01-configmap.yaml.tpl caller/02-deployment.yaml.tpl; do
  output="$TMP/${template##*/}"
  render_template "$PROJECT_DIR/manifests/$template" "$output"
  oc apply -f "$output"
done
if [[ "$CREATE_ROUTES" == true ]]; then
  domain="$(resolve_apps_domain)"
  render_template "$PROJECT_DIR/manifests/caller/04-route.yaml.tpl" "$TMP/caller-route.yaml" "$domain"
  oc apply -f "$TMP/caller-route.yaml"
fi
oc rollout status "deployment/$CALLER_DEPLOYMENT_NAME" -n "$CALLER_NAMESPACE" --timeout=180s
