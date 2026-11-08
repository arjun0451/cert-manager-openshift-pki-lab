#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
oc apply -f "$PROJECT_DIR/manifests/calling/03-service-route.yaml"
oc apply -f "$PROJECT_DIR/manifests/calling/01-configmap.yaml"
oc apply -f "$PROJECT_DIR/manifests/calling/02-deployment.yaml"
if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
  oc create route passthrough calling-app -n "$CALLING_NAMESPACE" --service=calling-app --port=https --hostname="calling-app.$(discover_domain)" --dry-run=client -o yaml | oc apply -f -
fi
oc rollout status deployment/nginx-calling -n "$CALLING_NAMESPACE" --timeout=180s
