#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
DOMAIN="$(discover_domain)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for app in caller calling; do
  if [[ "$app" == caller ]]; then ns="$CALLER_NAMESPACE"; appname=caller-app; else ns="$CALLING_NAMESPACE"; appname=calling-app; fi
  route_san=''
  if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then route_san="    - ${appname}.${DOMAIN}"; fi
  sed -e "s/__NAMESPACE__/${ns}/g" -e "s/__APP_NAME__/${appname}/g" -e "s/__SECRET_NAME__/${appname}-tls-secret/g" \
      -e "s/__ISSUER_NAME__/${CLUSTER_ISSUER_NAME}/g" -e "s|__ROUTE_SAN__|${route_san}|g" \
      "$PROJECT_DIR/manifests/certificates/app-certificate.yaml.tpl" > "$TMP/${appname}.yaml"
  oc apply -f "$TMP/${appname}.yaml"
done
echo "Requested two dual-purpose leaf certificates. Apps domain: $DOMAIN"
