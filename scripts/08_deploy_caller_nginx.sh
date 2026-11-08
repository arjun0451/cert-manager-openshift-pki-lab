#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
# Create both Services before either NGINX starts; static upstream DNS names must resolve at NGINX startup.
oc apply -f "$PROJECT_DIR/manifests/caller/03-service-route.yaml"
oc apply -f "$PROJECT_DIR/manifests/calling/03-service-route.yaml"
oc apply -f "$PROJECT_DIR/manifests/caller/01-configmap.yaml"
oc apply -f "$PROJECT_DIR/manifests/caller/02-deployment.yaml"
if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
  oc create route passthrough caller-app -n "$CALLER_NAMESPACE" --service=caller-app --port=https --hostname="caller-app.$(discover_domain)" --dry-run=client -o yaml | oc apply -f -
fi
oc rollout status deployment/nginx-caller -n "$CALLER_NAMESPACE" --timeout=180s
