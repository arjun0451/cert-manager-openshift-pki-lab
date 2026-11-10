#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config/lab.env}"
[[ -f "$CONFIG_FILE" ]] || CONFIG_FILE="${PROJECT_DIR}/config/lab.env.example"
# Process environment values intentionally win over the configuration file.
CONFIG_KEYS=(
  CALLER_NAMESPACE CALLING_NAMESPACE CERT_MANAGER_NAMESPACE CLUSTER_ISSUER_NAME
  CALLER_APP_NAME CALLING_APP_NAME CREATE_ROUTES INCLUDE_ROUTE_SANS APPS_DOMAIN
  AUTO_DISCOVER_APPS_DOMAIN APPS_DOMAIN_FALLBACK CERTIFICATE_DURATION
  CERTIFICATE_RENEW_BEFORE EDGE_ROUTE_NAMESPACE EDGE_ROUTE_APP_NAME
  EDGE_ROUTE_SERVICE_NAME EDGE_ROUTE_NAME EDGE_ROUTE_TLS_SECRET ROOT_CA_COMMON_NAME
  INTERMEDIATE_CA_COMMON_NAME
)
for key in "${CONFIG_KEYS[@]}"; do
  if printenv "$key" >/dev/null 2>&1; then
    eval "ENV_${key}=\${$key}"
    eval "ENV_${key}_SET=true"
  fi
done
# shellcheck disable=SC1090
source "$CONFIG_FILE"
for key in "${CONFIG_KEYS[@]}"; do
  if [[ "$(eval "printf '%s' \"\${ENV_${key}_SET:-}\"")" == true ]]; then
    eval "export $key=\"\${ENV_${key}}\""
  fi
done
CALLER_NAMESPACE="${CALLER_NAMESPACE:-caller-ns}"
CALLING_NAMESPACE="${CALLING_NAMESPACE:-calling-ns}"
CERT_MANAGER_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-external-intermediate-ca}"
CALLER_APP_NAME="${CALLER_APP_NAME:-caller-app}"
CALLING_APP_NAME="${CALLING_APP_NAME:-calling-app}"
EDGE_ROUTE_NAMESPACE="${EDGE_ROUTE_NAMESPACE:-edgeroute-ns}"
EDGE_ROUTE_APP_NAME="${EDGE_ROUTE_APP_NAME:-nginx-edge-app}"
EDGE_ROUTE_SERVICE_NAME="${EDGE_ROUTE_SERVICE_NAME:-nginx-edge-service}"
EDGE_ROUTE_NAME="${EDGE_ROUTE_NAME:-nginx-edge-route}"
EDGE_ROUTE_TLS_SECRET="${EDGE_ROUTE_TLS_SECRET:-edge-route-tls}"
CERTIFICATE_DURATION="${CERTIFICATE_DURATION:-60m}"
CERTIFICATE_RENEW_BEFORE="${CERTIFICATE_RENEW_BEFORE:-10m}"
CREATE_ROUTES="${CREATE_ROUTES:-true}"
INCLUDE_ROUTE_SANS="${INCLUDE_ROUTE_SANS:-true}"
APPS_DOMAIN="${APPS_DOMAIN:-}"
AUTO_DISCOVER_APPS_DOMAIN="${AUTO_DISCOVER_APPS_DOMAIN:-true}"
APPS_DOMAIN_FALLBACK="${APPS_DOMAIN_FALLBACK:-apps.example.test}"
CALLER_SECRET_NAME="${CALLER_APP_NAME}-tls-secret"
CALLING_SECRET_NAME="${CALLING_APP_NAME}-tls-secret"
CALLER_CERTIFICATE_NAME="${CALLER_APP_NAME}-tls"
CALLING_CERTIFICATE_NAME="${CALLING_APP_NAME}-tls"
CALLER_DEPLOYMENT_NAME="nginx-${CALLER_APP_NAME}"
CALLING_DEPLOYMENT_NAME="nginx-${CALLING_APP_NAME}"
CALLER_CONFIGMAP_NAME="nginx-config-${CALLER_APP_NAME}"
CALLING_CONFIGMAP_NAME="nginx-config-${CALLING_APP_NAME}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: Required command '$1' not found" >&2; exit 1; }; }
require_oc_login() { need oc; oc whoami >/dev/null 2>&1 || { echo 'ERROR: Run oc login first.' >&2; exit 1; }; }
is_valid_name() { [[ "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; }
is_valid_domain() { [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; }
duration_seconds() {
  [[ "$1" =~ ^([1-9][0-9]*)(ms|s|m|h)$ ]] || return 1
  local amount="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}" multiplier=1
  case "$unit" in ms) multiplier=0 ;; s) multiplier=1 ;; m) multiplier=60 ;; h) multiplier=3600 ;; esac
  printf '%s' "$((amount * multiplier))"
}
normalize_domain() {
  local domain="$1"
  [[ "$domain" == \*.* ]] && domain="${domain#*.}"
  is_valid_domain "$domain" || { echo "ERROR: Invalid apps domain: $1" >&2; return 1; }
  printf '%s' "$domain"
}
resolve_apps_domain() {
  local domain="$APPS_DOMAIN"
  if [[ -z "$domain" && "${RENDER_OFFLINE:-false}" != true && "$AUTO_DISCOVER_APPS_DOMAIN" == true ]] && command -v oc >/dev/null 2>&1; then
    domain="$(oc get ingress.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
  fi
  domain="${domain:-$APPS_DOMAIN_FALLBACK}"
  [[ -n "$domain" ]] || { echo 'ERROR: Set APPS_DOMAIN or APPS_DOMAIN_FALLBACK.' >&2; return 1; }
  normalize_domain "$domain"
}
validate_config() {
  local value duration renewal
  for value in "$CALLER_NAMESPACE" "$CALLING_NAMESPACE" "$CALLER_APP_NAME" "$CALLING_APP_NAME" "$EDGE_ROUTE_NAMESPACE" "$EDGE_ROUTE_APP_NAME" "$EDGE_ROUTE_SERVICE_NAME" "$EDGE_ROUTE_NAME" "$EDGE_ROUTE_TLS_SECRET"; do
    is_valid_name "$value" || { echo "ERROR: Invalid Kubernetes name: $value" >&2; return 1; }
  done
  [[ "$CALLER_APP_NAME" != "$CALLING_APP_NAME" ]] || { echo 'ERROR: Application names must differ.' >&2; return 1; }
  for value in "$CREATE_ROUTES" "$INCLUDE_ROUTE_SANS" "$AUTO_DISCOVER_APPS_DOMAIN"; do
    [[ "$value" == true || "$value" == false ]] || { echo "ERROR: Expected true or false, got: $value" >&2; return 1; }
  done
  duration="$(duration_seconds "$CERTIFICATE_DURATION")" || { echo "ERROR: Invalid CERTIFICATE_DURATION: $CERTIFICATE_DURATION" >&2; return 1; }
  renewal="$(duration_seconds "$CERTIFICATE_RENEW_BEFORE")" || { echo "ERROR: Invalid CERTIFICATE_RENEW_BEFORE: $CERTIFICATE_RENEW_BEFORE" >&2; return 1; }
  (( duration >= 3600 && renewal >= 300 && duration > renewal )) || { echo 'ERROR: Certificate duration must be at least 60m, renewBefore at least 5m, and duration greater than renewBefore.' >&2; return 1; }
}
render_template() {
  local template="$1" output="$2" domain="${3:-}"
  sed \
    -e "s|__CALLER_NAMESPACE__|${CALLER_NAMESPACE}|g" \
    -e "s|__CALLING_NAMESPACE__|${CALLING_NAMESPACE}|g" \
    -e "s|__CERT_MANAGER_NAMESPACE__|${CERT_MANAGER_NAMESPACE}|g" \
    -e "s|__CLUSTER_ISSUER_NAME__|${CLUSTER_ISSUER_NAME}|g" \
    -e "s|__CALLER_APP_NAME__|${CALLER_APP_NAME}|g" \
    -e "s|__CALLING_APP_NAME__|${CALLING_APP_NAME}|g" \
    -e "s|__CALLER_SECRET_NAME__|${CALLER_SECRET_NAME}|g" \
    -e "s|__CALLING_SECRET_NAME__|${CALLING_SECRET_NAME}|g" \
    -e "s|__CALLER_DEPLOYMENT_NAME__|${CALLER_DEPLOYMENT_NAME}|g" \
    -e "s|__CALLING_DEPLOYMENT_NAME__|${CALLING_DEPLOYMENT_NAME}|g" \
    -e "s|__CALLER_CONFIGMAP_NAME__|${CALLER_CONFIGMAP_NAME}|g" \
    -e "s|__CALLING_CONFIGMAP_NAME__|${CALLING_CONFIGMAP_NAME}|g" \
    -e "s|__EDGE_ROUTE_NAMESPACE__|${EDGE_ROUTE_NAMESPACE}|g" \
    -e "s|__EDGE_ROUTE_APP_NAME__|${EDGE_ROUTE_APP_NAME}|g" \
    -e "s|__EDGE_ROUTE_SERVICE_NAME__|${EDGE_ROUTE_SERVICE_NAME}|g" \
    -e "s|__EDGE_ROUTE_NAME__|${EDGE_ROUTE_NAME}|g" \
    -e "s|__EDGE_ROUTE_TLS_SECRET__|${EDGE_ROUTE_TLS_SECRET}|g" \
    -e "s|__CERTIFICATE_DURATION__|${CERTIFICATE_DURATION}|g" \
    -e "s|__CERTIFICATE_RENEW_BEFORE__|${CERTIFICATE_RENEW_BEFORE}|g" \
    -e "s|__APPS_DOMAIN__|${domain}|g" \
    "$template" > "$output"
}
render_certificate() {
  local app_name="$1" namespace="$2" secret_name="$3" output="$4" domain="${5:-}" route_san=''
  if [[ "$INCLUDE_ROUTE_SANS" == true ]]; then
    route_san="    - ${app_name}.${domain}"
  fi
  sed \
    -e "s|__NAMESPACE__|${namespace}|g" \
    -e "s|__APP_NAME__|${app_name}|g" \
    -e "s|__SECRET_NAME__|${secret_name}|g" \
    -e "s|__CLUSTER_ISSUER_NAME__|${CLUSTER_ISSUER_NAME}|g" \
    -e "s|__CERTIFICATE_DURATION__|${CERTIFICATE_DURATION}|g" \
    -e "s|__CERTIFICATE_RENEW_BEFORE__|${CERTIFICATE_RENEW_BEFORE}|g" \
    -e "s|__ROUTE_SAN__|${route_san}|g" \
    "$PROJECT_DIR/manifests/certificates/app-certificate.yaml.tpl" > "$output"
}
