#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

RENDER_OFFLINE=true
RENDER_DIR="${RENDER_DIR:-$PROJECT_DIR/rendered}"
validate_config
mkdir -p "$RENDER_DIR"
domain="$(resolve_apps_domain)"

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
for resource in 00-namespace 01-configmap 02-deployment 03-service 04-certificate 05-router-secret-reader-role 06-router-secret-reader-binding 07-route; do
  render_template "$PROJECT_DIR/manifests/edgeroute/$resource.yaml.tpl" "$RENDER_DIR/edgeroute-$resource.yaml" "$domain"
done
render_trust_template "$PROJECT_DIR/manifests/trustbundle/00-caller-namespace.yaml.tpl" "$RENDER_DIR/trustbundle-caller-namespace.yaml" '' '' '' '' '' '' ''
render_trust_template "$PROJECT_DIR/manifests/trustbundle/01-calling-namespace.yaml.tpl" "$RENDER_DIR/trustbundle-calling-namespace.yaml" '' '' '' '' '' '' ''
render_trust_template "$PROJECT_DIR/manifests/trustbundle/02-bundle.yaml.tpl" "$RENDER_DIR/trustbundle-bundle.yaml" '' '' '' '' '' '' ''
for role in caller calling; do
  if [[ "$role" == caller ]]; then app="$TRUST_CALLER_APP_NAME"; ns="$TRUST_CALLER_NAMESPACE"; peer="$TRUST_CALLING_APP_NAME"; peer_ns="$TRUST_CALLING_NAMESPACE"; secret="$TRUST_CALLER_SECRET_NAME"; config="$TRUST_CALLER_CONFIGMAP_NAME"; deploy="$TRUST_CALLER_DEPLOYMENT_NAME"; else app="$TRUST_CALLING_APP_NAME"; ns="$TRUST_CALLING_NAMESPACE"; peer="$TRUST_CALLER_APP_NAME"; peer_ns="$TRUST_CALLER_NAMESPACE"; secret="$TRUST_CALLING_SECRET_NAME"; config="$TRUST_CALLING_CONFIGMAP_NAME"; deploy="$TRUST_CALLING_DEPLOYMENT_NAME"; fi
  for resource in 03-app-configmap 04-app-deployment 05-app-service 06-app-certificate; do render_trust_template "$PROJECT_DIR/manifests/trustbundle/$resource.yaml.tpl" "$RENDER_DIR/trustbundle-$role-${resource#??-app-}.yaml" "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy" "$domain"; done
  [[ "$CREATE_ROUTES" == true ]] && render_trust_template "$PROJECT_DIR/manifests/trustbundle/07-app-route.yaml.tpl" "$RENDER_DIR/trustbundle-$role-route.yaml" "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy" "$domain"
done
echo "Rendered manifests in $RENDER_DIR"
