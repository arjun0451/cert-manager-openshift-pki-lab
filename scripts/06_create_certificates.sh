#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
validate_config
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
domain=''
[[ "$INCLUDE_ROUTE_SANS" == true ]] && domain="$(resolve_apps_domain)"
render_certificate "$CALLER_APP_NAME" "$CALLER_NAMESPACE" "$CALLER_SECRET_NAME" "$TMP/caller.yaml" "$domain"
render_certificate "$CALLING_APP_NAME" "$CALLING_NAMESPACE" "$CALLING_SECRET_NAME" "$TMP/calling.yaml" "$domain"
oc apply -f "$TMP/caller.yaml"
oc apply -f "$TMP/calling.yaml"
echo 'Requested two dual-purpose leaf certificates.'
