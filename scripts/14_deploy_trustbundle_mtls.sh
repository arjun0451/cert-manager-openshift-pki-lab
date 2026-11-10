#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
require_oc_login
need openssl
validate_config
oc get crd bundles.trust.cert-manager.io >/dev/null || { echo 'ERROR: trust-manager Bundle CRD is not installed.' >&2; exit 1; }
oc get secret ca-key-pair -n "$TRUST_MANAGER_NAMESPACE" >/dev/null || { echo "ERROR: ca-key-pair is missing from trust-manager namespace $TRUST_MANAGER_NAMESPACE." >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
DOMAIN=''
[[ "$CREATE_ROUTES" == true || "$INCLUDE_ROUTE_SANS" == true ]] && DOMAIN="$(resolve_apps_domain)"
render() { render_trust_template "$PROJECT_DIR/manifests/trustbundle/$1.yaml.tpl" "$TMP/$1.yaml" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$DOMAIN"; }
for pair in "00-caller-namespace:$TRUST_CALLER_NAMESPACE" "01-calling-namespace:$TRUST_CALLING_NAMESPACE"; do
  template="${pair%%:*}"; namespace="${pair#*:}"
  if ! oc get namespace "$namespace" >/dev/null 2>&1; then
    render "$template" '' '' '' '' '' '' ''
    oc apply -f "$TMP/$template.yaml"
  else
    echo "Using existing namespace $namespace; it will not be marked lab-owned."
  fi
done
render 02-bundle '' '' '' '' '' '' ''
oc apply -f "$TMP/02-bundle.yaml"
for namespace in "$TRUST_CALLER_NAMESPACE" "$TRUST_CALLING_NAMESPACE"; do
  for _ in {1..30}; do
    pem="$(oc get configmap "$TRUST_BUNDLE_NAME" -n "$namespace" -o jsonpath='{.data.ca-bundle\.crt}' 2>/dev/null || true)"
    p12="$(oc get configmap "$TRUST_BUNDLE_NAME" -n "$namespace" -o jsonpath='{.binaryData.ca-bundle\.p12}' 2>/dev/null || true)"
    if [[ -n "$pem" && -n "$p12" ]]; then break; fi
    sleep 2
  done
  [[ -n "${pem:-}" && -n "${p12:-}" ]] || { echo "ERROR: Bundle did not sync PEM and PKCS#12 data to $namespace." >&2; exit 1; }
done
render 05-app-service "$TRUST_CALLER_APP_NAME" "$TRUST_CALLER_NAMESPACE" "$TRUST_CALLING_APP_NAME" "$TRUST_CALLING_NAMESPACE" "$TRUST_CALLER_SECRET_NAME" "$TRUST_CALLER_CONFIGMAP_NAME" "$TRUST_CALLER_DEPLOYMENT_NAME"
oc apply -f "$TMP/05-app-service.yaml"
render 05-app-service "$TRUST_CALLING_APP_NAME" "$TRUST_CALLING_NAMESPACE" "$TRUST_CALLER_APP_NAME" "$TRUST_CALLER_NAMESPACE" "$TRUST_CALLING_SECRET_NAME" "$TRUST_CALLING_CONFIGMAP_NAME" "$TRUST_CALLING_DEPLOYMENT_NAME"
oc apply -f "$TMP/05-app-service.yaml"
for role in caller calling; do
  if [[ "$role" == caller ]]; then app="$TRUST_CALLER_APP_NAME"; ns="$TRUST_CALLER_NAMESPACE"; peer="$TRUST_CALLING_APP_NAME"; peer_ns="$TRUST_CALLING_NAMESPACE"; secret="$TRUST_CALLER_SECRET_NAME"; config="$TRUST_CALLER_CONFIGMAP_NAME"; deploy="$TRUST_CALLER_DEPLOYMENT_NAME"; else app="$TRUST_CALLING_APP_NAME"; ns="$TRUST_CALLING_NAMESPACE"; peer="$TRUST_CALLER_APP_NAME"; peer_ns="$TRUST_CALLER_NAMESPACE"; secret="$TRUST_CALLING_SECRET_NAME"; config="$TRUST_CALLING_CONFIGMAP_NAME"; deploy="$TRUST_CALLING_DEPLOYMENT_NAME"; fi
  render 06-app-certificate "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy"; oc apply -f "$TMP/06-app-certificate.yaml"
  oc wait --for=condition=Ready "certificate/$app-tls" -n "$ns" --timeout=180s
  if [[ "$CREATE_ROUTES" == true && "$INCLUDE_ROUTE_SANS" == true ]]; then
    for _ in {1..90}; do
      if oc get secret "$secret" -n "$ns" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -Fq "DNS:$app.$DOMAIN"; then break; fi
      sleep 2
    done
    oc get secret "$secret" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -ext subjectAltName | grep -Fq "DNS:$app.$DOMAIN" || { echo "ERROR: Certificate $app-tls does not contain its Route SAN." >&2; exit 1; }
  fi
  if [[ "$CREATE_ROUTES" == true ]]; then render 07-app-route "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy"; oc apply -f "$TMP/07-app-route.yaml"; fi
  render 03-app-configmap "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy"; oc apply -f "$TMP/03-app-configmap.yaml"
  render 04-app-deployment "$app" "$ns" "$peer" "$peer_ns" "$secret" "$config" "$deploy"; oc apply -f "$TMP/04-app-deployment.yaml"
  oc rollout restart "deployment/$deploy" -n "$ns"
  oc rollout status "deployment/$deploy" -n "$ns" --timeout=180s
done
echo "Trust-manager mTLS scenario deployed with bundle $TRUST_BUNDLE_NAME."
